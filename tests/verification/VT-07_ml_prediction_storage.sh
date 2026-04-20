#!/usr/bin/env bash
# VT-07: ML prediction storage
# Spec: Stored < 500ms, accessible for dashboard
# n: 10 trials
# Method: POST directly to ml_inferences (service role bypasses RLS — AI worker does the same),
#         time POST -> DB commit, then GET back and verify retrieval

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
load_env
require_vars SUPABASE_URL SUPABASE_ANON_KEY SUPABASE_SERVICE_ROLE_KEY SUPABASE_DEVICE_ID

RESULTS_CSV="$RESULTS_DIR/VT-07_results.csv"
EVIDENCE_TXT="$RESULTS_DIR/VT-07_evidence.txt"
SPEC_MS=500

init_results "$RESULTS_CSV" "trial_num,record_id,post_ms,retrieved,pass_fail"
> "$EVIDENCE_TXT"
log_evidence "$EVIDENCE_TXT" "VT-07 ML Prediction Storage — $(now_iso)"

echo "=== VT-07: ML Prediction Storage ==="
echo "Spec: prediction stored and retrievable in < ${SPEC_MS}ms"
echo "Using service role key (same privilege level as AI worker)."
echo ""

TIMES=""; PASS=0; FAIL=0
INSERTED_IDS=""

for TRIAL in $(seq 1 10); do
    TS=$(now_iso)
    CONFIDENCE=$(python3 -c "import random; print(round(random.uniform(0.70,0.99),4))")
    PAYLOAD="{
      \"device_id\": \"$SUPABASE_DEVICE_ID\",
      \"timestamp\": \"$TS\",
      \"result\": {\"health\": \"good\", \"notes\": \"VT-07 trial $TRIAL\"},
      \"confidence\": $CONFIDENCE,
      \"image_url\": \"https://example.com/test-image-$TRIAL.jpg\",
      \"model_version\": \"moondream-1.8b\",
      \"processing_time_ms\": $((RANDOM % 3000 + 500)),
      \"diagnostic\": \"Plant appears healthy. VT-07 test record.\",
      \"tips\": [\"Keep watering schedule\", \"Good light levels\"]
    }"

    http_call POST "$SUPABASE_URL/rest/v1/ml_inferences" \
        "$SUPABASE_SERVICE_ROLE_KEY" "$PAYLOAD"
    POST_MS=$HTTP_MS
    RECORD_ID=$(get_json_field "$HTTP_BODY" "id")

    # Immediately GET it back to verify retrieval
    http_call GET \
        "$SUPABASE_URL/rest/v1/ml_inferences?id=eq.$RECORD_ID&select=id,confidence,diagnostic" \
        "$SUPABASE_SERVICE_ROLE_KEY"
    RETRIEVED_ID=$(get_json_field "$HTTP_BODY" "id")
    RETRIEVED=$([ "$RETRIEVED_ID" = "$RECORD_ID" ] && echo "true" || echo "false")

    TOTAL_MS=$(( POST_MS + HTTP_MS ))

    if [[ "$RETRIEVED" == "true" && $TOTAL_MS -lt $SPEC_MS ]]; then
        VERDICT="PASS"; (( PASS++ )) || true
    else
        VERDICT="FAIL"; (( FAIL++ )) || true
    fi

    printf "Trial %2d/10 | post=%3dms retrieved=%s → %s\n" "$TRIAL" "$POST_MS" "$RETRIEVED" "$VERDICT"
    log_csv "$RESULTS_CSV" "$TRIAL,$RECORD_ID,$POST_MS,$RETRIEVED,$VERDICT"
    log_evidence "$EVIDENCE_TXT" "Trial $TRIAL | id=$RECORD_ID | confidence=$CONFIDENCE | post=${POST_MS}ms | $VERDICT"
    log_evidence "$EVIDENCE_TXT" "  Response: $HTTP_BODY"
    TIMES="${TIMES:+$TIMES,}$POST_MS"
    INSERTED_IDS="${INSERTED_IDS:+$INSERTED_IDS,}$RECORD_ID"
done

echo ""
echo "=== VT-07 RESULTS ==="
SUMMARY=$(print_stats "VT-07" "$TIMES" "$SPEC_MS")
echo "$SUMMARY"
echo "Pass: $PASS/10 | Fail: $((10 - PASS))/10"
echo ""
echo "--- ONE-LINER ---"
echo "$SUMMARY | $PASS/10 reliable"
