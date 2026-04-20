#!/usr/bin/env python3
"""
PhytoPi AI Worker - runs on home PC / server
Polls ai_capture_jobs for pending jobs, runs Moondream vision inference,
writes diagnostic + tips back to ai_capture_jobs and ml_inferences.

Species identification uses a two-stage hybrid pipeline:
  1. moondream:1.8b answers the species question.
  2. If the answer looks uncertain (hedging words, vague, etc.) AND a
     PLANTNET_API_KEY is set, the PlantNet API is queried as a fallback.
     PlantNet is purpose-built for plant taxonomy and returns a real
     confidence score (0-1).  If its top result score >= PLANTNET_CONFIDENCE_THRESHOLD
     the PlantNet name is used; otherwise the moondream answer is kept.

Usage:
    python3 scripts/ai_worker.py

Environment (set in .env file next to this script, or export before running):
    SUPABASE_URL                    - your Supabase project URL
    SUPABASE_SERVICE_ROLE_KEY       - service role key (bypasses RLS)
    SUPABASE_ANON_KEY               - fallback if service role not set
    PLANTNET_API_KEY                - PlantNet API key (get one free at https://my.plantnet.org)
    PLANTNET_CONFIDENCE_THRESHOLD   - minimum PlantNet score to accept (default: 0.20)

Models (installed via pip):
    pip install moondream pillow requests supabase
"""
import io
import os
import re
import sys
import time
from pathlib import Path
from datetime import datetime, timezone

try:
    import requests as _requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False

PROCESSING_TIMEOUT_SECONDS = int(os.environ.get("AI_JOB_PROCESSING_TIMEOUT_SECONDS", "300"))
# Jobs older than this are abandoned (failed) rather than re-queued.
# Set to 0 to re-queue all stale jobs regardless of age.
MAX_RECOVERY_AGE_SECONDS = int(os.environ.get("AI_JOB_MAX_RECOVERY_AGE_SECONDS", str(2 * 3600)))

# ---------------------------------------------------------------------------
# Load .env from the same directory as this script (or the working directory)
# ---------------------------------------------------------------------------
def _load_dotenv():
    candidates = [
        Path(__file__).parent.parent / ".env",   # controller/.env
        Path(__file__).parent / ".env",            # scripts/.env
        Path(".env"),                              # cwd/.env
    ]
    for path in candidates:
        if path.exists():
            with open(path) as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#") or "=" not in line:
                        continue
                    key, _, val = line.partition("=")
                    val = val.strip().strip('"').strip("'")
                    os.environ.setdefault(key.strip(), val)
            print(f"Loaded env from {path}", file=sys.stderr)
            return
    print("Warning: no .env file found; relying on exported environment variables.", file=sys.stderr)

_load_dotenv()

# ---------------------------------------------------------------------------
# Supabase client
# ---------------------------------------------------------------------------
try:
    from supabase import create_client
except ImportError:
    print("pip install supabase", file=sys.stderr)
    sys.exit(1)

# ---------------------------------------------------------------------------
# Vision inference via Ollama (moondream:1.8b)
# Moondream is a compact VLM (~2.2-2.8 GB) optimised for OCR/VQA on
# resource-constrained hardware.  2 K context window — keep prompts short.
# Install: curl -fsSL https://ollama.com/install.sh | sh
#          ollama pull moondream:1.8b   # or moondream:latest
#          pip install ollama Pillow
# ---------------------------------------------------------------------------
try:
    import ollama as _ollama
    from PIL import Image
    HAS_OLLAMA = True
except ImportError:
    HAS_OLLAMA = False
    print("Warning: ollama not installed. Using placeholder results.", file=sys.stderr)
    print("  Install: pip install ollama && ollama pull moondream:1.8b", file=sys.stderr)

OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "moondream:1.8b")

# ---------------------------------------------------------------------------
# PlantNet API — species identification fallback
# Free tier: 500 requests/day.  Sign up at https://my.plantnet.org
# If PLANTNET_API_KEY is not set the fallback is silently skipped.
# ---------------------------------------------------------------------------
PLANTNET_API_KEY = os.environ.get("PLANTNET_API_KEY", "")
PLANTNET_CONFIDENCE_THRESHOLD = float(
    os.environ.get("PLANTNET_CONFIDENCE_THRESHOLD", "0.20")
)
PLANTNET_URL = "https://my-api.plantnet.org/v2/identify/all"

# Words/phrases that indicate moondream isn't sure about the species.
_LOW_CONFIDENCE_SIGNALS = frozenset([
    "i think", "possibly", "appears to be", "may be", "might be",
    "not sure", "cannot identify", "i'm not sure", "i am not sure",
    "hard to tell", "difficult to identify", "unclear", "i cannot",
    "i don't know", "i do not know",
])

# Moondream occasionally hallucinates lorem ipsum filler text.
_LOREM_IPSUM_RE = re.compile(
    r'\b(lorem|ipsum|dolor|sit\s+amet|consectetur|adipiscing|elit)\b',
    re.IGNORECASE,
)

# Garbled / nonsense patterns: pure symbols, ?-runs, leading punctuation.
_GARBLED_RE = re.compile(r'^[^a-zA-Z0-9]+$')


def _is_garbled(text: str) -> bool:
    """Return True if the response looks like garbage (?????, xtremely, !!! …)."""
    if not text or not text.strip():
        return True
    t = text.strip()
    # Pure non-alphanumeric (e.g. "?????")
    if _GARBLED_RE.match(t):
        return True
    # Starts with a non-word character that suggests a stray prefix (e.g. "!!! Marijuana")
    # We still allow it — the content after may be valid — so we don't flag here.
    # Very short token that can't be a real word (single char that isn't a letter)
    if len(t) == 1 and not t.isalpha():
        return True
    return False


def _match_enum(text: str, choices: list, default: str) -> str:
    """
    Return the first allowed value found in *text* (case-insensitive).
    Falls back to *default* if none match or *text* looks garbled.
    """
    if _is_garbled(text):
        return default
    t = text.lower()
    for choice in choices:
        if choice.lower() in t:
            return choice
    return default


def _is_low_confidence_species(answer: str) -> bool:
    """Return True if moondream's species answer looks uncertain or garbled."""
    if _is_garbled(answer):
        return True
    text = answer.lower().strip()
    # Strip leading punctuation/symbols (e.g. "!!! Marijuana")
    text_clean = re.sub(r'^[^a-z]+', '', text).strip()
    if not text_clean:
        return True
    # Lorem ipsum hallucination
    if _LOREM_IPSUM_RE.search(text):
        return True
    # Vague single-word catch-alls
    if text_clean in {"unknown", "plant", "a plant", "flower", "tree", "shrub", "herb"}:
        return True
    # Rambling sentence = model is guessing
    if len(text.split()) > 8:
        return True
    return any(phrase in text for phrase in _LOW_CONFIDENCE_SIGNALS)


def _identify_species_plantnet(image_bytes: bytes) -> tuple:
    """
    Query the PlantNet API with the image.
    Returns (common_name: str, confidence: float).
    Returns ("", 0.0) on any failure or if the key is not set.
    """
    if not PLANTNET_API_KEY or not HAS_REQUESTS:
        return "", 0.0

    try:
        resp = _requests.post(
            PLANTNET_URL,
            params={"api-key": PLANTNET_API_KEY, "lang": "en", "nb-results": 3},
            files=[("images", ("plant.jpg", io.BytesIO(image_bytes), "image/jpeg"))],
            data={"organs": ["auto"]},
            timeout=20,
        )
        resp.raise_for_status()
        results = resp.json().get("results", [])
        if not results:
            return "", 0.0

        top = results[0]
        score = float(top.get("score", 0.0))
        species_data = top.get("species", {})
        common_names = species_data.get("commonNames", [])
        scientific = species_data.get("scientificName", "")
        name = common_names[0] if common_names else scientific
        return name, score
    except Exception as exc:
        print(f"  PlantNet API error: {exc}", file=sys.stderr)
        return "", 0.0


def _parse_iso_ts(value):
    if not value or not isinstance(value, str):
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Image fetching
# ---------------------------------------------------------------------------
def _fetch_image_bytes(supabase, storage_path: str):
    """Download image bytes from Supabase Storage."""
    try:
        return supabase.storage.from_("device-images").download(storage_path)
    except Exception as e:
        print(f"Could not fetch image from storage ({storage_path}): {e}", file=sys.stderr)
        return None


# ---------------------------------------------------------------------------
# Real inference with Moondream — multi-query VQA pattern
# Moondream is a VQA model; one focused question per field is far more
# reliable than asking it to fill a multi-field JSON template in one shot.
# ---------------------------------------------------------------------------

# Matches "1. tip text", "2) tip text", etc. for parsing the tips response.
_TIP_RE = re.compile(r'^\s*\d+[\.\)]\s*(.+)', re.MULTILINE)


def _query(image_bytes: bytes, question: str, temperature: float = 0.15) -> str:
    """Send the image with a single focused question; return the model's answer.

    A low temperature (default 0.15) greatly reduces random hallucinations on
    structured / enum-type questions.  Use a higher value (0.4-0.6) for free-text
    descriptions where some creativity is acceptable.
    """
    response = _ollama.chat(
        model=OLLAMA_MODEL,
        messages=[{"role": "user", "content": question, "images": [image_bytes]}],
        options={"temperature": temperature},
    )
    return response["message"]["content"].strip()


# ---------------------------------------------------------------------------
# Retry prompt variants — used when the first attempt returns garbled output.
# Asking the same question again usually produces the same bad answer.
# ---------------------------------------------------------------------------
_RETRY_PROMPTS = {
    "health_status": (
        "Look at this plant image carefully. "
        "Type ONLY the single word 'healthy' if the plant looks vigorous and undamaged, "
        "or ONLY the single word 'needs_attention' if you see wilting, yellowing, spots, "
        "or other stress signs. Do not write anything else."
    ),
    "leaf_area": (
        "How much of the plant is covered in leaves? "
        "Answer with ONLY one of these exact words (nothing else): sparse  moderate  dense"
    ),
    "growth_stage": (
        "What stage of growth is this plant in? "
        "Answer with ONLY one of these exact words (nothing else): "
        "seedling  vegetative  flowering  fruiting  mature"
    ),
    "disease_signs": (
        "Do you see any disease, pest damage, yellowing, spots, mould, or rot on this plant? "
        "If yes, describe it in one short sentence. If no problems are visible, reply exactly: None"
    ),
    "soil_observation": (
        "Is the soil visible in this image? "
        "If yes, describe its appearance in one sentence. "
        "If the soil is not visible, reply exactly: Not visible"
    ),
}


def _run_ollama(image_bytes: bytes, sensor_context: str = "") -> dict:
    sensors = sensor_context if sensor_context else "No sensor data available."

    def q(label: str, question: str, default: str = "",
          temperature: float = 0.15, retry_question: str = "") -> str:
        """Query moondream; retry once with an alternate prompt on failure/garbage."""
        for attempt in range(2):
            prompt = question if attempt == 0 else (retry_question or question)
            suffix = " (retry)" if attempt else ""
            print(f"  -> Querying: {label}{suffix}")
            try:
                answer = _query(image_bytes, prompt, temperature=temperature)
                if answer and not _is_garbled(answer):
                    print(f"     <- {answer[:120]}")
                    return answer
                if answer:
                    print(f"     <- garbled response ({answer[:40]!r}), retrying ...")
            except Exception as e:
                print(f"     Query error ({label}): {e}", file=sys.stderr)
                break
            if attempt == 0:
                time.sleep(1)
        if default:
            print(f"     <- (no response, using default: {default!r})")
        return default

    species_raw = q(
        "species",
        "What type of plant is shown in this image? "
        "Reply with only the common plant name, one to three words "
        "(examples: tomato, snake plant, peace lily, basil). "
        "Do not add any explanation.",
        temperature=0.1,
    )

    # --- Hybrid species identification ---
    species_source = "moondream"
    species_confidence = None

    if _is_low_confidence_species(species_raw) and PLANTNET_API_KEY:
        print("  -> Species confidence low — querying PlantNet API as fallback ...")
        plantnet_name, plantnet_score = _identify_species_plantnet(image_bytes)
        if plantnet_name and plantnet_score >= PLANTNET_CONFIDENCE_THRESHOLD:
            species = plantnet_name
            species_source = "plantnet"
            species_confidence = round(plantnet_score, 3)
            print(f"     <- PlantNet: {species} (score {plantnet_score:.1%})")
        else:
            # Strip leading punctuation from moondream answer (e.g. "!!! Basil" -> "Basil")
            species = re.sub(r'^[^a-zA-Z]+', '', species_raw).strip() or "Unknown"
            if plantnet_name:
                print(
                    f"     PlantNet score too low ({plantnet_score:.1%} < "
                    f"{PLANTNET_CONFIDENCE_THRESHOLD:.0%}), keeping moondream answer"
                )
            else:
                print("     PlantNet returned no result, keeping moondream answer")
    else:
        species = re.sub(r'^[^a-zA-Z]+', '', species_raw).strip() or "Unknown"

    health_raw = q(
        "health_status",
        "Is this plant healthy, or does it show stress, disease, or damage? "
        "Reply with ONLY one of these two words: healthy  needs_attention",
        default="healthy",
        temperature=0.1,
        retry_question=_RETRY_PROMPTS["health_status"],
    )
    plant_state = _match_enum(
        health_raw,
        ["needs_attention", "healthy"],
        default="healthy",
    )

    leaf_color = q(
        "leaf_color",
        "What is the primary leaf color of this plant? "
        "Answer in one short sentence (e.g. 'The leaves are dark green with yellow edges.').",
        temperature=0.3,
    )

    leaf_area_raw = q(
        "leaf_area",
        "How dense is the leaf coverage of this plant? "
        "Reply with ONLY one of these exact words: sparse  moderate  dense",
        default="moderate",
        temperature=0.1,
        retry_question=_RETRY_PROMPTS["leaf_area"],
    )
    leaf_area = _match_enum(
        leaf_area_raw,
        ["sparse", "moderate", "dense"],
        default="moderate",
    )

    leaf_condition = q(
        "leaf_condition",
        "Describe the condition of the leaves in one or two sentences: "
        "include color, texture, shape, and any spots, curling, or damage you can see.",
        temperature=0.35,
    )

    growth_stage_raw = q(
        "growth_stage",
        "What growth stage is this plant in? "
        "Reply with ONLY one of these exact words: seedling  vegetative  flowering  fruiting  mature",
        default="vegetative",
        temperature=0.1,
        retry_question=_RETRY_PROMPTS["growth_stage"],
    )
    growth_stage = _match_enum(
        growth_stage_raw,
        ["seedling", "vegetative", "flowering", "fruiting", "mature"],
        default="vegetative",
    )

    disease_signs = q(
        "disease_signs",
        "Are there any visible diseases, pests, discoloration, spots, wilting, or rot on this plant? "
        "Describe briefly in one sentence, or reply exactly 'None' if everything looks healthy.",
        default="None",
        temperature=0.2,
        retry_question=_RETRY_PROMPTS["disease_signs"],
    )

    soil_obs = q(
        "soil_observation",
        "Is the soil visible in this image? If yes, describe its colour and moisture appearance. "
        "If the soil is not visible, reply exactly 'Not visible'.",
        default="Not visible",
        temperature=0.2,
        retry_question=_RETRY_PROMPTS["soil_observation"],
    )

    env_assessment = q(
        "environment_assessment",
        f"Sensor readings for this plant's environment:\n{sensors}\n\n"
        "In one sentence, explain how these sensor conditions help or stress this plant.",
        temperature=0.35,
    )

    diagnostic = q(
        "diagnostic",
        f"Sensor readings for this plant's environment:\n{sensors}\n\n"
        "In two sentences, summarise this plant's overall health based on what you "
        "see in the image and the sensor readings above.",
        temperature=0.35,
    )

    tips_raw = q(
        "tips",
        f"Sensor readings for this plant's environment:\n{sensors}\n\n"
        "Give exactly three specific, actionable care tips for this plant. "
        "Base them on what you see in the image and the sensor readings. "
        "Format as a numbered list — nothing before or after:\n1. ...\n2. ...\n3. ...",
        temperature=0.4,
    )
    tips = _TIP_RE.findall(tips_raw)
    if not tips and tips_raw:
        tips = [tips_raw]
    tips = [t.strip() for t in tips[:3] if t.strip()]
    if not tips:
        tips = [
            "Monitor plant regularly.",
            "Ensure adequate water and light.",
            "Check soil moisture weekly.",
        ]

    return {
        "observations": [leaf_condition] if leaf_condition else [],
        "plant_state": plant_state,
        "diagnostic": diagnostic,
        "tips": tips,
        "analysis": {
            "species": species or "Unknown",
            "species_source": species_source,
            "species_confidence": species_confidence,
            "leaf_color": leaf_color,
            "leaf_area": leaf_area,
            "leaf_condition": leaf_condition,
            "growth_stage": growth_stage,
            "health_status": plant_state,
            "disease_signs": disease_signs or "None visible",
            "soil_observation": soil_obs or "Not visible",
            "environment_assessment": env_assessment,
        },
    }


def _fetch_sensor_readings(supabase, device_id: str) -> str:
    """
    Fetch the latest reading for each sensor type attached to this device.
    Returns a formatted string for injection into the prompt, or empty string on failure.
    """
    try:
        # Get all sensors for this device with their type keys and units
        sensors = supabase.table("sensors").select(
            "id, label, sensor_types(key, name, unit)"
        ).eq("device_id", device_id).execute().data

        if not sensors:
            return ""

        lines = []
        for sensor in sensors:
            sensor_id = sensor["id"]
            st = sensor.get("sensor_types") or {}
            key = st.get("key", "unknown")
            name = st.get("name", key)
            unit = st.get("unit", "")
            label = sensor.get("label") or name

            # Get latest reading for this sensor
            reading = supabase.table("readings").select("value, ts").eq(
                "sensor_id", sensor_id
            ).order("ts", desc=True).limit(1).execute().data

            if reading:
                val = reading[0]["value"]
                ts = reading[0]["ts"][:16].replace("T", " ")  # trim to minutes
                lines.append(f"  - {label} ({key}): {val} {unit}  [at {ts}]")

        return "\n".join(lines) if lines else ""
    except Exception as e:
        print(f"Warning: could not fetch sensor readings: {e}", file=sys.stderr)
        return ""


# ---------------------------------------------------------------------------
# Stub fallbacks
# ---------------------------------------------------------------------------
def _stub_result(_image_bytes) -> dict:
    return {
        "observations": ["Plant visible", "Leaves present"],
        "plant_state": "healthy",
        "diagnostic": "Plant appears healthy based on image analysis. (stub — run: ollama pull moondream:1.8b)",
        "tips": [
            "Continue current watering schedule.",
            "Ensure adequate light exposure.",
            "Monitor for pests weekly.",
        ],
    }


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
def main():
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_ANON_KEY")
    if not url or not key:
        print("Error: Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env or environment.", file=sys.stderr)
        sys.exit(1)

    model_version = f"ollama/{OLLAMA_MODEL}" if HAS_OLLAMA else "stub"
    print(f"AI Worker starting. Model: {model_version}")
    print(f"Polling for pending jobs every 10s ...")

    supabase = create_client(url, key)
    current_job_id = None

    while True:
        try:
            rows = supabase.table("ai_capture_jobs").select("*").eq("status", "pending").limit(1).execute()
            if not rows.data:
                # Recover stale jobs that got stuck in processing due crash/network issues.
                processing_rows = supabase.table("ai_capture_jobs").select("*").eq(
                    "status", "processing"
                ).order("created_at", desc=False).limit(1).execute()
                if processing_rows.data:
                    processing_job = processing_rows.data[0]
                    created_at = _parse_iso_ts(processing_job.get("created_at"))
                    if created_at:
                        age_seconds = (datetime.now(timezone.utc) - created_at).total_seconds()
                        if age_seconds > PROCESSING_TIMEOUT_SECONDS:
                            stale_id = processing_job["id"]
                            # If the job is too old to be worth retrying, mark it failed.
                            if MAX_RECOVERY_AGE_SECONDS > 0 and age_seconds > MAX_RECOVERY_AGE_SECONDS:
                                print(
                                    f"[{datetime.now().strftime('%H:%M:%S')}] "
                                    f"Abandoning old stale job {stale_id} "
                                    f"(age {int(age_seconds / 3600):.1f}h > limit {MAX_RECOVERY_AGE_SECONDS // 3600}h)"
                                )
                                supabase.table("ai_capture_jobs").update({"status": "failed"}).eq(
                                    "id", stale_id
                                ).execute()
                            else:
                                print(
                                    f"[{datetime.now().strftime('%H:%M:%S')}] "
                                    f"Re-queuing stale processing job {stale_id} "
                                    f"(age {int(age_seconds)}s)"
                                )
                                supabase.table("ai_capture_jobs").update({"status": "pending"}).eq(
                                    "id", stale_id
                                ).execute()
                            time.sleep(1)
                            continue
                time.sleep(10)
                continue

            job = rows.data[0]
            job_id = job["id"]
            current_job_id = job_id
            device_id = job["device_id"]
            image_storage_path = job.get("image_url")

            print(f"[{datetime.now().strftime('%H:%M:%S')}] Processing job {job_id} (image: {image_storage_path})")
            supabase.table("ai_capture_jobs").update({"status": "processing"}).eq("id", job_id).execute()

            image_bytes = _fetch_image_bytes(supabase, image_storage_path) if image_storage_path else None
            sensor_context = _fetch_sensor_readings(supabase, device_id)
            if sensor_context:
                print(f"  -> Sensor context:\n{sensor_context}")

            if HAS_OLLAMA and image_bytes:
                result = _run_ollama(image_bytes, sensor_context)
            else:
                result = _stub_result(image_bytes)

            vision_result = {
                "observations": result["observations"],
                "plant_state": result["plant_state"],
            }
            llm_result = {
                "diagnostic": result["diagnostic"],
                "tips": result["tips"],
                "analysis": result.get("analysis", {}),
            }

            supabase.table("ai_capture_jobs").update({
                "status": "completed",
                "vision_result": vision_result,
                "llm_result": llm_result,
                "processed_at": datetime.now(timezone.utc).isoformat(),
            }).eq("id", job_id).execute()

            supabase.table("ml_inferences").insert({
                "device_id": device_id,
                "result": {
                    "vision": vision_result,
                    "llm": llm_result,
                    "sensor_snapshot": sensor_context,
                },
                "diagnostic": result["diagnostic"],
                "tips": result["tips"],
                "image_url": image_storage_path,
                "model_version": model_version[:100],
                "job_id": job_id,
            }).execute()

            print(f"  -> Done. State: {result['plant_state']} | {result['diagnostic'][:80]}...")
            current_job_id = None

        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)
            if current_job_id:
                try:
                    supabase.table("ai_capture_jobs").update({"status": "failed"}).eq("id", current_job_id).execute()
                except Exception:
                    pass
            current_job_id = None
            time.sleep(30)


if __name__ == "__main__":
    main()
