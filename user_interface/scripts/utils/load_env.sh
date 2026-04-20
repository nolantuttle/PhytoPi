#!/bin/bash
# Load environment variables from .env files
# Usage: source scripts/load_env.sh

# Get the dashboard directory (parent of scripts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Script is in scripts/utils, so go up two levels to get to dashboard
DASHBOARD_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Function to load .env file
load_env_file() {
    local env_file="$1"
    if [ -f "$env_file" ]; then
        echo "📋 Loading environment from $env_file"
        # Export variables from .env file, ignoring comments and empty lines
        # Use set -a to automatically export variables
        set -a
        # Source the file, filtering out comments and empty lines
        while IFS= read -r line || [ -n "$line" ]; do
            # Skip comments and empty lines
            if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
                continue
            fi
            # Export the variable
            export "$line" 2>/dev/null || true
        done < <(grep -v '^#' "$env_file" | grep -v '^$')
        set +a
        return 0
    fi
    return 1
}

# Detect platform if not set
detect_platform() {
    if [ -z "$PLATFORM" ]; then
        # Check if we're building for a specific platform
        if echo "$@" | grep -q "android"; then
            PLATFORM="android"
        elif echo "$@" | grep -q "ios"; then
            PLATFORM="ios"
        elif echo "$@" | grep -q "kiosk\|linux"; then
            PLATFORM="kiosk"
        elif echo "$@" | grep -q "web"; then
            PLATFORM="web"
        fi
    fi
}

# Try to load .env files in order of priority:
# 1. .env.local (local development overrides, highest priority)
# 2. .env.{platform} (platform-specific, e.g., .env.android, .env.ios, .env.kiosk)
# 3. .env (general configuration)
# 4. .env.production (production, if explicitly set)

# Load .env.local first (highest priority)
if load_env_file "$DASHBOARD_DIR/.env.local"; then
    echo "✅ Loaded .env.local (highest priority)"
# Try platform-specific files if platform is detected
elif [ -n "$PLATFORM" ] && load_env_file "$DASHBOARD_DIR/.env.$PLATFORM"; then
    echo "✅ Loaded .env.$PLATFORM"
# Load general .env file
elif load_env_file "$DASHBOARD_DIR/.env"; then
    echo "✅ Loaded .env"
# Load production file as fallback
elif load_env_file "$DASHBOARD_DIR/.env.production"; then
    echo "✅ Loaded .env.production"
else
    echo "⚠️  No .env file found. Using environment variables or defaults."
    echo "   Create .env or .env.local from env.example"
    echo "   Or run: ./scripts/utils/setup_env.sh [web|android|ios|kiosk|production]"
fi

# Set Android SDK paths (if not already set)
if [ -z "$ANDROID_HOME" ]; then
    if [ -d "/opt/android-sdk" ]; then
        export ANDROID_HOME=/opt/android-sdk
        export ANDROID_SDK_ROOT=/opt/android-sdk
        export PATH=$PATH:$ANDROID_HOME/platform-tools
        echo "✅ Set Android SDK paths"
    fi
fi

