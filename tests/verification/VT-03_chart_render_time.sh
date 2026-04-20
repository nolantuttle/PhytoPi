#!/usr/bin/env bash
# VT-03: Growth trend chart render time
# Spec: Render < 5s, values match data
# n: 10 renders across different time windows
# Method: Manual timer + programmatic DB point count verification

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
load_env
require_vars SUPABASE_URL SUPABASE_ANON_KEY SUPABASE_SERVICE_ROLE_KEY SUPABASE_DEVICE_ID

RESULTS_CSV="$RESULTS_DIR/VT-03_results.csv"
EVIDENCE_TXT="$RESULTS_DIR/VT-03_evidence.txt"
SPEC_MS=5000

# 10 trials: 2 runs per window
WINDOWS=("1 hour" "6 hours" "24 hours" "7 days" "30 days"
         "1 hour" "6 hours" "24 hours" "7 days" "30 days")
WINDOW_HOURS=(1 6 24 168 720 1 6 24 168 720)

init_results "$RESULTS_CSV" "trial_num,window,db_point_count,render_time_ms,spec_ms,pass_fail"
> "$EVIDENCE_TXT"
log_evidence "$EVIDENCE_TXT" "VT-03 Chart Render Time — $(now_iso)"

echo "=== VT-03: Growth Trend Chart Render Time ==="
echo "Spec: chart renders in < ${SPEC_MS}ms"
echo "Open the PhytoPi app and navigate to the Charts screen."
echo "Press ENTER to begin..."
read -r

TIMES=""; PASS=0; FAIL=0
N=${#WINDOWS[@]}

for i in "${!WINDOWS[@]}"; do
    TRIAL=$(( i + 1 ))
    WINDOW="${WINDOWS[$i]}"
    HOURS="${WINDOW_HOURS[$i]}"

    # Query DB for point count in this window
    SINCE=$(python3 -c "
from datetime import datetime, timezone, timedelta
now = datetime.now(timezone.utc)
since = now - timedelta(hours=$HOURS)
print(since.strftime('%Y-%m-%dT%H:%M:%SZ'))
")
    http_call GET \
        "$SUPABASE_URL/rest/v1/readings?ts=gte.$SINCE&select=id&limit=1000" \
        "$SUPABASE_SERVICE_ROLE_KEY"
    DB_COUNT=$(echo "$HTTP_BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else 0)" 2>/dev/null || echo 0)
    log_evidence "$EVIDENCE_TXT" "Trial $TRIAL | window=$WINDOW | DB points in range: $DB_COUNT | since: $SINCE"

    echo ""
    echo "Trial $TRIAL/$N — Window: last $WINDOW"
    echo "  DB has $DB_COUNT readings in this window"
    echo "  → Select the '$WINDOW' time range on the Charts screen"
    printf "  Timer starts NOW. Press ENTER when the chart finishes rendering... "

    T0=$(date +%s%N)
    read -r
    ELAPSED=$(( ($(date +%s%N) - T0) / 1000000 ))

    if (( ELAPSED < SPEC_MS )); then
        VERDICT="PASS"; (( PASS++ )) || true
    else
        VERDICT="FAIL"; (( FAIL++ )) || true
    fi

    echo "  ${ELAPSED}ms — $VERDICT"
    log_csv "$RESULTS_CSV" "$TRIAL,\"last $WINDOW\",$DB_COUNT,$ELAPSED,$SPEC_MS,$VERDICT"
    TIMES="${TIMES:+$TIMES,}$ELAPSED"
done

echo ""
echo "=== VT-03 RESULTS ==="
SUMMARY=$(print_stats "VT-03" "$TIMES" "$SPEC_MS")
echo "$SUMMARY"
echo "Pass: $PASS/$N | Fail: $FAIL/$N"
echo ""
echo "--- ONE-LINER ---"
echo "$SUMMARY | $PASS/$N reliable"
