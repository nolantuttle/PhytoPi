#!/usr/bin/env bash
# VT-10: Store automated/manual actions
# Spec: Stored < 500ms, structured, retained >= 90 days
# n: 10 trials (5 manual pump commands, 5 automated/schedule-triggered commands)
# Fully automated

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
load_env
require_vars SUPABASE_URL SUPABASE_ANON_KEY SUPABASE_SERVICE_ROLE_KEY SUPABASE_DEVICE_ID

RESULTS_CSV="$RESULTS_DIR/VT-10_results.csv"
EVIDENCE_TXT="$RESULTS_DIR/VT-10_evidence.txt"
SPEC_MS=500

REQUIRED_FIELDS=(id device_id command_type payload status created_at)

init_results "$RESULTS_CSV" "trial_num,source_type,command_type,record_id,post_ms,fields_complete,pass_fail"
> "$EVIDENCE_TXT"
log_evidence "$EVIDENCE_TXT" "VT-10 Store Actions — $(now_iso)"

echo "=== VT-10: Store Automated/Manual Actions ==="
echo "Spec: commands stored in < ${SPEC_MS}ms, all required fields present"
echo ""

TIMES=""; PASS=0; FAIL=0
INSERTED_IDS=""

for TRIAL in $(seq 1 10); do
    if (( TRIAL <= 5 )); then
        SOURCE="manual"
        PAYLOAD="{\"state\":true,\"duration_sec\":30,\"source\":\"manual\",\"trial\":$TRIAL}"
    else
        SOURCE="automated"
        PAYLOAD="{\"state\":true,\"duration_sec\":60,\"source\":\"automated\",\"trigger\":\"schedule\",\"trial\":$TRIAL}"
    fi

    BODY="{
      \"device_id\": \"$SUPABASE_DEVICE_ID\",
      \"command_type\": \"toggle_pump\",
      \"payload\": $PAYLOAD,
      \"status\": \"pending\"
    }"

    http_call POST "$SUPABASE_URL/rest/v1/device_commands" \
        "$SUPABASE_SERVICE_ROLE_KEY" "$BODY"
    POST_MS=$HTTP_MS
    RECORD_ID=$(get_json_field "$HTTP_BODY" "id")

    # Fallback: if POST returned no body (return=minimal default), fetch last inserted row
    if [[ -z "$RECORD_ID" ]]; then
        http_call GET \
            "$SUPABASE_URL/rest/v1/device_commands?device_id=eq.$SUPABASE_DEVICE_ID&order=created_at.desc&limit=1" \
            "$SUPABASE_SERVICE_ROLE_KEY"
        RECORD_ID=$(get_json_field "$HTTP_BODY" "id")
    fi

    # GET back and verify all required fields present
    http_call GET \
        "$SUPABASE_URL/rest/v1/device_commands?id=eq.$RECORD_ID" \
        "$SUPABASE_SERVICE_ROLE_KEY"
    RECORD="$HTTP_BODY"

    MISSING=""
    for field in "${REQUIRED_FIELDS[@]}"; do
        VAL=$(get_json_field "$RECORD" "$field")
        if [[ -z "$VAL" || "$VAL" == "None" ]]; then
            MISSING="${MISSING:+$MISSING,}$field"
        fi
    done
    FIELDS_OK=$([[ -z "$MISSING" ]] && echo "true" || echo "false (missing: $MISSING)")

    if [[ "$FIELDS_OK" == "true" && $POST_MS -lt $SPEC_MS ]]; then
        VERDICT="PASS"; (( PASS++ )) || true
    else
        VERDICT="FAIL"; (( FAIL++ )) || true
    fi

    printf "Trial %2d/10 | %-9s | post=%3dms fields=%s → %s\n" \
        "$TRIAL" "$SOURCE" "$POST_MS" "$FIELDS_OK" "$VERDICT"
    log_csv "$RESULTS_CSV" "$TRIAL,$SOURCE,toggle_pump,$RECORD_ID,$POST_MS,\"$FIELDS_OK\",$VERDICT"
    log_evidence "$EVIDENCE_TXT" "Trial $TRIAL | $SOURCE | id=$RECORD_ID | ${POST_MS}ms | $VERDICT"
    log_evidence "$EVIDENCE_TXT" "  Record: $RECORD"
    TIMES="${TIMES:+$TIMES,}$POST_MS"
    INSERTED_IDS="${INSERTED_IDS:+$INSERTED_IDS,}\"$RECORD_ID\""
done

# Retention check: any commands older than 90 days?
SINCE_90D=$(python3 -c "
from datetime import datetime, timezone, timedelta
print((datetime.now(timezone.utc) - timedelta(days=90)).strftime('%Y-%m-%dT%H:%M:%SZ'))
")
http_call GET \
    "$SUPABASE_URL/rest/v1/device_commands?created_at=lte.$SINCE_90D&select=id&limit=1" \
    "$SUPABASE_SERVICE_ROLE_KEY"
OLD_COUNT=$(echo "$HTTP_BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else 0)" 2>/dev/null || echo 0)
RETENTION=$([[ $OLD_COUNT -gt 0 ]] && echo "CONFIRMED (records found >= 90 days old)" || echo "UNCONFIRMED (no records > 90 days old yet; system may be new)")
log_evidence "$EVIDENCE_TXT" "Retention check (>=90 days): $RETENTION"

echo ""
echo "=== VT-10 RESULTS ==="
SUMMARY=$(print_stats "VT-10" "$TIMES" "$SPEC_MS")
echo "$SUMMARY"
echo "Pass: $PASS/10 | Fail: $((10 - PASS))/10"
echo "Retention (>=90 days): $RETENTION"
echo ""
echo "--- ONE-LINER ---"
echo "$SUMMARY | $PASS/10 reliable | retention: $RETENTION"
