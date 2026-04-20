#!/bin/bash
# Script to fix Android device connection issues
# Usage: ./scripts/dev/fix_android_connection.sh

echo "🔧 Android Device Connection Fix"
echo "================================="
echo ""

# Check if device is physically connected
echo "📱 Checking USB connection..."
if lsusb | grep -i "motorola\|android" > /dev/null; then
    echo "✅ Device detected via USB"
    lsusb | grep -i "motorola\|android"
else
    echo "❌ No Android device detected via USB"
    echo ""
    echo "   Please:"
    echo "   1. Check USB cable connection"
    echo "   2. ⚠️  Connect directly to computer (NOT through USB hub)"
    echo "      USB hubs can cause connection issues with ADB"
    echo "   3. Try a different USB cable"
    echo "   4. Try a different USB port on your computer"
    exit 1
fi

echo ""
echo "🔄 Restarting ADB server..."
adb kill-server
sleep 2
adb start-server
sleep 2

echo ""
echo "📱 Checking ADB device status..."
DEVICE_STATUS=$(adb devices | grep -v "List of devices" | grep -v "^$" | awk '{print $2}')

if [ -z "$DEVICE_STATUS" ]; then
    echo "❌ No device detected by ADB"
    echo ""
    echo "   Please check your phone:"
    echo "   1. Is USB debugging enabled? (Settings → Developer Options → USB Debugging)"
    echo "   2. Is there an authorization prompt on your phone?"
    echo "   3. Try unplugging and replugging the USB cable"
    echo ""
    echo "   On your phone, you should see:"
    echo "   'Allow USB debugging?' with an RSA fingerprint"
    echo "   → Check 'Always allow from this computer'"
    echo "   → Tap 'Allow'"
    exit 1
elif [ "$DEVICE_STATUS" = "offline" ]; then
    echo "⚠️  Device is OFFLINE"
    echo ""
    echo "   This usually means:"
    echo "   1. USB debugging authorization needed"
    echo "   2. USB connection mode needs to be changed"
    echo ""
    echo "   Fix steps:"
    echo "   1. On your phone:"
    echo "      - Look for 'Allow USB debugging?' prompt"
    echo "      - Check 'Always allow from this computer'"
    echo "      - Tap 'Allow'"
    echo ""
    echo "   2. Change USB connection mode on your phone:"
    echo "      - Pull down notification shade"
    echo "      - Tap 'USB' or 'Charging this device via USB'"
    echo "      - Select 'File Transfer' or 'PTP' mode"
    echo "      - NOT 'Charging only' mode"
    echo ""
    echo "   3. Revoke USB debugging authorization (if needed):"
    echo "      - Settings → Developer Options"
    echo "      - Tap 'Revoke USB debugging authorizations'"
    echo "      - Unplug and replug USB cable"
    echo "      - Accept the new authorization prompt"
    echo ""
    echo "   Trying to reconnect..."
    adb kill-server
    sleep 2
    adb start-server
    sleep 2
    adb devices
    echo ""
    echo "   If still offline, try the steps above on your phone."
    exit 1
elif [ "$DEVICE_STATUS" = "unauthorized" ]; then
    echo "⚠️  Device is UNAUTHORIZED"
    echo ""
    echo "   On your phone:"
    echo "   1. Look for 'Allow USB debugging?' prompt"
    echo "   2. Check 'Always allow from this computer'"
    echo "   3. Tap 'Allow'"
    echo ""
    echo "   If no prompt appears:"
    echo "   1. Go to Settings → Developer Options"
    echo "   2. Tap 'Revoke USB debugging authorizations'"
    echo "   3. Unplug and replug USB cable"
    echo "   4. Accept the new authorization prompt"
    exit 1
else
    echo "✅ Device is connected and authorized!"
    DEVICE_ID=$(adb devices | grep -v "List of devices" | grep -v "^$" | awk '{print $1}')
    echo "   Device ID: $DEVICE_ID"
    echo ""
    echo "   Checking Flutter devices..."
    flutter devices | grep -i android || echo "   (Run 'flutter devices' to see full list)"
fi

echo ""
echo "✅ Connection fix complete!"

