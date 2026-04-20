#!/bin/bash
# Test Android app on emulator
# Usage: ./scripts/dev/test_android_emulator.sh

echo "📱 Testing Android App on Emulator"
echo "==================================="
echo ""

# Navigate to dashboard directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$DASHBOARD_DIR"

# Load environment variables
UTILS_DIR="$(cd "$DASHBOARD_DIR/scripts/utils" && pwd)"
if [ -f "$UTILS_DIR/load_env.sh" ]; then
    export PLATFORM="android"
    source "$UTILS_DIR/load_env.sh"
fi

# For emulator, use 10.0.2.2 instead of local IP (this is the emulator's special IP for host machine)
echo "🔧 Configuring environment for emulator..."
echo "   Using 10.0.2.2 for Supabase (emulator's host machine IP)"
echo ""

# Override SUPABASE_URL for emulator if not already set for emulator
if [ -z "$SUPABASE_URL_EMULATOR" ]; then
    # Check if we're using localhost or local IP
    if echo "$SUPABASE_URL" | grep -q "192.168\|127.0.0.1\|localhost"; then
        export SUPABASE_URL_EMULATOR="http://10.0.2.2:54321"
        echo "   SUPABASE_URL (emulator): $SUPABASE_URL_EMULATOR"
        echo "   (10.0.2.2 is the emulator's special IP for the host machine)"
    else
        # If using remote Supabase, keep as is
        export SUPABASE_URL_EMULATOR="$SUPABASE_URL"
        echo "   SUPABASE_URL (emulator): $SUPABASE_URL_EMULATOR"
    fi
fi

# Check if emulator is running
echo "🔍 Checking for running emulator..."
EMULATOR_DEVICE=$(adb devices | grep "emulator" | grep "device" | awk '{print $1}' | head -1)

if [ -z "$EMULATOR_DEVICE" ]; then
    echo "⚠️  No emulator is running"
    echo ""
    echo "   Please start an emulator first:"
    echo ""
    echo "   Option 1: Using Android Studio (Recommended)"
    echo "   1. Open Android Studio"
    echo "   2. Tools → Device Manager"
    echo "   3. Click 'Play' button next to your AVD"
    echo ""
    echo "   Option 2: Using Flutter"
    echo "   flutter emulators --launch <emulator-name>"
    echo ""
    echo "   Option 3: Using the start script"
    echo "   ./scripts/dev/start_emulator.sh"
    echo ""
    echo "   After starting the emulator, wait for it to boot (1-2 minutes),"
    echo "   then run this script again."
    echo ""
    exit 1
fi

echo "✅ Emulator is running: $EMULATOR_DEVICE"
echo ""

# Check Flutter devices
echo "📱 Checking Flutter devices..."
FLUTTER_DEVICES=$(flutter devices)
echo "$FLUTTER_DEVICES"
echo ""

# Find Android emulator in Flutter devices
ANDROID_DEVICE=$(echo "$FLUTTER_DEVICES" | grep -i "emulator\|android" | grep -v "Linux" | head -1 | awk -F'•' '{print $2}' | xargs)

if [ -z "$ANDROID_DEVICE" ]; then
    # Try to get device ID from ADB
    ANDROID_DEVICE="$EMULATOR_DEVICE"
fi

if [ -z "$ANDROID_DEVICE" ]; then
    echo "❌ No Android emulator found in Flutter devices"
    echo "   Make sure the emulator is fully booted"
    echo "   Wait a few seconds and try again"
    exit 1
fi

echo "🎯 Using device: $ANDROID_DEVICE"
echo ""

# Verify Supabase is accessible from emulator
echo "🔍 Verifying Supabase connection..."
echo "   (This may take a moment)"
echo ""

# Use the emulator-specific URL
if [ -n "$SUPABASE_URL_EMULATOR" ]; then
    SUPABASE_URL_TO_USE="$SUPABASE_URL_EMULATOR"
else
    SUPABASE_URL_TO_USE="http://10.0.2.2:54321"
fi

echo "   SUPABASE_URL: $SUPABASE_URL_TO_USE"
echo "   SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY:0:30}..."
echo ""

# Check if Supabase is running (on host machine)
if echo "$SUPABASE_URL_TO_USE" | grep -q "10.0.2.2"; then
    # Test connection to host machine's Supabase
    HOST_SUPABASE="http://127.0.0.1:54321"
    if curl -s "$HOST_SUPABASE" > /dev/null 2>&1; then
        echo "✅ Supabase is running on host machine"
    else
        echo "⚠️  Warning: Supabase may not be running on host machine"
        echo "   Start it with: cd infra/supabase && supabase start"
        echo ""
    fi
fi

echo ""

# Get Flutter dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get
echo ""

# Run the app on emulator
echo "🚀 Running app on emulator..."
echo "   (Press 'q' to quit, 'r' to hot reload, 'R' to hot restart)"
echo ""

# Use emulator-specific Supabase URL
flutter run -d "$ANDROID_DEVICE" \
    --dart-define=SUPABASE_URL="$SUPABASE_URL_TO_USE" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

