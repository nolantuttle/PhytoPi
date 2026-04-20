#!/bin/bash
# Start Android Emulator
# Usage: ./scripts/dev/start_emulator.sh [emulator_name]

EMULATOR_NAME="${1:-phytopi_emulator}"

echo "📱 Starting Android Emulator"
echo "============================"
echo ""

# Navigate to dashboard directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$DASHBOARD_DIR"

# Set Android SDK paths
if [ -z "$ANDROID_HOME" ]; then
    if [ -d "/opt/android-sdk" ]; then
        export ANDROID_HOME=/opt/android-sdk
        export ANDROID_SDK_ROOT=/opt/android-sdk
    fi
fi

# Check if Flutter emulators are available
echo "🔍 Checking available emulators..."
EMULATOR_LIST=$(flutter emulators 2>/dev/null)

if [ -z "$EMULATOR_LIST" ] || echo "$EMULATOR_LIST" | grep -q "No emulators found"; then
    echo "❌ No emulators found"
    echo ""
    echo "   Create an emulator first:"
    echo "   ./scripts/dev/setup_emulator.sh"
    echo ""
    echo "   Or using Android Studio:"
    echo "   1. Open Android Studio"
    echo "   2. Tools → Device Manager"
    echo "   3. Create a new AVD"
    echo ""
    exit 1
fi

echo "$EMULATOR_LIST"
echo ""

# Check if specified emulator exists
if echo "$EMULATOR_LIST" | grep -q "$EMULATOR_NAME"; then
    echo "✅ Found emulator: $EMULATOR_NAME"
    echo ""
    echo "🚀 Starting emulator..."
    echo "   (This may take a minute or two)"
    echo ""
    
    # Start emulator in background
    flutter emulators --launch "$EMULATOR_NAME" &
    EMULATOR_PID=$!
    
    echo "   Emulator starting (PID: $EMULATOR_PID)"
    echo "   Waiting for emulator to boot..."
    echo ""
    
    # Wait for emulator to be ready
    MAX_WAIT=120
    WAIT_TIME=0
    while [ $WAIT_TIME -lt $MAX_WAIT ]; do
        if adb devices | grep -q "emulator.*device"; then
            echo "✅ Emulator is ready!"
            echo ""
            echo "   Device status:"
            adb devices
            echo ""
            echo "   You can now run:"
            echo "   ./scripts/dev/test_android.sh"
            echo ""
            exit 0
        fi
        sleep 2
        WAIT_TIME=$((WAIT_TIME + 2))
        echo "   Waiting... ($WAIT_TIME/$MAX_WAIT seconds)"
    done
    
    echo "⚠️  Emulator is taking longer than expected to start"
    echo "   Check if the emulator window opened"
    echo "   You can check status with: adb devices"
    echo ""
else
    echo "⚠️  Emulator '$EMULATOR_NAME' not found"
    echo ""
    echo "   Available emulators:"
    echo "$EMULATOR_LIST" | grep -E "^  " | sed 's/^/   /'
    echo ""
    echo "   To use a different emulator:"
    echo "   ./scripts/dev/start_emulator.sh <emulator-name>"
    echo ""
    echo "   Or create a new emulator:"
    echo "   ./scripts/dev/setup_emulator.sh"
    echo ""
    exit 1
fi

