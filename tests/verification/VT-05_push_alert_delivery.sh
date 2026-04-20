#!/usr/bin/env bash
# VT-05: Push alert delivery time
# Spec: Alerts delivered to device < 2s
# n: 10 trials
# Method: Insert alert (T1), poll for notify_completed_at (T2), user presses ENTER on buzz (T3)
# Requires: notify-alert Edge Function with Resend/Twilio configured in Supabase dashboard

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
load_env
require_vars SUPABASE_URL SUPABASE_ANON_KEY SUPABASE_DEVICE_ID

RESULTS_CSV="$RESULTS_DIR/VT-05_results.csv"
EVIDENCE_TXT="$RESULTS_DIR/VT-05_evidence.txt"
SPEC_MS=2000
NOTIFY_TIMEOUT=30  # seconds to wait for notify_completed_at

# Use distinct alert types per trial to avoid issue_key deduplication
TYPES=(threshold_temp_c threshold_humidity threshold_soil_moisture
       water_level_low threshold_gas_resistance threshold_pressure
       threshold_temp_c threshold_humidity threshold_soil_moisture water_level_low)

init_results "$RESULTS_CSV" "trial_num,alert_id,inject_to_notified_ms,inject_to_receipt_ms,notify_completed,spec_ms,pass_fail"
> "$EVIDENCE_TXT"
log_evidence "$EVIDENCE_TXT" "VT-05 Push Alert Delivery — $(now_iso)"

echo "=== VT-05: Push Alert Delivery Time ==="
echo "Spec: alert delivered to device in < ${SPEC_MS}ms"
echo "IMPORTANT: This test requires Resend/Twilio configured in the notify-alert Edge Function."
echo "Have your phone/notification device ready with the PhytoPi app in background."
echo "Press ENTER to begin..."
read -r

TIMES=""; PASS=0; FAIL=0
N=${#TYPES[@]}

for i in "${!TYPES[@]}"; do
    TRIAL=$(( i + 1 ))
    ATYPE="${TYPES[$i]}"
    TS=$(now_iso)

    echo ""
    echo "Trial $TRIAL/$N — type: $ATYPE"

    # T1: inject alert
    T0_NS=$(date +%s%N)
    http_call POST "$SUPABASE_URL/rest/v1/alerts" "$SUPABASE_ANON_KEY" \
        "{\"device_id\":\"$SUPABASE_DEVICE_ID\",\"type\":\"$ATYPE\",\"message\":\"[VT-05 T$TRIAL] Push delivery test\",\"severity\":\"high\",\"source\":\"automated\",\"triggered_at\":\"$TS\"}"
    ALERT_ID=$(get_json_field "$HTTP_BODY" "id")
    INJECT_MS=$(( ($(date +%s%N) - T0_NS) / 1000000 ))
    echo "  Alert injected: $ALERT_ID (${INJECT_MS}ms)"
    log_evidence "$EVIDENCE_TXT" "Trial $TRIAL | id=$ALERT_ID | injected at $TS"

    # T2: poll for notify_completed_at (edge function result)
    NOTIFY_MS=""
    for s in $(seq 1 $NOTIFY_TIMEOUT); do
        sleep 1
        http_call GET \
            "$SUPABASE_URL/rest/v1/alerts?id=eq.$ALERT_ID&select=notify_completed_at" \
            "$SUPABASE_ANON_KEY"
        COMPLETED=$(get_json_field "$HTTP_BODY" "notify_completed_at")
        if [[ -n "$COMPLETED" && "$COMPLETED" != "None" && "$COMPLETED" != "null" ]]; then
            NOTIFY_MS=$(( s * 1000 + INJECT_MS ))
            echo "  Notification sent at ${s}s (~${NOTIFY_MS}ms from injection)"
            break
        fi
    done

    NOTIFY_DONE="true"
    if [[ -z "$NOTIFY_MS" ]]; then
        echo "  WARNING: notify_completed_at not set after ${NOTIFY_TIMEOUT}s."
        echo "  Check that Resend/Twilio secrets are set in Supabase Edge Function config."
        NOTIFY_DONE="false"
        NOTIFY_MS="-1"
    fi

    # T3: user presses ENTER when device buzzes
    printf "  Press ENTER when your device receives the notification... "
    read -r
    TOTAL_MS=$(( ($(date +%s%N) - T0_NS) / 1000000 ))
    echo "  Total delivery time: ${TOTAL_MS}ms"

    if (( TOTAL_MS < SPEC_MS )); then
        VERDICT="PASS"; (( PASS++ )) || true
    else
        VERDICT="FAIL"; (( FAIL++ )) || true
    fi

    log_csv "$RESULTS_CSV" "$TRIAL,$ALERT_ID,$NOTIFY_MS,$TOTAL_MS,$NOTIFY_DONE,$SPEC_MS,$VERDICT"
    log_evidence "$EVIDENCE_TXT" "  notify=${NOTIFY_MS}ms receipt=${TOTAL_MS}ms | $VERDICT"
    TIMES="${TIMES:+$TIMES,}$TOTAL_MS"

    # Resolve alert to stop escalation
    [[ -n "$ALERT_ID" ]] && http_call_prefer PATCH \
        "$SUPABASE_URL/rest/v1/alerts?id=eq.$ALERT_ID" \
        "$SUPABASE_ANON_KEY" \
        "{\"resolved_at\":\"$(now_iso)\"}" \
        "return=minimal"
done

echo ""
echo "=== VT-05 RESULTS ==="
SUMMARY=$(print_stats "VT-05" "$TIMES" "$SPEC_MS")
echo "$SUMMARY"
echo "Pass: $PASS/$N | Fail: $FAIL/$N"
echo ""
echo "--- ONE-LINER ---"
echo "$SUMMARY | $PASS/$N reliable"
