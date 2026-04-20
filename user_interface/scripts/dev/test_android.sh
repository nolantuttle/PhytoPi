#!/bin/bash
# Quick script to test Android setup and run the app

# Navigate to dashboard directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Script is in scripts/dev, so go up two levels to get to dashboard
DASHBOARD_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$DASHBOARD_DIR"

# Load environment variables from .env files
UTILS_DIR="$(cd "$DASHBOARD_DIR/scripts/utils" && pwd)"
if [ -f "$UTILS_DIR/load_env.sh" ]; then
    export PLATFORM="android"
    source "$UTILS_DIR/load_env.sh"
else
    echo "⚠️  load_env.sh not found, using defaults"
    export ANDROID_HOME=/opt/android-sdk
    export ANDROID_SDK_ROOT=/opt/android-sdk
    export PATH=$PATH:$ANDROID_HOME/platform-tools
fi

# Add Android SDK Build-Tools to PATH (needed for aapt and other tools)
if [ -n "$ANDROID_HOME" ] && [ -d "$ANDROID_HOME/build-tools" ]; then
    # Find the latest build-tools version
    LATEST_BUILD_TOOLS=$(find "$ANDROID_HOME/build-tools" -maxdepth 1 -type d -name "[0-9]*" | sort -V | tail -1)
    if [ -n "$LATEST_BUILD_TOOLS" ]; then
        export PATH="$LATEST_BUILD_TOOLS:$PATH"
    fi
fi

echo "📱 Android Testing Setup"
echo "========================"
echo ""

# Check and configure Java version
echo "🔍 Checking Java version..."
CURRENT_JAVA_VERSION=$(java -version 2>&1 | head -1 | awk -F'"' '{print $2}' | awk -F'.' '{print $1}')
CURRENT_JAVA_FULL=$(java -version 2>&1 | head -1 | awk -F'"' '{print $2}')

# Try to find Java 17 or 21
JAVA17_PATH=""
JAVA21_PATH=""

# First, try using archlinux-java to list available Java versions
if command -v archlinux-java &> /dev/null; then
    # Check if Java 17 or 21 is available via archlinux-java
    AVAILABLE_JAVA=$(archlinux-java status 2>/dev/null | grep -E "java-17|java-21" | head -1 | awk '{print $1}')
    if [ -n "$AVAILABLE_JAVA" ]; then
        JAVA_PATH="/usr/lib/jvm/$AVAILABLE_JAVA"
        if [ -d "$JAVA_PATH" ] && [ -f "$JAVA_PATH/bin/java" ]; then
            JAVA_VER=$("$JAVA_PATH/bin/java" -version 2>&1 | head -1 | awk -F'"' '{print $2}' | awk -F'.' '{print $1}')
            if [ "$JAVA_VER" = "17" ]; then
                JAVA17_PATH="$JAVA_PATH"
            elif [ "$JAVA_VER" = "21" ]; then
                JAVA21_PATH="$JAVA_PATH"
            fi
        fi
    fi
fi

# Also check common locations for Java 17/21
for path in /usr/lib/jvm/java-17-openjdk /usr/lib/jvm/jdk-17* /usr/lib/jvm/java-21-openjdk /usr/lib/jvm/jdk-21*; do
    if [ -d "$path" ] && [ -f "$path/bin/java" ]; then
        JAVA_VER=$("$path/bin/java" -version 2>&1 | head -1 | awk -F'"' '{print $2}' | awk -F'.' '{print $1}')
        if [ "$JAVA_VER" = "17" ] && [ -z "$JAVA17_PATH" ]; then
            JAVA17_PATH="$path"
        elif [ "$JAVA_VER" = "21" ] && [ -z "$JAVA21_PATH" ]; then
            JAVA21_PATH="$path"
        fi
    fi
done

# Prefer Java 17, then 21, if current Java is 25+
if [ -n "$CURRENT_JAVA_VERSION" ] && [ "$CURRENT_JAVA_VERSION" -ge 25 ]; then
    if [ -n "$JAVA17_PATH" ]; then
        export JAVA_HOME="$JAVA17_PATH"
        export PATH="$JAVA_HOME/bin:$PATH"
        echo "✅ Using Java 17 from $JAVA17_PATH (Java $CURRENT_JAVA_FULL detected, incompatible with Kotlin)"
    elif [ -n "$JAVA21_PATH" ]; then
        export JAVA_HOME="$JAVA21_PATH"
        export PATH="$JAVA_HOME/bin:$PATH"
        echo "✅ Using Java 21 from $JAVA21_PATH (Java $CURRENT_JAVA_FULL detected, incompatible with Kotlin)"
    else
        echo "⚠️  Warning: Java $CURRENT_JAVA_FULL detected. Kotlin compiler may have compatibility issues."
        echo ""
        echo "   To fix this, install Java 17 or 21:"
        echo "   sudo pacman -S jdk17-openjdk  # or jdk21-openjdk"
        echo ""
        if command -v archlinux-java &> /dev/null; then
            echo "   After installation, you can switch Java versions with:"
            echo "   sudo archlinux-java set java-17-openjdk  # or java-21-openjdk"
            echo ""
        fi
        echo "   Or run this script again after installation (it will auto-detect and use Java 17/21)"
        echo ""
        echo "   Continuing with current Java version (build may fail)..."
        echo ""
    fi
else
    echo "✅ Java version: $CURRENT_JAVA_FULL"
fi
echo ""

# Check ADB
echo "🔍 Checking ADB..."
if command -v adb &> /dev/null; then
    echo "✅ ADB found"
    echo ""
    echo "📱 Connected devices:"
    ADB_OUTPUT=$(adb devices)
    echo "$ADB_OUTPUT"
    echo ""
    
    # Check device status
    DEVICE_STATUS=$(echo "$ADB_OUTPUT" | grep -v "List of devices" | grep -v "^$" | awk '{print $2}' | head -1)
    DEVICE_ID=$(echo "$ADB_OUTPUT" | grep -v "List of devices" | grep -v "^$" | awk '{print $1}' | head -1)
    
    if [ -z "$DEVICE_ID" ]; then
        echo "❌ No Android device found"
        echo ""
        echo "   Your device is physically connected but ADB can't see it."
        echo ""
        echo "   Troubleshooting steps (on your phone):"
        echo ""
        echo "   1. ⚠️  CONNECT DIRECTLY TO COMPUTER (MOST IMPORTANT):"
        echo "      - Connect USB cable DIRECTLY to computer"
        echo "      - NOT through a USB hub"
        echo "      - USB hubs can cause connection issues with ADB"
        echo "      - Use a USB port directly on your computer"
        echo ""
        echo "   2. CHANGE USB CONNECTION MODE:"
        echo "      - Pull down notification shade"
        echo "      - Tap 'USB' or 'Charging this device via USB'"
        echo "      - Select 'File Transfer' or 'PTP' mode"
        echo "      - NOT 'Charging only' mode ⚠️"
        echo ""
        echo "   3. Check USB Debugging:"
        echo "      - Settings → Developer Options"
        echo "      - Make sure 'USB Debugging' is ENABLED"
        echo ""
        echo "   4. Authorize USB Debugging:"
        echo "      - Look for 'Allow USB debugging?' prompt"
        echo "      - Check 'Always allow from this computer'"
        echo "      - Tap 'Allow'"
        echo ""
        echo "   5. If no prompt appears:"
        echo "      - Settings → Developer Options"
        echo "      - Tap 'Revoke USB debugging authorizations'"
        echo "      - Unplug USB cable"
        echo "      - Wait 5 seconds"
        echo "      - Plug USB cable back in"
        echo "      - Accept the new authorization prompt"
        echo ""
        echo "   6. Run fix script:"
        echo "      ./scripts/dev/fix_android_connection.sh"
        echo "      or"
        echo "      ./scripts/dev/quick_fix_adb.sh"
        exit 1
    elif [ "$DEVICE_STATUS" = "offline" ]; then
        echo "⚠️  Device is OFFLINE"
        echo ""
        echo "   This happens when you disconnect and reconnect your phone."
        echo "   The phone defaults to 'Charging only' mode which ADB can't use."
        echo ""
        echo "   📱 FIX THIS ON YOUR PHONE (in this order):"
        echo ""
        echo "   1. CHANGE USB CONNECTION MODE (MOST IMPORTANT!):"
        echo "      ⚠️  Pull down notification shade"
        echo "      ⚠️  Tap 'USB' or 'Charging this device via USB'"
        echo "      ⚠️  Select 'File Transfer' or 'PTP' mode"
        echo "      ⚠️  NOT 'Charging only' mode"
        echo ""
        echo "   2. AUTHORIZE USB DEBUGGING:"
        echo "      - Look for 'Allow USB debugging?' prompt"
        echo "      - Check 'Always allow from this computer'"
        echo "      - Tap 'Allow'"
        echo ""
        echo "   3. IF NO PROMPT APPEARS:"
        echo "      - Settings → Developer Options"
        echo "      - Tap 'Revoke USB debugging authorizations'"
        echo "      - Unplug USB cable"
        echo "      - Wait 5 seconds"
        echo "      - Plug USB cable back in"
        echo "      - Accept the new authorization prompt"
        echo ""
        echo "   🔄 Trying to reconnect..."
        adb kill-server
        sleep 2
        adb start-server
        sleep 3
        echo ""
        echo "   Current status:"
        adb devices
        echo ""
        echo "   ✅ After fixing on your phone, run:"
        echo "      adb devices"
        echo ""
        echo "   You should see: $DEVICE_ID    device"
        echo "   (Not 'offline')"
        echo ""
        echo "   Then run this script again:"
        echo "      ./scripts/dev/test_android.sh"
        echo ""
        echo "   Or use the quick fix script:"
        echo "      ./scripts/dev/quick_fix_adb.sh"
        exit 1
    elif [ "$DEVICE_STATUS" = "unauthorized" ]; then
        echo "⚠️  Device is UNAUTHORIZED"
        echo ""
        echo "   On your phone:"
        echo "   1. Look for 'Allow USB debugging?' prompt"
        echo "   2. Check 'Always allow from this computer'"
        echo "   3. Tap 'Allow'"
        echo ""
        echo "   If no prompt appears, revoke and re-authorize:"
        echo "   - Settings → Developer Options"
        echo "   - Tap 'Revoke USB debugging authorizations'"
        echo "   - Unplug and replug USB cable"
        echo "   - Accept the new authorization prompt"
        exit 1
    else
        echo "✅ Device is connected and authorized: $DEVICE_ID"
    fi
else
    echo "❌ ADB not found in PATH"
    echo "   Make sure /opt/android-sdk/platform-tools is in PATH"
    exit 1
fi

# Check and accept Android SDK licenses
echo "🔍 Checking Android SDK licenses..."
LICENSE_ACCEPTED=false

if [ -n "$ANDROID_HOME" ] && [ -d "$ANDROID_HOME" ]; then
    # Create licenses directory if it doesn't exist
    mkdir -p "$ANDROID_HOME/licenses"
    
    # Try newer cmdline-tools sdkmanager first
    SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
    if [ ! -f "$SDKMANAGER" ]; then
        # Try to find any cmdline-tools version
        CMDLINE_TOOLS=$(find "$ANDROID_HOME/cmdline-tools" -name "sdkmanager" 2>/dev/null | head -1)
        if [ -n "$CMDLINE_TOOLS" ]; then
            SDKMANAGER="$CMDLINE_TOOLS"
        fi
    fi
    
    # Try sdkmanager if found
    if [ -f "$SDKMANAGER" ]; then
        echo "📝 Accepting Android SDK licenses via sdkmanager..."
        # Use Java 17 if available for sdkmanager
        if [ -n "$JAVA_HOME" ]; then
            export JAVA_HOME
            export PATH="$JAVA_HOME/bin:$PATH"
        fi
        yes | "$SDKMANAGER" --licenses > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "✅ Android SDK licenses accepted"
            LICENSE_ACCEPTED=true
        fi
    fi
    
    # If sdkmanager didn't work, try to accept common licenses manually
    if [ "$LICENSE_ACCEPTED" = false ]; then
        # Check if licenses are already accepted
        if [ -d "$ANDROID_HOME/licenses" ] && [ "$(ls -A $ANDROID_HOME/licenses 2>/dev/null)" ]; then
            echo "✅ Android SDK licenses already accepted"
            LICENSE_ACCEPTED=true
        else
            echo "📝 Attempting to accept Android SDK licenses manually..."
            
            # Try to create licenses directory (may need sudo)
            if mkdir -p "$ANDROID_HOME/licenses" 2>/dev/null; then
                # Common Android SDK license acceptance files
                # These are standard license hashes for Android SDK components
                echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > "$ANDROID_HOME/licenses/android-sdk-license" 2>/dev/null
                echo "d56f5187c7c9c1f1aa16a452136273e4669b2e21" > "$ANDROID_HOME/licenses/android-sdk-preview-license" 2>/dev/null
                echo "601085b94cd77f0b54ff86406957099ebe79c4d6" > "$ANDROID_HOME/licenses/android-googletv-license" 2>/dev/null
                echo "84831b9409646a918e30573bab4c9c91346d8abd" > "$ANDROID_HOME/licenses/google-gdk-license" 2>/dev/null
                
                # NDK and other common licenses
                COMMON_LICENSE_HASHES=(
                    "24333f8a63b6825ea9c5514f83c2829b004d1fee"
                    "d56f5187c7c9c1f1aa16a452136273e4669b2e21"
                    "33b6a33b8c81e1cb0e5e31c03e18e3cd6d755ec0"
                    "601085b94cd77f0b54ff86406957099ebe79c4d6"
                )
                
                for hash in "${COMMON_LICENSE_HASHES[@]}"; do
                    echo "$hash" > "$ANDROID_HOME/licenses/$hash" 2>/dev/null
                done
                
                if [ -d "$ANDROID_HOME/licenses" ] && [ "$(ls -A $ANDROID_HOME/licenses 2>/dev/null 2>&1)" ]; then
                    echo "✅ Android SDK licenses accepted (manual method)"
                    LICENSE_ACCEPTED=true
                fi
            else
                echo "⚠️  Cannot create license files (permission denied)."
                echo ""
                echo "   Run this command to accept all Android SDK licenses:"
                echo "   /tmp/accept_android_licenses.sh"
                echo ""
                echo "   Or manually run:"
                echo "   sudo mkdir -p $ANDROID_HOME/licenses"
                echo "   sudo bash -c 'echo \"24333f8a63b6825ea9c5514f83c2829b004d1fee\" > $ANDROID_HOME/licenses/android-sdk-license'"
                echo "   sudo bash -c 'echo \"d56f5187c7c9c1f1aa16a452136273e4669b2e21\" > $ANDROID_HOME/licenses/android-sdk-preview-license'"
                echo "   sudo bash -c 'echo \"24333f8a63b6825ea9c5514f83c2829b004d1fee\" > $ANDROID_HOME/licenses/ndk-license'"
                echo ""
                echo "   Then run this script again."
            fi
        fi
    fi
fi

# If still not accepted, try Flutter's method
if [ "$LICENSE_ACCEPTED" = false ] && command -v flutter &> /dev/null; then
    echo "📝 Trying to accept licenses via Flutter..."
    # Flutter might need cmdline-tools, but let's try anyway
    yes | flutter doctor --android-licenses > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ Android SDK licenses accepted via Flutter"
        LICENSE_ACCEPTED=true
    fi
fi

if [ "$LICENSE_ACCEPTED" = false ]; then
    echo "⚠️  Could not auto-accept licenses automatically."
    echo ""
    echo "   Quick fix - Run this command to accept licenses:"
    echo "   /tmp/accept_android_licenses.sh"
    echo ""
    echo "   If NDK license errors persist, install Android SDK command-line tools:"
    echo "   1. Download from: https://developer.android.com/studio#command-tools"
    echo "   2. Extract to: $ANDROID_HOME/cmdline-tools/latest/"
    echo "   3. Then run: $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses"
    echo ""
fi
echo ""

# Check if Supabase vars are set
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
    echo "❌ Error: SUPABASE_URL or SUPABASE_ANON_KEY not set"
    echo ""
    echo "   Run setup script: ./scripts/utils/setup_env.sh android"
    echo "   Or create .env.local with:"
    echo "   SUPABASE_URL=http://192.168.0.107:54321  # Your local IP"
    echo "   SUPABASE_ANON_KEY=your-local-anon-key"
    echo ""
    echo "   Find your IP: ip addr show | grep 'inet ' | grep -v 127.0.0.1"
    exit 1
fi

# Explicitly export variables for Dart defines
export SUPABASE_URL="$SUPABASE_URL"
export SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

echo "📋 Using Supabase config:"
echo "   URL: $SUPABASE_URL"
echo "   Key: ${SUPABASE_ANON_KEY:0:10}..."
echo ""

# Check Flutter
echo "🔍 Checking Flutter..."
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found in PATH"
    exit 1
fi

# Get dependencies
echo ""
echo "📦 Getting Flutter dependencies..."
flutter pub get

# List available devices
echo ""
echo "📱 Available Flutter devices:"
flutter devices

echo ""

# Detect Android device ID (device ID is the second field between bullets)
ANDROID_DEVICE=$(flutter devices | grep -E "android|mobile" | grep -v "emulator" | head -1 | awk -F'•' '{print $2}' | xargs)

if [ -z "$ANDROID_DEVICE" ]; then
    echo "❌ No Android device found"
    echo "   Make sure your device is connected and authorized via ADB"
    exit 1
fi

echo "🎯 Using device: $ANDROID_DEVICE"
echo ""

# Check if Android SDK directory is writable
if [ -n "$ANDROID_HOME" ] && [ -d "$ANDROID_HOME" ]; then
    if [ ! -w "$ANDROID_HOME" ]; then
        echo "⚠️  Warning: Android SDK directory is not writable: $ANDROID_HOME"
        echo "   This may prevent automatic installation of SDK components (like NDK)."
        echo ""
        echo "   To fix this, run one of the following:"
        echo "   1. Change ownership (recommended):"
        echo "      sudo chown -R $USER:$USER $ANDROID_HOME"
        echo ""
        echo "   2. Or install NDK manually with sudo:"
        echo "      sudo $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager 'ndk;27.0.12077973'"
        echo ""
        echo "   Continuing anyway (build may fail if NDK needs to be installed)..."
        echo ""
    fi
fi

# Check if app is already installed and uninstall if needed
echo "🔍 Checking if app is already installed..."
APP_ID="com.example.phytopi_dashboard"
if adb shell pm list packages | grep -q "$APP_ID"; then
    echo "⚠️  App is already installed. Uninstalling previous version..."
    if adb uninstall "$APP_ID" 2>/dev/null; then
        echo "✅ Previous version uninstalled"
    else
        echo "⚠️  Could not uninstall previous version (may have different signature)"
        echo "   Attempting to install anyway (will try to replace)..."
    fi
else
    echo "✅ App not installed (fresh install)"
fi
echo ""

# Check device storage
echo "🔍 Checking device storage..."
STORAGE_INFO=$(adb shell df /data | tail -1 | awk '{print $4}')
if [ -n "$STORAGE_INFO" ]; then
    # Convert to MB (assuming the output is in KB)
    STORAGE_MB=$((STORAGE_INFO / 1024))
    echo "   Available storage: ~${STORAGE_MB}MB"
    if [ "$STORAGE_MB" -lt 100 ]; then
        echo "⚠️  Warning: Low storage space (less than 100MB)"
        echo "   The app may fail to install. Consider freeing up space."
    fi
fi
echo ""

echo "🚀 Running app on Android..."
echo "   (Press 'q' to quit, 'r' to hot reload, 'R' to hot restart)"
echo ""

# Run on Android device with error handling
TEMP_LOG=$(mktemp)
trap "rm -f $TEMP_LOG" EXIT

# Try to run the app
if ! flutter run -d "$ANDROID_DEVICE" --dart-define=SUPABASE_URL="$SUPABASE_URL" --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" 2>&1 | tee "$TEMP_LOG"; then
    echo ""
    echo "❌ Build failed."
    echo ""
    
    # Check for specific errors
    if grep -q "SDK directory is not writable\|not writable" "$TEMP_LOG"; then
        echo "🔧 Android SDK directory permission issue detected."
        echo ""
        echo "   The Android SDK at $ANDROID_HOME is not writable."
        echo "   This prevents automatic installation of required components (like NDK)."
        echo ""
        echo "   Fix by changing ownership:"
        echo "   sudo chown -R $USER:$USER $ANDROID_HOME"
        echo ""
        echo "   Then run this script again."
    elif grep -q "did not have a source.properties file\|CXX1101\|malformed download of the NDK" "$TEMP_LOG"; then
        echo "🔧 Corrupted NDK installation detected."
        echo ""
        echo "   The NDK installation is incomplete or corrupted."
        echo ""
        
        # Try to find and clean up the corrupted NDK
        CORRUPTED_NDK=$(grep -o "/opt/android-sdk/ndk/[0-9.]*" "$TEMP_LOG" | head -1)
        if [ -z "$CORRUPTED_NDK" ]; then
            # Try to find any NDK directories
            CORRUPTED_NDK=$(find "$ANDROID_HOME/ndk" -maxdepth 1 -type d 2>/dev/null | head -1)
        fi
        
        if [ -n "$CORRUPTED_NDK" ] && [ -d "$CORRUPTED_NDK" ]; then
            echo "   Found corrupted NDK at: $CORRUPTED_NDK"
            echo ""
            if [ -w "$CORRUPTED_NDK" ] || [ -w "$(dirname "$CORRUPTED_NDK")" ]; then
                echo "   🧹 Cleaning up corrupted NDK..."
                rm -rf "$CORRUPTED_NDK" 2>/dev/null
                if [ $? -eq 0 ]; then
                    echo "   ✅ Corrupted NDK removed. It will be re-downloaded on next build."
                else
                    echo "   ⚠️  Could not remove (permission denied). Run manually:"
                    echo "      sudo rm -rf $CORRUPTED_NDK"
                fi
            else
                echo "   ⚠️  Cannot remove (permission denied). Run:"
                echo "      sudo rm -rf $CORRUPTED_NDK"
            fi
        else
            echo "   Clean up any corrupted NDK directories:"
            echo "      rm -rf $ANDROID_HOME/ndk/*"
            echo "      (or use sudo if permission denied)"
        fi
        
        echo ""
        echo "   Also clear download cache:"
        echo "      rm -rf $ANDROID_HOME/.temp $ANDROID_HOME/.downloadCache"
        echo ""
        echo "   Then run this script again."
    elif grep -q "Archive is not a ZIP archive\|ZipException\|Error on ZipFile" "$TEMP_LOG"; then
        echo "🔧 NDK download corruption detected."
        echo ""
        echo "   The NDK download appears to be corrupted or incomplete."
        echo ""
        echo "   Try these solutions:"
        echo "   1. Clear the Android SDK download cache:"
        echo "      rm -rf $ANDROID_HOME/.temp"
        echo "      rm -rf $ANDROID_HOME/.downloadCache"
        echo ""
        echo "   2. Remove any partially installed NDK:"
        echo "      rm -rf $ANDROID_HOME/ndk/*"
        echo ""
        echo "   3. Or manually install NDK using sdkmanager:"
        if [ -f "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
            echo "      $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager 'ndk;27.0.12077973'"
        else
            echo "      (Install Android SDK command-line tools first)"
        fi
        echo ""
        echo "   Then run this script again."
    elif grep -q "NDK.*not accepted\|License.*not accepted" "$TEMP_LOG"; then
        echo "🔧 NDK license issue detected."
        echo "   Run: /tmp/accept_android_licenses.sh"
        echo "   Then run this script again."
    elif grep -q "Could not locate aapt\|aapt.*not found" "$TEMP_LOG"; then
        echo "🔧 Android Build-Tools PATH issue detected."
        echo ""
        echo "   Flutter cannot find 'aapt' from Android Build-Tools."
        echo "   This script should have added build-tools to PATH automatically."
        echo ""
        echo "   Verify build-tools are installed:"
        echo "      ls -la $ANDROID_HOME/build-tools/"
        echo ""
        echo "   If build-tools exist, try running Flutter again - PATH should be set now."
        echo "   Or manually add to PATH:"
        if [ -d "$ANDROID_HOME/build-tools" ]; then
            LATEST_BUILD_TOOLS=$(find "$ANDROID_HOME/build-tools" -maxdepth 1 -type d -name "[0-9]*" | sort -V | tail -1)
            if [ -n "$LATEST_BUILD_TOOLS" ]; then
                echo "      export PATH=\"$LATEST_BUILD_TOOLS:\$PATH\""
            fi
        fi
        echo ""
        echo "   Then run this script again."
    elif grep -q "failed to install\|Error launching application\|INSTALL_FAILED\|ADB exited with exit code 1" "$TEMP_LOG"; then
        echo "🔧 Installation failure detected."
        echo ""
        echo "   The APK was built successfully (✓ Built build/app/outputs/flutter-apk/app-debug.apk)"
        echo "   but failed to install on the device."
        echo ""
        
        # Extract any error details from the log
        ERROR_DETAILS=$(grep -i "failed\|error\|install_failed" "$TEMP_LOG" | tail -5)
        if [ -n "$ERROR_DETAILS" ]; then
            echo "   Error details:"
            echo "$ERROR_DETAILS" | sed 's/^/      /'
            echo ""
        fi
        
        echo "   Common causes and solutions:"
        echo ""
        echo "   1. Installation from unknown sources disabled (MOST COMMON):"
        echo "      - On your phone: Settings → Security"
        echo "      - Enable 'Install from unknown sources' or 'Install apps via USB'"
        echo "      - Or: Settings → Apps → Special access → Install unknown apps"
        echo "      - Enable for 'USB' or 'ADB'"
        echo ""
        echo "   2. Device restrictions or security policies:"
        echo "      - Check if your device has installation restrictions"
        echo "      - Try: Settings → Developer Options → Verify apps over USB (disable)"
        echo "      - Or: Settings → Developer Options → USB debugging (security settings)"
        echo ""
        echo "   3. Try manual installation with verbose output:"
        echo "      cd /home/danielg/Documents/PhytoPi/dashboard"
        echo "      adb install -r -d -g build/app/outputs/flutter-apk/app-debug.apk"
        echo "      (Flags: -r=replace, -d=downgrade, -g=grant permissions)"
        echo ""
        echo "   4. Try pushing APK to phone and install manually:"
        echo "      adb push build/app/outputs/flutter-apk/app-debug.apk /sdcard/phytopi.apk"
        echo "      (Then on your phone: File Manager → /sdcard/ → phytopi.apk → Install)"
        echo ""
        echo "   5. Check installation logs:"
        echo "      adb logcat -c  # Clear logs"
        echo "      adb install -r -d build/app/outputs/flutter-apk/app-debug.apk"
        echo "      adb logcat -d | grep -i 'package\|install\|failed' | tail -20"
        echo ""
        echo "   6. Use the manual installation script:"
        echo "      ./scripts/dev/install_apk.sh"
        echo ""
        echo "   The APK is ready at: build/app/outputs/flutter-apk/app-debug.apk"
        echo "   You can also manually transfer it to your phone and install it."
    else
        echo "   To see more details, run:"
        echo "   cd android && ./gradlew assembleDebug --stacktrace"
        echo "   Or: flutter run -d $ANDROID_DEVICE --verbose"
    fi
    exit 1
fi

