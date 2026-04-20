#!/usr/bin/env python3
"""
PhytoPi AI Image Capture Script
Captures a still image, uploads to Supabase Storage, and creates ai_capture_jobs row.
Run from Pi controller when capture_image command is received.
Usage: capture_and_upload.py <device_id> [supabase_url] [anon_key]
Environment: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_DEVICE_ID
"""
import os
import sys
import time
import subprocess
import glob
from pathlib import Path

try:
    from supabase import create_client, Client
except ImportError:
    print("Install: pip install supabase", file=sys.stderr)
    sys.exit(1)


def find_usb_camera():
    """Auto-detect first USB camera from /dev/video* (prefer video0)."""
    devices = sorted(glob.glob("/dev/video*"))
    if not devices:
        return "/dev/video0"
    for d in devices:
        if "video0" in d:
            return d
    return devices[0]


def capture_from_mjpeg_stream(out_path: Path) -> bool:
    """Grab one JPEG frame from the phytopi-camera MJPEG stream (same Docker network)."""
    import urllib.request
    url = os.environ.get("CAMERA_STREAM_URL", "http://phytopi-camera:8000/stream.mjpg")
    try:
        with urllib.request.urlopen(url, timeout=10) as resp:
            data = b""
            while True:
                chunk = resp.read(4096)
                if not chunk:
                    break
                data += chunk
                start = data.find(b'\xff\xd8')
                if start == -1:
                    if len(data) > 2:
                        data = data[-2:]
                    continue
                end = data.find(b'\xff\xd9', start)
                if end == -1:
                    data = data[start:]
                    continue
                out_path.write_bytes(data[start:end + 2])
                return True
    except Exception as e:
        print(f"Stream capture failed ({url}): {e}", file=sys.stderr)
    return False


def capture_with_pi_camera(out_path: Path) -> bool:
    """Try rpicam-still (Bookworm) or libcamera-still (Bullseye). Returns True if capture succeeded."""
    for cmd_name in ("rpicam-still", "libcamera-still"):
        if subprocess.run(["which", cmd_name], capture_output=True).returncode != 0:
            continue
        cmd = [cmd_name, "-o", str(out_path), "-t", "1000", "-n"]
        r = subprocess.run(cmd, capture_output=True)
        if r.returncode == 0 and out_path.exists():
            return True
    return False


def capture_with_usb_camera(out_path: Path) -> bool:
    """Capture a single frame from USB camera via ffmpeg (video4linux2)."""
    if subprocess.run(["which", "ffmpeg"], capture_output=True).returncode != 0:
        return False
    dev = find_usb_camera()
    cmd = [
        "ffmpeg", "-y",
        "-f", "video4linux2", "-i", dev,
        "-frames:v", "1",
        "-vcodec", "mjpeg",
        str(out_path),
    ]
    r = subprocess.run(cmd, capture_output=True, timeout=15)
    return r.returncode == 0 and out_path.exists()


def main():
    device_id = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("SUPABASE_DEVICE_ID")
    url = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("SUPABASE_URL")
    # Prefer service role key (bypasses RLS) when available; fall back to anon key
    key = (
        os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
        or os.environ.get("SUPABASE_ANON_KEY")
    )
    if len(sys.argv) > 3:
        key = sys.argv[3]

    if not device_id or not url or not key:
        print("Usage: capture_and_upload.py <device_id> [url] [key]", file=sys.stderr)
        print("Or set SUPABASE_DEVICE_ID, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (or SUPABASE_ANON_KEY)", file=sys.stderr)
        sys.exit(1)

    ts = int(time.time())
    out_path = Path(f"/tmp/phytopi_capture_{ts}.jpg")

    # Try MJPEG stream first (camera container on same Docker network),
    # then fall back to direct Pi/USB camera access
    if capture_from_mjpeg_stream(out_path):
        pass  # success
    elif capture_with_pi_camera(out_path):
        pass  # success
    elif capture_with_usb_camera(out_path):
        pass  # success
    else:
        print("Capture failed: MJPEG stream, Pi camera, and USB camera (ffmpeg) all unavailable", file=sys.stderr)
        sys.exit(2)

    if not out_path.exists():
        print("Capture file not created", file=sys.stderr)
        sys.exit(3)

    try:
        supabase: Client = create_client(url, key)
        storage_path = f"{device_id}/{ts}.jpg"

        with open(out_path, "rb") as f:
            supabase.storage.from_("device-images").upload(
                storage_path,
                f.read(),
                file_options={"content-type": "image/jpeg"},
            )

        supabase.table("ai_capture_jobs").insert({
            "device_id": device_id,
            "image_url": storage_path,
            "status": "pending",
        }).execute()

        print(f"Uploaded {storage_path}, job created")
    except Exception as e:
        print(f"Upload failed: {e}", file=sys.stderr)
        sys.exit(4)
    finally:
        out_path.unlink(missing_ok=True)

if __name__ == "__main__":
    main()
