#!/usr/bin/env bash
# lib/common.sh — shared utilities for PhytoPi verification tests
# Source from each VT-XX script: source "$(dirname "$0")/lib/common.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$(cd "$TEST_DIR/../.." && pwd)/.env"
RESULTS_DIR="$TEST_DIR/results"

load_env() {
    if [[ ! -f "$ENV_FILE" ]]; then
        echo "ERROR: .env not found at $ENV_FILE" >&2
        exit 1
    fi
    set -a; source "$ENV_FILE"; set +a
}

require_vars() {
    local missing=0
    for var in "$@"; do
        if [[ -z "${!var:-}" ]]; then
            echo "ERROR: $var is not set in .env" >&2
            missing=1
        fi
    done
    [[ $missing -eq 0 ]] || exit 1
}

init_results() {
    local csv="$1" header="$2"
    mkdir -p "$RESULTS_DIR"
    [[ ! -f "$csv" ]] && echo "$header" > "$csv"
}

log_csv()      { local f="$1"; shift; echo "$@" >> "$f"; }
log_evidence() { local f="$1"; shift; echo "$@" >> "$f"; }

# Sets HTTP_CODE, HTTP_BODY, HTTP_MS globals
http_call() {
    local method="$1" url="$2" token="${3:-}" body="${4:-}"
    local tmp; tmp=$(mktemp)
    local args=(-s -X "$method" -o "$tmp" -w "%{http_code}"
        -H "apikey: ${SUPABASE_ANON_KEY}"
        -H "Content-Type: application/json")
    [[ -n "$token" ]] && args+=(-H "Authorization: Bearer $token")
    [[ -n "$body"  ]] && args+=(-d "$body" -H "Prefer: return=representation")
    local T0; T0=$(date +%s%N)
    HTTP_CODE=$(curl "${args[@]}" "$url" 2>/dev/null)
    HTTP_MS=$(( ($(date +%s%N) - T0) / 1000000 ))
    HTTP_BODY=$(cat "$tmp"); rm -f "$tmp"
}

# Like http_call with a custom Prefer header (for upserts etc.)
http_call_prefer() {
    local method="$1" url="$2" token="$3" body="$4" prefer="$5"
    local tmp; tmp=$(mktemp)
    local args=(-s -X "$method" -o "$tmp" -w "%{http_code}"
        -H "apikey: ${SUPABASE_ANON_KEY}"
        -H "Content-Type: application/json"
        -H "Prefer: $prefer")
    [[ -n "$token" ]] && args+=(-H "Authorization: Bearer $token")
    [[ -n "$body"  ]] && args+=(-d "$body")
    local T0; T0=$(date +%s%N)
    HTTP_CODE=$(curl "${args[@]}" "$url" 2>/dev/null)
    HTTP_MS=$(( ($(date +%s%N) - T0) / 1000000 ))
    HTTP_BODY=$(cat "$tmp"); rm -f "$tmp"
}

get_user_token() {
    local email="$1" password="$2" tmp
    tmp=$(mktemp)
    curl -s -X POST \
        -H "apikey: $SUPABASE_ANON_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
        -o "$tmp" \
        "$SUPABASE_URL/auth/v1/token?grant_type=password" 2>/dev/null
    python3 -c "
import json, sys
try:
    d = json.load(open('$tmp'))
    print(d.get('access_token',''))
except: print('')
"
    rm -f "$tmp"
}

get_json_field() {
    echo "$1" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    if isinstance(d,list): d=d[0] if d else {}
    print(d.get('$2',''))
except: print('')
" 2>/dev/null
}

now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

print_stats() {
    local label="$1" values="$2" threshold="${3:-}" unit="${4:-ms}"
    python3 - <<PYEOF
import sys, statistics
label, values_str, threshold_str, unit = "$label", "$values", "$threshold", "$unit"
try:
    vals = [float(v) for v in values_str.split(',') if v.strip()]
    if not vals:
        print(f"{label}: no data"); sys.exit()
    vals_s = sorted(vals)
    mean = statistics.mean(vals)
    mx   = max(vals)
    p95  = vals_s[min(int(len(vals_s)*0.95), len(vals_s)-1)]
    thr  = float(threshold_str) if threshold_str else None
    result = "PASS" if (thr is None or p95 <= thr) else "FAIL"
    print(f"{label}: {result} | mean={mean:.1f}{unit} max={mx:.0f}{unit} p95={p95:.0f}{unit} n={len(vals)}")
except Exception as e:
    print(f"{label}: ERROR — {e}")
PYEOF
}
