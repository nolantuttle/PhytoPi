#!/bin/bash
# Troubleshoot Android APK installation issues
# Usage: ./scripts/dev/troubleshoot_install.sh

APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
APP_ID="com.example.phytopi_dashboard"

echo "🔧 Android APK Installation Troubleshooting"
echo "==========================================="
echo ""

# Check if device is connected
if ! adb devices | grep -q "device$"; then
    echo "❌ No Android device found"
    echo "   Make sure your device is connected and authorized"
    echo "   Run: adb devices"
    exit 1
fi

# Check if APK exists
if [ ! -f "$APK_PATH" ]; then
    echo "❌ APK not found: $APK_PATH"
    echo "   Build the APK first: flutter build apk --debug"
    exit 1
fi

echo "📦 APK: $APK_PATH"
APK_SIZE=$(ls -lh "$APK_PATH" | awk '{print $5}')
echo "   Size: $APK_SIZE"
echo ""

# Check device storage
echo "🔍 Checking device storage..."
STORAGE_INFO=$(adb shell df /data 2>/dev/null | tail -1 | awk '{print $4}')
if [ -n "$STORAGE_INFO" ] && [ "$STORAGE_INFO" != "df:" ]; then
    STORAGE_MB=$((STORAGE_INFO / 1024))
    echo "   Available storage: ~${STORAGE_MB}MB"
    if [ "$STORAGE_MB" -lt 100 ]; then
        echo "   ⚠️  Warning: Low storage space"
    fi
fi
echo ""

# Check if app is installed
echo "🔍 Checking if app is installed..."
if adb shell pm list packages 2>/dev/null | grep -q "$APP_ID"; then
    echo "   ⚠️  App is already installed"
    echo "   Uninstalling..."
    adb uninstall "$APP_ID" 2>/dev/null
    sleep 2
else
    echo "   ✅ App not installed"
fi
echo ""

# Try installation with different methods
echo "📥 Attempting installation..."
echo ""

# Method 1: Standard install with replace and downgrade
echo "Method 1: Standard install (-r -d)"
if adb install -r -d "$APK_PATH" 2>&1; then
    echo ""
    echo "✅ Installation successful!"
    exit 0
else
    echo "   ❌ Failed"
    echo ""
fi

# Method 2: Install with grant permissions
echo "Method 2: Install with grant permissions (-r -d -g)"
if adb install -r -d -g "$APK_PATH" 2>&1; then
    echo ""
    echo "✅ Installation successful!"
    exit 0
else
    echo "   ❌ Failed"
    echo ""
fi

# Method 3: Push to phone and provide manual install instructions
echo "Method 3: Push APK to phone for manual installation"
echo "   Pushing APK to /sdcard/phytopi.apk..."
if adb push "$APK_PATH" /sdcard/phytopi.apk 2>&1; then
    echo "   ✅ APK pushed to phone"
    echo ""
    echo "   📱 On your phone:"
    echo "   1. Open File Manager"
    echo "   2. Navigate to /sdcard/ or Internal Storage"
    echo "   3. Find 'phytopi.apk'"
    echo "   4. Tap on it"
    echo "   5. Tap 'Install'"
    echo "   6. If prompted, enable 'Install from unknown sources'"
    echo ""
    echo "   After installation, you can launch the app or run:"
    echo "   flutter run -d android"
    exit 0
else
    echo "   ❌ Failed to push APK"
    echo ""
fi

# If all methods failed, show detailed error
echo "❌ All installation methods failed"
echo ""
echo "   Troubleshooting steps:"
echo ""
echo "   1. Enable installation from unknown sources:"
echo "      - Settings → Security → Install from unknown sources"
echo "      - Or: Settings → Apps → Special access → Install unknown apps"
echo "      - Enable for 'USB' or 'ADB'"
echo ""
echo "   2. Check device restrictions:"
echo "      - Settings → Developer Options"
echo "      - Disable 'Verify apps over USB'"
echo "      - Check 'USB debugging (Security settings)'"
echo ""
echo "   3. Check installation logs:"
echo "      adb logcat -c"
echo "      adb install -r -d $APK_PATH"
echo "      adb logcat -d | grep -i 'package\|install\|failed' | tail -30"
echo ""
echo "   4. Try restarting ADB:"
echo "      adb kill-server && adb start-server"
echo ""
echo "   5. Manually transfer APK:"
echo "      - Copy $APK_PATH to your phone via USB (MTP mode)"
echo "      - Install from phone's file manager"
echo ""
exit 1

