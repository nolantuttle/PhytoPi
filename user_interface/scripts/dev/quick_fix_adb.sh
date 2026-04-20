#!/bin/bash
# Quick fix for ADB connection issues after reconnecting device
# Usage: ./scripts/dev/quick_fix_adb.sh

echo "🔧 Quick ADB Connection Fix"
echo "==========================="
echo ""

# Check if device is physically connected
echo "📱 Step 1: Checking USB connection..."
if lsusb | grep -i "motorola\|android" > /dev/null; then
    echo "✅ Device detected via USB"
    DEVICE_INFO=$(lsusb | grep -i "motorola\|android")
    echo "   $DEVICE_INFO"
else
    echo "❌ No Android device detected via USB"
    echo ""
    echo "   Please check:"
    echo "   1. USB cable is properly connected"
    echo "   2. ⚠️  Connect directly to computer (NOT through USB hub)"
    echo "      USB hubs can cause connection issues with ADB"
    echo "   3. Try a different USB cable"
    echo "   4. Try a different USB port on your computer"
    echo "   5. On your phone, check if USB debugging is still enabled"
    exit 1
fi

echo ""
echo "🔄 Step 2: Restarting ADB server..."
adb kill-server 2>/dev/null
sleep 2
adb start-server
sleep 3

echo ""
echo "📱 Step 3: Checking ADB device status..."
ADB_OUTPUT=$(adb devices -l)
echo "$ADB_OUTPUT"
echo ""

DEVICE_STATUS=$(echo "$ADB_OUTPUT" | grep -v "List of devices" | grep -v "^$" | awk '{print $2}' | head -1)
DEVICE_ID=$(echo "$ADB_OUTPUT" | grep -v "List of devices" | grep -v "^$" | awk '{print $1}' | head -1)

if [ -z "$DEVICE_ID" ]; then
    echo "❌ Device not detected by ADB"
    echo ""
    echo "   On your phone, please do the following:"
    echo ""
    echo "   1. Check USB Debugging:"
    echo "      - Settings → Developer Options"
    echo "      - Make sure 'USB Debugging' is ENABLED"
    echo "      - If it's disabled, enable it"
    echo ""
    echo "   2. Change USB Connection Mode:"
    echo "      - Pull down the notification shade"
    echo "      - Look for 'USB' or 'Charging this device via USB' notification"
    echo "      - Tap on it"
    echo "      - Select 'File Transfer' or 'PTP' mode"
    echo "      - NOT 'Charging only' mode"
    echo ""
    echo "   3. Authorize USB Debugging:"
    echo "      - Look for 'Allow USB debugging?' prompt on your phone"
    echo "      - Check 'Always allow from this computer'"
    echo "      - Tap 'Allow'"
    echo ""
    echo "   4. If no prompt appears:"
    echo "      - Settings → Developer Options"
    echo "      - Tap 'Revoke USB debugging authorizations'"
    echo "      - Unplug the USB cable"
    echo "      - Wait 5 seconds"
    echo "      - Plug the USB cable back in"
    echo "      - Accept the new authorization prompt"
    echo ""
    echo "   5. After doing the above, run this script again:"
    echo "      ./scripts/dev/quick_fix_adb.sh"
    echo ""
    exit 1
elif [ "$DEVICE_STATUS" = "offline" ]; then
    echo "⚠️  Device is OFFLINE"
    echo ""
    echo "   On your phone, do the following:"
    echo ""
    echo "   1. Change USB Connection Mode (MOST IMPORTANT):"
    echo "      - Pull down notification shade"
    echo "      - Tap 'USB' or 'Charging this device via USB'"
    echo "      - Select 'File Transfer' or 'PTP' mode"
    echo "      - NOT 'Charging only' mode"
    echo ""
    echo "   2. Authorize USB Debugging:"
    echo "      - Look for 'Allow USB debugging?' prompt"
    echo "      - Check 'Always allow from this computer'"
    echo "      - Tap 'Allow'"
    echo ""
    echo "   3. If no prompt appears:"
    echo "      - Settings → Developer Options"
    echo "      - Tap 'Revoke USB debugging authorizations'"
    echo "      - Unplug USB cable"
    echo "      - Wait 5 seconds"
    echo "      - Plug USB cable back in"
    echo "      - Accept the new authorization prompt"
    echo ""
    echo "   After fixing on your phone, run:"
    echo "   adb devices"
    echo ""
    echo "   You should see: $DEVICE_ID    device"
    echo ""
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
    echo "   - Settings → Developer Options"
    echo "   - Tap 'Revoke USB debugging authorizations'"
    echo "   - Unplug and replug USB cable"
    echo "   - Accept the new authorization prompt"
    echo ""
    exit 1
else
    echo "✅ Device is connected and authorized!"
    echo "   Device ID: $DEVICE_ID"
    echo "   Status: $DEVICE_STATUS"
    echo ""
    echo "   You can now run:"
    echo "   ./scripts/dev/test_android.sh"
    echo ""
    exit 0
fi

