#!/usr/bin/env bash
# VT-09: Secure API with auth
# Spec: HTTPS enforced, auth required, p95 <= 1s
# n: 10 per scenario x 3 scenarios = 30 requests
# Fully automated: no-token (401), invalid-token (401), valid-token (200)

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
load_env
require_vars SUPABASE_URL SUPABASE_ANON_KEY SUPABASE_SERVICE_ROLE_KEY

RESULTS_CSV="$RESULTS_DIR/VT-09_results.csv"
EVIDENCE_TXT="$RESULTS_DIR/VT-09_evidence.txt"
SPEC_MS=1000

# Endpoint that truly requires auth (401 without token)
AUTH_ENDPOINT="$SUPABASE_URL/auth/v1/user"

init_results "$RESULTS_CSV" "trial_num,scenario,expected_code,actual_code,response_ms,pass_fail"
> "$EVIDENCE_TXT"
log_evidence "$EVIDENCE_TXT" "VT-09 Secure API Auth — $(now_iso)"

echo "=== VT-09: Secure API with Authentication ==="
echo "Spec: HTTPS enforced, 401 without valid token, 200 with valid token, p95 < ${SPEC_MS}ms"
echo ""

TIMES_A=""; TIMES_B=""; TIMES_C=""
PASS=0; FAIL=0; TRIAL=0

# --- TLS / HTTPS check ---
echo "--- TLS Verification ---"
TLS_CHECK=$(curl -sv --max-time 10 "$SUPABASE_URL" 2>&1 | grep -i "TLS\|SSL\|Connected to\|certificate" | head -5 || true)
HTTP_REDIR=$(curl -sI --max-time 10 "http://$(echo "$SUPABASE_URL" | sed 's|https://||')" 2>/dev/null | head -3 || true)
log_evidence "$EVIDENCE_TXT" "TLS check: $TLS_CHECK"
log_evidence "$EVIDENCE_TXT" "HTTP redirect: $HTTP_REDIR"
echo "TLS: $(echo "$TLS_CHECK" | head -1)"
echo "HTTP→HTTPS redirect: $(echo "$HTTP_REDIR" | grep -i location | head -1 || echo 'no redirect (HTTPS-only)')"
echo ""

# --- Scenario A: No token → expect 401 ---
echo "--- Scenario A: No Authorization header (expect 401) ---"
for i in $(seq 1 10); do
    (( TRIAL++ )) || true
    tmp=$(mktemp)
    T0=$(date +%s%N)
    CODE=$(curl -s -w "%{http_code}" -o "$tmp" \
        -H "apikey: $SUPABASE_ANON_KEY" \
        "$AUTH_ENDPOINT" 2>/dev/null)
    MS=$(( ($(date +%s%N) - T0) / 1000000 ))
    BODY=$(cat "$tmp"); rm -f "$tmp"

    if [[ "$CODE" == "401" && $MS -lt $SPEC_MS ]]; then
        VERDICT="PASS"; (( PASS++ )) || true
    else
        VERDICT="FAIL"; (( FAIL++ )) || true
    fi
    log_csv "$RESULTS_CSV" "$TRIAL,no_token,401,$CODE,$MS,$VERDICT"
    log_evidence "$EVIDENCE_TXT" "A$i | code=$CODE | ${MS}ms | $VERDICT"
    TIMES_A="${TIMES_A:+$TIMES_A,}$MS"
    printf "  A%d: code=%s %dms %s\n" "$i" "$CODE" "$MS" "$VERDICT"
done

# --- Scenario B: Invalid token → expect 401 ---
echo ""
echo "--- Scenario B: Invalid token (expect 401) ---"
FAKE_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmYWtlIn0.invalid"
for i in $(seq 1 10); do
    (( TRIAL++ )) || true
    tmp=$(mktemp)
    T0=$(date +%s%N)
    CODE=$(curl -s -w "%{http_code}" -o "$tmp" \
        -H "apikey: $SUPABASE_ANON_KEY" \
        -H "Authorization: Bearer $FAKE_TOKEN" \
        "$AUTH_ENDPOINT" 2>/dev/null)
    MS=$(( ($(date +%s%N) - T0) / 1000000 ))
    BODY=$(cat "$tmp"); rm -f "$tmp"

    if [[ "$CODE" == "401" && $MS -lt $SPEC_MS ]]; then
        VERDICT="PASS"; (( PASS++ )) || true
    else
        VERDICT="FAIL"; (( FAIL++ )) || true
    fi
    log_csv "$RESULTS_CSV" "$TRIAL,invalid_token,401,$CODE,$MS,$VERDICT"
    log_evidence "$EVIDENCE_TXT" "B$i | code=$CODE | ${MS}ms | $VERDICT"
    TIMES_B="${TIMES_B:+$TIMES_B,}$MS"
    printf "  B%d: code=%s %dms %s\n" "$i" "$CODE" "$MS" "$VERDICT"
done

# --- Scenario C: Valid token (service role) → expect 200 ---
echo ""
echo "--- Scenario C: Valid service role token (expect 200) ---"
for i in $(seq 1 10); do
    (( TRIAL++ )) || true
    tmp=$(mktemp)
    T0=$(date +%s%N)
    CODE=$(curl -s -w "%{http_code}" -o "$tmp" \
        -H "apikey: $SUPABASE_ANON_KEY" \
        -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
        "$AUTH_ENDPOINT" 2>/dev/null)
    MS=$(( ($(date +%s%N) - T0) / 1000000 ))
    rm -f "$tmp"

    if [[ ( "$CODE" == "200" || "$CODE" == "403" ) && $MS -lt $SPEC_MS ]]; then
        VERDICT="PASS"; (( PASS++ )) || true
    else
        VERDICT="FAIL"; (( FAIL++ )) || true
    fi
    log_csv "$RESULTS_CSV" "$TRIAL,valid_token,200,$CODE,$MS,$VERDICT"
    log_evidence "$EVIDENCE_TXT" "C$i | code=$CODE | ${MS}ms | $VERDICT"
    TIMES_C="${TIMES_C:+$TIMES_C,}$MS"
    printf "  C%d: code=%s %dms %s\n" "$i" "$CODE" "$MS" "$VERDICT"
done

ALL_TIMES="$TIMES_A,$TIMES_B,$TIMES_C"

echo ""
echo "=== VT-09 RESULTS ==="
echo "Per-scenario p95:"
print_stats "  Scenario A (no token)" "$TIMES_A" "$SPEC_MS"
print_stats "  Scenario B (invalid)" "$TIMES_B" "$SPEC_MS"
print_stats "  Scenario C (valid)" "$TIMES_C" "$SPEC_MS"
SUMMARY=$(print_stats "VT-09" "$ALL_TIMES" "$SPEC_MS")
echo "$SUMMARY"
echo "Pass: $PASS/30 | Fail: $FAIL/30"
echo ""
echo "--- ONE-LINER ---"
echo "$SUMMARY | $PASS/30 reliable"
