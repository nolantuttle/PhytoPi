#!/usr/bin/env bash
# VT-04: Color-coded alert latency
# Spec: UI updates < 500ms, color matches condition
# n: 10 trials across severity levels
# Method: Inject alert via API, manual timer until UI color updates on Alerts screen
# Note: measured time includes network round-trip + realtime push + render + user reaction (~150ms)

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
load_env
require_vars SUPABASE_URL SUPABASE_ANON_KEY SUPABASE_DEVICE_ID

RESULTS_CSV="$RESULTS_DIR/VT-04_results.csv"
EVIDENCE_TXT="$RESULTS_DIR/VT-04_evidence.txt"
SPEC_MS=500

# Cycle through severities (2-3 trials each across 10)
SEVERITIES=(low medium high critical low medium high critical low medium)
TYPES=(threshold_temp_c threshold_humidity threshold_soil_moisture threshold_gas_resistance
       water_level_low threshold_temp_c threshold_humidity threshold_soil_moisture
       threshold_gas_resistance threshold_pressure)

# Expected UI color per severity (for manual verification)
declare -A COLORS
COLORS[low]="blue/green"
COLORS[medium]="yellow/orange"
COLORS[high]="orange/red"
COLORS[critical]="red/bright red"

init_results "$RESULTS_CSV" "trial_num,severity,alert_type,inject_to_enter_ms,expected_color,spec_ms,pass_fail"
> "$EVIDENCE_TXT"
log_evidence "$EVIDENCE_TXT" "VT-04 Alert Color Latency — $(now_iso)"

echo "=== VT-04: Color-Coded Alert Latency ==="
echo "Spec: UI color updates in < ${SPEC_MS}ms after injection"
echo "Open the PhytoPi app and navigate to the Alerts screen. Keep it visible."
echo "Press ENTER to begin..."
read -r

TIMES=""; PASS=0; FAIL=0
N=${#SEVERITIES[@]}

for i in "${!SEVERITIES[@]}"; do
    TRIAL=$(( i + 1 ))
    SEV="${SEVERITIES[$i]}"
    ATYPE="${TYPES[$i]}"
    COLOR="${COLORS[$SEV]}"
    TS=$(now_iso)
    MSG="[VT-04 T$TRIAL] Test alert — $SEV"

    echo ""
    echo "Trial $TRIAL/$N — Severity: $SEV (expect $COLOR in UI)"
    printf "  Injecting alert and starting timer simultaneously... "

    # Inject alert and start timer at the same moment
    T0=$(date +%s%N)
    http_call POST "$SUPABASE_URL/rest/v1/alerts" "$SUPABASE_ANON_KEY" \
        "{\"device_id\":\"$SUPABASE_DEVICE_ID\",\"type\":\"$ATYPE\",\"message\":\"$MSG\",\"severity\":\"$SEV\",\"source\":\"automated\",\"triggered_at\":\"$TS\"}"
    INJECT_MS=$HTTP_MS

    ALERT_ID=$(get_json_field "$HTTP_BODY" "id")
    log_evidence "$EVIDENCE_TXT" "Trial $TRIAL | id=$ALERT_ID | sev=$SEV | inject=${INJECT_MS}ms"

    echo "injected (${INJECT_MS}ms). Watch Alerts screen for $COLOR row..."
    printf "  Press ENTER when you see the $COLOR alert appear in the list... "
    read -r
    ELAPSED=$(( ($(date +%s%N) - T0) / 1000000 ))

    if (( ELAPSED < SPEC_MS )); then
        VERDICT="PASS"; (( PASS++ )) || true
    else
        VERDICT="FAIL"; (( FAIL++ )) || true
    fi

    echo "  ${ELAPSED}ms total (includes ~150ms reaction) — $VERDICT"
    log_csv "$RESULTS_CSV" "$TRIAL,$SEV,$ATYPE,$ELAPSED,$COLOR,$SPEC_MS,$VERDICT"
    log_evidence "$EVIDENCE_TXT" "  → elapsed=${ELAPSED}ms | $VERDICT"
    TIMES="${TIMES:+$TIMES,}$ELAPSED"

    # Mark alert resolved so it doesn't spam notifications
    if [[ -n "$ALERT_ID" ]]; then
        http_call_prefer PATCH \
            "$SUPABASE_URL/rest/v1/alerts?id=eq.$ALERT_ID" \
            "$SUPABASE_ANON_KEY" \
            "{\"resolved_at\":\"$(now_iso)\"}" \
            "return=minimal"
    fi

    sleep 1  # brief pause before next injection
done

echo ""
echo "=== VT-04 RESULTS ==="
SUMMARY=$(print_stats "VT-04" "$TIMES" "$SPEC_MS")
echo "$SUMMARY"
echo "Pass: $PASS/$N | Fail: $FAIL/$N"
echo ""
echo "--- ONE-LINER ---"
echo "$SUMMARY | $PASS/$N reliable"
