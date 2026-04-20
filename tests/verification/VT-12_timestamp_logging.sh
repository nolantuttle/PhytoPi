#!/usr/bin/env bash
# VT-12: Timestamp + outcome logging
# Spec: Retrieval <= 2s, logs complete (timestamp + outcome on every row)
# n: 10 trials (query last 10 device_commands, verify completeness + timing)
# Fully automated

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
load_env
require_vars SUPABASE_URL SUPABASE_ANON_KEY SUPABASE_SERVICE_ROLE_KEY SUPABASE_DEVICE_ID

RESULTS_CSV="$RESULTS_DIR/VT-12_results.csv"
EVIDENCE_TXT="$RESULTS_DIR/VT-12_evidence.txt"
SPEC_MS=2000

init_results "$RESULTS_CSV" "trial_num,record_id,has_timestamp,has_outcome,query_ms,pass_fail"
> "$EVIDENCE_TXT"
log_evidence "$EVIDENCE_TXT" "VT-12 Timestamp + Outcome Logging — $(now_iso)"

echo "=== VT-12: Timestamp + Outcome Logging ==="
echo "Spec: log retrieval <= ${SPEC_MS}ms, every record has timestamp + outcome (status)"
echo ""

# Insert 10 fresh command records so we have known data to verify
echo "Inserting 10 test command records..."
INSERTED_IDS=()
for i in $(seq 1 10); do
    http_call POST "$SUPABASE_URL/rest/v1/device_commands" \
        "$SUPABASE_SERVICE_ROLE_KEY" \
        "{\"device_id\":\"$SUPABASE_DEVICE_ID\",\"command_type\":\"toggle_light\",\"payload\":{\"state\":false,\"vt12_trial\":$i},\"status\":\"executed\"}"
    ID=$(get_json_field "$HTTP_BODY" "id")
    # Fallback if POST returned no body
    if [[ -z "$ID" ]]; then
        http_call GET \
            "$SUPABASE_URL/rest/v1/device_commands?device_id=eq.$SUPABASE_DEVICE_ID&order=created_at.desc&limit=1&select=id" \
            "$SUPABASE_SERVICE_ROLE_KEY"
        ID=$(get_json_field "$HTTP_BODY" "id")
    fi
    INSERTED_IDS+=("$ID")
done
echo "Done. Running retrieval trials..."
echo ""

TIMES=""; PASS=0; FAIL=0

for TRIAL in $(seq 1 10); do
    RECORD_ID="${INSERTED_IDS[$((TRIAL-1))]}"

    http_call GET \
        "$SUPABASE_URL/rest/v1/device_commands?id=eq.$RECORD_ID&select=id,created_at,executed_at,status,command_type" \
        "$SUPABASE_SERVICE_ROLE_KEY"
    QUERY_MS=$HTTP_MS
    RECORD="$HTTP_BODY"

    HAS_TS=$(get_json_field "$RECORD" "created_at")
    HAS_OUTCOME=$(get_json_field "$RECORD" "status")

    TS_OK=$([[ -n "$HAS_TS" && "$HAS_TS" != "None" ]] && echo "true" || echo "false")
    OUT_OK=$([[ -n "$HAS_OUTCOME" && "$HAS_OUTCOME" != "None" ]] && echo "true" || echo "false")

    if [[ "$TS_OK" == "true" && "$OUT_OK" == "true" && $QUERY_MS -lt $SPEC_MS ]]; then
        VERDICT="PASS"; (( PASS++ )) || true
    else
        VERDICT="FAIL"; (( FAIL++ )) || true
    fi

    printf "Trial %2d/10 | %dms | ts=%s outcome=%s → %s\n" \
        "$TRIAL" "$QUERY_MS" "$TS_OK" "$OUT_OK" "$VERDICT"
    log_csv "$RESULTS_CSV" "$TRIAL,$RECORD_ID,$TS_OK,$OUT_OK,$QUERY_MS,$VERDICT"
    log_evidence "$EVIDENCE_TXT" "Trial $TRIAL | id=$RECORD_ID | created_at=$HAS_TS status=$HAS_OUTCOME | ${QUERY_MS}ms | $VERDICT"
    TIMES="${TIMES:+$TIMES,}$QUERY_MS"
done

echo ""
echo "=== VT-12 RESULTS ==="
SUMMARY=$(print_stats "VT-12" "$TIMES" "$SPEC_MS")
echo "$SUMMARY"
echo "Pass: $PASS/10 | Fail: $((10-PASS))/10"
echo ""
echo "--- ONE-LINER ---"
echo "$SUMMARY | $PASS/10 reliable"
