#!/usr/bin/env bash
# VT-06: Real-time dashboard refresh
# Spec: Refresh <= 1s, values match sensor input
# n: 10 trials
# Method: Insert known value (99.9X°C) to temperature sensor,
#         user presses ENTER when they see it on Dashboard

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
load_env
require_vars SUPABASE_URL SUPABASE_ANON_KEY SUPABASE_TEMPERATURE_SENSOR_ID

RESULTS_CSV="$RESULTS_DIR/VT-06_results.csv"
EVIDENCE_TXT="$RESULTS_DIR/VT-06_evidence.txt"
SPEC_MS=1000

init_results "$RESULTS_CSV" "trial_num,test_value,inject_to_seen_ms,spec_ms,pass_fail"
> "$EVIDENCE_TXT"
log_evidence "$EVIDENCE_TXT" "VT-06 Realtime Dashboard Refresh — $(now_iso)"

echo "=== VT-06: Real-Time Dashboard Refresh ==="
echo "Spec: updated value visible on Dashboard in < ${SPEC_MS}ms"
echo "Open the PhytoPi app and navigate to the Home/Dashboard screen."
echo "Watch the temperature reading — it will briefly show a test value (99.9X°C)."
echo "The firmware will overwrite it with the real reading within ~5 seconds."
echo "Press ENTER to begin..."
read -r

TIMES=""; PASS=0; FAIL=0

for TRIAL in $(seq 1 10); do
    # Unique recognizable value: 99.91, 99.92 ... 99.99, 100.00
    TEST_VAL=$(python3 -c "print(f'{99.9 + $TRIAL * 0.01:.2f}')")
    TS=$(now_iso)

    echo ""
    echo "Trial $TRIAL/10 — Inserting temperature = ${TEST_VAL}°C"
    printf "  Watch the Dashboard temperature widget. Timer starts on injection... "

    T0=$(date +%s%N)
    http_call POST "$SUPABASE_URL/rest/v1/readings" "$SUPABASE_ANON_KEY" \
        "[{\"sensor_id\":\"$SUPABASE_TEMPERATURE_SENSOR_ID\",\"value\":$TEST_VAL,\"ts\":\"$TS\",\"metadata\":{\"test\":\"VT-06\",\"trial\":$TRIAL}}]"
    INJECT_MS=$HTTP_MS

    READING_ID=$(echo "$HTTP_BODY" | python3 -c "
import sys,json
d=json.load(sys.stdin)
if isinstance(d,list) and d: print(d[0].get('id',''))
else: print('')
" 2>/dev/null || echo "")

    echo "injected (${INJECT_MS}ms)."
    printf "  Press ENTER the moment you see ${TEST_VAL} on the Dashboard... "
    read -r
    ELAPSED=$(( ($(date +%s%N) - T0) / 1000000 ))

    if (( ELAPSED < SPEC_MS )); then
        VERDICT="PASS"; (( PASS++ )) || true
    else
        VERDICT="FAIL"; (( FAIL++ )) || true
    fi

    echo "  ${ELAPSED}ms — $VERDICT"
    log_csv "$RESULTS_CSV" "$TRIAL,$TEST_VAL,$ELAPSED,$SPEC_MS,$VERDICT"
    log_evidence "$EVIDENCE_TXT" "Trial $TRIAL | val=$TEST_VAL id=$READING_ID | inject=${INJECT_MS}ms total=${ELAPSED}ms | $VERDICT"
    TIMES="${TIMES:+$TIMES,}$ELAPSED"

    sleep 2  # let firmware overwrite test value before next trial
done

echo ""
echo "=== VT-06 RESULTS ==="
SUMMARY=$(print_stats "VT-06" "$TIMES" "$SPEC_MS")
echo "$SUMMARY"
echo "Pass: $PASS/10 | Fail: $((10 - PASS))/10"
echo ""
echo "--- ONE-LINER ---"
echo "$SUMMARY | $PASS/10 reliable"
