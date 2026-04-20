#!/bin/bash
# Setup Android Emulator for testing
# Usage: ./scripts/dev/setup_emulator.sh

echo "📱 Android Emulator Setup"
echo "========================"
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

# Set Android SDK paths
if [ -z "$ANDROID_HOME" ]; then
    if [ -d "/opt/android-sdk" ]; then
        export ANDROID_HOME=/opt/android-sdk
        export ANDROID_SDK_ROOT=/opt/android-sdk
    fi
fi

if [ -z "$ANDROID_HOME" ]; then
    echo "❌ Android SDK not found"
    echo "   Make sure ANDROID_HOME is set or Android SDK is at /opt/android-sdk"
    exit 1
fi

echo "📋 Android SDK: $ANDROID_HOME"
echo ""

# Check if emulator is available
EMULATOR="$ANDROID_HOME/emulator/emulator"
if [ ! -f "$EMULATOR" ]; then
    echo "❌ Android Emulator not found"
    echo ""
    echo "   You need to install Android Emulator:"
    echo ""
    echo "   Option 1: Install Android Studio (Recommended)"
    echo "   - Download from: https://developer.android.com/studio"
    echo "   - Or install via AUR: yay -S android-studio"
    echo "   - Open Android Studio → Tools → SDK Manager"
    echo "   - Install 'Android SDK Platform-Tools' and 'Android Emulator'"
    echo ""
    echo "   Option 2: Install via command line (if sdkmanager is available)"
    echo "   - Install system images and emulator:"
    echo "     sdkmanager 'system-images;android-33;google_apis;x86_64'"
    echo "     sdkmanager 'emulator'"
    echo ""
    exit 1
fi

echo "✅ Android Emulator found: $EMULATOR"
echo ""

# Check available system images
echo "🔍 Checking available system images..."
SYSTEM_IMAGES=$(find "$ANDROID_HOME/system-images" -name "system.img" 2>/dev/null | head -5)
if [ -z "$SYSTEM_IMAGES" ]; then
    echo "⚠️  No system images found"
    echo ""
    echo "   You need to install a system image first:"
    echo ""
    echo "   Option 1: Using Android Studio"
    echo "   1. Open Android Studio"
    echo "   2. Tools → SDK Manager"
    echo "   3. SDK Platforms tab"
    echo "   4. Check a system image (e.g., Android 13 - API 33)"
    echo "   5. Apply"
    echo ""
    echo "   Option 2: Using sdkmanager (if available)"
    echo "   $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager 'system-images;android-33;google_apis;x86_64'"
    echo ""
    exit 1
fi

echo "✅ System images found"
echo ""

# List available emulators
echo "📱 Checking for existing emulators..."
flutter emulators 2>/dev/null || echo "   No emulators found via Flutter"
echo ""

# Check if AVD directory exists
AVD_DIR="$HOME/.android/avd"
mkdir -p "$AVD_DIR"

# Try to list AVDs
if [ -d "$AVD_DIR" ] && [ "$(ls -A $AVD_DIR 2>/dev/null)" ]; then
    echo "✅ Existing AVDs found:"
    ls -1 "$AVD_DIR" | grep -E "\.avd$" | sed 's/\.avd$//' | sed 's/^/   - /'
    echo ""
else
    echo "⚠️  No existing AVDs found"
    echo ""
fi

# Check if phytopi_emulator exists
EMULATOR_NAME="phytopi_emulator"
if [ -f "$AVD_DIR/${EMULATOR_NAME}.avd/config.ini" ]; then
    echo "✅ PhytoPi emulator already exists: $EMULATOR_NAME"
    echo ""
    echo "   To start it:"
    echo "   flutter emulators --launch $EMULATOR_NAME"
    echo "   or"
    echo "   ./scripts/dev/start_emulator.sh"
    echo ""
    exit 0
fi

echo "📱 Creating PhytoPi emulator..."
echo ""

# Find available system images
AVAILABLE_IMAGES=$(find "$ANDROID_HOME/system-images" -name "source.properties" 2>/dev/null | head -1)
if [ -z "$AVAILABLE_IMAGES" ]; then
    echo "❌ No system images found"
    echo "   Install a system image first (see instructions above)"
    exit 1
fi

# Extract system image path
SYSTEM_IMAGE_DIR=$(dirname "$AVAILABLE_IMAGES")
SYSTEM_IMAGE_NAME=$(basename "$(dirname "$SYSTEM_IMAGE_DIR")")

echo "   Using system image: $SYSTEM_IMAGE_NAME"
echo ""

# Try to create AVD using avdmanager
AVDMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager"
if [ ! -f "$AVDMANAGER" ]; then
    # Try to find avdmanager
    AVDMANAGER=$(find "$ANDROID_HOME" -name "avdmanager" 2>/dev/null | head -1)
fi

if [ -f "$AVDMANAGER" ]; then
    echo "   Creating AVD with avdmanager..."
    "$AVDMANAGER" create avd -n "$EMULATOR_NAME" -k "$SYSTEM_IMAGE_NAME" --force <<< "no" 2>&1 | grep -v "Do you wish to create a custom hardware profile"
    if [ $? -eq 0 ]; then
        echo "   ✅ Emulator created successfully!"
        echo ""
        echo "   To start it:"
        echo "   flutter emulators --launch $EMULATOR_NAME"
        echo "   or"
        echo "   ./scripts/dev/start_emulator.sh"
        exit 0
    fi
fi

# If avdmanager doesn't work, provide manual instructions
echo "⚠️  Could not create emulator automatically"
echo ""
echo "   Manual setup:"
echo ""
echo "   Option 1: Using Android Studio (Easiest)"
echo "   1. Open Android Studio"
echo "   2. Tools → Device Manager"
echo "   3. Click 'Create Device'"
echo "   4. Select a device (e.g., Pixel 5)"
echo "   5. Select a system image (e.g., Android 13 - API 33)"
echo "   6. Click 'Finish'"
echo ""
echo "   Option 2: Using command line"
echo "   $AVDMANAGER create avd -n phytopi_emulator -k system-images;android-33;google_apis;x86_64"
echo ""
echo "   After creating the emulator, you can start it with:"
echo "   flutter emulators --launch <emulator-name>"
echo ""

