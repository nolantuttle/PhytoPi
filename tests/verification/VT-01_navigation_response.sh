#!/usr/bin/env bash
# VT-01: Navigation menu response time
# Spec: All menus reachable, response < 1s
# n: 10 trials across all menu items
# Method: Manual runner — start timer on prompt, press ENTER when screen renders

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
load_env
require_vars SUPABASE_URL

RESULTS_CSV="$RESULTS_DIR/VT-01_results.csv"
EVIDENCE_TXT="$RESULTS_DIR/VT-01_evidence.txt"
SPEC_MS=1000

SCREENS=(
    "Home/Dashboard|Tap tab 1 (home icon)"
    "Devices|Tap tab 2 (devices icon)"
    "Charts|Tap tab 3 (chart/graph icon)"
    "Alerts|Tap tab 4 (bell icon)"
    "AI Health|Tap tab 5 (AI/plant icon)"
    "Profile|Tap tab 6 (person icon)"
    "Camera|Tap the camera icon on the Dashboard screen"
    "Home/Dashboard (return)|Tap tab 1 to navigate back home"
    "Charts (2nd run)|Tap tab 3 again"
    "Alerts (2nd run)|Tap tab 4 again"
)

init_results "$RESULTS_CSV" "trial_num,screen_name,response_time_ms,spec_ms,pass_fail"
> "$EVIDENCE_TXT"
log_evidence "$EVIDENCE_TXT" "VT-01 Navigation Response Time — $(now_iso)"

echo "=== VT-01: Navigation Response Time ==="
echo "Spec: each navigation renders in < ${SPEC_MS}ms"
echo "Open the PhytoPi app on your device, navigate to Home/Dashboard first."
echo "Press ENTER to begin..."
read -r

TIMES=""; PASS=0; FAIL=0
N=${#SCREENS[@]}

for i in "${!SCREENS[@]}"; do
    TRIAL=$(( i + 1 ))
    IFS="|" read -r SCREEN_NAME ACTION <<< "${SCREENS[$i]}"

    echo ""
    echo "Trial $TRIAL/$N — $SCREEN_NAME"
    echo "  → $ACTION"
    printf "  Timer starts NOW. Press ENTER the moment the screen finishes rendering... "

    T0=$(date +%s%N)
    read -r
    ELAPSED=$(( ($(date +%s%N) - T0) / 1000000 ))

    if (( ELAPSED < SPEC_MS )); then
        VERDICT="PASS"; (( PASS++ )) || true
    else
        VERDICT="FAIL"; (( FAIL++ )) || true
    fi

    echo "  ${ELAPSED}ms — $VERDICT"
    log_csv "$RESULTS_CSV" "$TRIAL,\"$SCREEN_NAME\",$ELAPSED,$SPEC_MS,$VERDICT"
    log_evidence "$EVIDENCE_TXT" "Trial $TRIAL | $SCREEN_NAME | ${ELAPSED}ms | $VERDICT"
    TIMES="${TIMES:+$TIMES,}$ELAPSED"
done

echo ""
echo "=== VT-01 RESULTS ==="
SUMMARY=$(print_stats "VT-01" "$TIMES" "$SPEC_MS")
echo "$SUMMARY"
echo "Pass: $PASS/$N | Fail: $FAIL/$N"
echo ""
echo "--- ONE-LINER ---"
echo "$SUMMARY | $PASS/$N reliable"
