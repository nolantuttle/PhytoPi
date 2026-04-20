#!/bin/bash
# Manual APK installation script
# Usage: ./scripts/dev/install_apk.sh [apk_path]

APK_PATH="${1:-build/app/outputs/flutter-apk/app-debug.apk}"
APP_ID="com.example.phytopi_dashboard"

echo "📱 Manual APK Installation"
echo "========================="
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
        echo "⚠️  Warning: Low storage space (less than 100MB)"
    fi
fi
echo ""

# Uninstall existing app if present
if adb shell pm list packages 2>/dev/null | grep -q "$APP_ID"; then
    echo "🔍 App is already installed. Uninstalling..."
    if adb uninstall "$APP_ID" 2>/dev/null; then
        echo "✅ Previous version uninstalled"
    else
        echo "⚠️  Could not uninstall (may need manual uninstall from phone)"
        echo "   Trying to install anyway..."
    fi
    echo ""
fi

# Install APK
echo "📥 Installing APK..."
echo ""

# Try different installation methods
if adb install -r -d "$APK_PATH" 2>&1; then
    echo ""
    echo "✅ APK installed successfully!"
    echo ""
    echo "   To launch the app:"
    echo "   adb shell am start -n $APP_ID/.MainActivity"
    echo ""
    echo "   Or run: flutter run -d android"
else
    echo ""
    echo "❌ Installation failed"
    echo ""
    echo "   Troubleshooting:"
    echo "   1. Check device storage: adb shell df /data"
    echo "   2. Try manual uninstall: adb uninstall $APP_ID"
    echo "   3. Enable installation from unknown sources on your phone"
    echo "   4. Check installation logs: adb logcat | grep -i install"
    echo "   5. Try pushing to phone and install manually:"
    echo "      adb push $APK_PATH /sdcard/phytopi.apk"
    echo "      (Then install from phone's file manager)"
    exit 1
fi

