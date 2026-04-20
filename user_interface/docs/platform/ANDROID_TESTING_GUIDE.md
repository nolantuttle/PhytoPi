# Android Testing Guide for PhytoPi Dashboard

This guide explains how to test the PhytoPi Flutter app on your Android device or emulator.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Testing on Physical Android Device](#testing-on-physical-android-device)
3. [Testing on Android Emulator](#testing-on-android-emulator)
4. [Troubleshooting](#troubleshooting)
5. [Quick Reference](#quick-reference)

---

## Prerequisites

### 1. System Requirements

- **Operating System**: EndeavourOS (Arch Linux)
- **Flutter SDK**: 3.12.0 or higher (✅ Installed: 3.35.7)
- **Android SDK**: Installed at `/opt/android-sdk`
- **Java**: Java 11 or higher (✅ Installed: Java 25)
- **Supabase**: Running locally

### 2. Verify Flutter Installation

```bash
flutter doctor -v
```

You should see:
- ✅ Flutter installed
- ✅ Android SDK detected
- ✅ Connected device (if phone is connected)

### 3. Verify Android SDK

```bash
# Check Android SDK location
echo $ANDROID_HOME
# Should output: /opt/android-sdk

# Check ADB
adb --version
# Should show ADB version

# Check connected devices
adb devices
# Should list your device or emulator
```

### 4. Start Supabase Locally

```bash
cd /home/danielg/Documents/PhytoPi/infra/supabase
supabase start
```

**Important**: Note the `Publishable key` from the output. You'll need it for the environment configuration.

---

## Testing on Physical Android Device

### Step 1: Enable USB Debugging on Your Phone

1. **Enable Developer Options**:
   - Go to **Settings** → **About Phone**
   - Tap **Build Number** 7 times
   - You should see a message: "You are now a developer!"

2. **Enable USB Debugging**:
   - Go to **Settings** → **Developer Options**
   - Enable **USB Debugging**
   - Enable **Install via USB** (optional, but recommended)

3. **Connect Your Phone**:
   - ⚠️ **IMPORTANT**: Connect your phone **directly to your computer** (NOT through a USB hub)
   - USB hubs can cause connection issues with ADB
   - Use a USB port directly on your computer
   - Connect your phone to your computer via USB
   - On your phone, you'll see a prompt: "Allow USB debugging?"
   - Check **"Always allow from this computer"** and tap **Allow**

### Step 2: Verify Device Connection

```bash
cd /home/danielg/Documents/PhytoPi/dashboard

# Check if device is detected
adb devices
```

You should see your device listed:
```
List of devices attached
ZY22CXM5W5    device
```

If you see `unauthorized`, check your phone for the authorization prompt.

### Step 3: Set Up Environment Configuration

The environment is already configured! Your `.env.local` file contains:

```bash
SUPABASE_URL=http://192.168.0.107:54321
SUPABASE_ANON_KEY=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH
```

**Important**: 
- Your phone and computer must be on the **same Wi-Fi network**
- The IP address `192.168.0.107` is your computer's local IP
- Make sure your firewall allows connections on port `54321`

### Step 4: Run the App on Your Phone

**Option A: Using the Test Script (Recommended)**

```bash
cd /home/danielg/Documents/PhytoPi/dashboard
./scripts/dev/test_android.sh
```

**Option B: Manual Run**

```bash
cd /home/danielg/Documents/PhytoPi/dashboard

# Load environment variables
export PLATFORM=android
source scripts/utils/load_env.sh

# Run the app
flutter run -d android
```

The app will:
1. Build the Android APK
2. Install it on your device
3. Launch the app
4. Enable hot reload (press `r` to reload, `R` to restart, `q` to quit)

### Step 5: Verify the App Works

1. The app should launch on your phone
2. Check the console for any errors
3. The app should connect to your local Supabase instance
4. Test the app's features

---

## Testing on Android Emulator

### Option 1: Using Android Studio (Recommended)

1. **Install Android Studio**:
   ```bash
   # Via AUR (Arch User Repository)
   yay -S android-studio
   
   # Or download from: https://developer.android.com/studio
   ```

2. **Set Up Android Studio**:
   - Open Android Studio
   - Go to **Tools** → **SDK Manager**
   - Install **Android SDK Platform** (API 30 or higher)
   - Install **Android SDK Build-Tools**
   - Install **Android Emulator**

3. **Create an Android Virtual Device (AVD)**:
   - Go to **Tools** → **Device Manager**
   - Click **Create Device**
   - Select a device (e.g., Pixel 5)
   - Select a system image (e.g., Android 13 - API 33)
   - Click **Finish**

4. **Start the Emulator**:
   - Click the **Play** button next to your AVD
   - Wait for the emulator to start

5. **Run the App**:
   ```bash
   cd /home/danielg/Documents/PhytoPi/dashboard
   export PLATFORM=android
   source scripts/utils/load_env.sh
   flutter run -d android
   ```

### Option 2: Using Command Line Tools

1. **Install Android SDK Command Line Tools**:
   ```bash
   # Install via pacman
   sudo pacman -S android-sdk android-sdk-build-tools android-sdk-platform-tools
   
   # Or download from: https://developer.android.com/studio#command-line-tools-only
   ```

2. **Set Environment Variables**:
   ```bash
   export ANDROID_HOME=/opt/android-sdk
   export ANDROID_SDK_ROOT=/opt/android-sdk
   export PATH=$PATH:$ANDROID_HOME/emulator
   export PATH=$PATH:$ANDROID_HOME/platform-tools
   export PATH=$PATH:$ANDROID_HOME/tools
   export PATH=$PATH:$ANDROID_HOME/tools/bin
   ```

3. **Install System Image**:
   ```bash
   # List available system images
   sdkmanager --list | grep system-images
   
   # Install a system image (example for Android 13)
   sdkmanager "system-images;android-33;google_apis;x86_64"
   ```

4. **Create an AVD**:
   ```bash
   # Create an AVD
   avdmanager create avd -n phyto_pi_test -k "system-images;android-33;google_apis;x86_64"
   ```

5. **Start the Emulator**:
   ```bash
   emulator -avd phyto_pi_test &
   ```

6. **Run the App**:
   ```bash
   cd /home/danielg/Documents/PhytoPi/dashboard
   export PLATFORM=android
   source scripts/utils/load_env.sh
   flutter run -d android
   ```

### Option 3: Using Flutter's Emulator Commands

```bash
# List available emulators
flutter emulators

# Launch an emulator
flutter emulators --launch <emulator_id>

# Run the app
flutter run -d <emulator_id>
```

**Note**: For emulator testing, you can use `localhost` or `10.0.2.2` (Android emulator's special IP for host machine) instead of your local IP:

```bash
# For emulator, update .env.local:
SUPABASE_URL=http://10.0.2.2:54321
```

---

## Building APK for Manual Installation

### Build Release APK

```bash
cd /home/danielg/Documents/PhytoPi/dashboard

# Build APK
./scripts/build/build_mobile_android.sh apk

# The APK will be at:
# build/app/outputs/flutter-apk/app-release.apk
```

### Install APK on Device

**Option 1: Using ADB**
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

**Option 2: Manual Transfer**
1. Copy `app-release.apk` to your phone
2. On your phone, enable **Install from Unknown Sources**
3. Open the APK file on your phone
4. Install the app

---

## Troubleshooting

### Issue: Device Not Detected

**Solution**:
```bash
# Restart ADB server
adb kill-server
adb start-server
adb devices

# Check USB connection
# ⚠️ IMPORTANT: Connect directly to computer (NOT through USB hub)
# USB hubs can cause connection issues with ADB
# Try a different USB cable
# Try a different USB port on your computer
```

### Issue: "Unauthorized" Device

**Solution**:
1. Check your phone for the USB debugging authorization prompt
2. Tap **Allow** or **Always allow from this computer**
3. Run `adb devices` again

### Issue: Cannot Access Phone Files

**Note**: This is normal! USB debugging works separately from MTP (Media Transfer Protocol). If you want to access files:
```bash
# Install MTP support
sudo pacman -S gvfs-mtp
```

### Issue: App Can't Connect to Supabase

**Check**:
1. ✅ Supabase is running: `cd infra/supabase && supabase status`
2. ✅ Phone and computer are on the same Wi-Fi network
3. ✅ Firewall allows port 54321
4. ✅ `.env.local` has the correct IP address (your computer's IP, not `localhost`)
5. ✅ The IP address is correct: `ip addr show | grep "inet " | grep -v 127.0.0.1`

**Test Connection**:
```bash
# From your phone's browser, try accessing:
# http://192.168.0.107:54321
# You should see Supabase API response
```

### Issue: Android SDK Not Found

**Solution**:
```bash
# Tell Flutter where Android SDK is
flutter config --android-sdk /opt/android-sdk

# Verify
flutter doctor -v
```

### Issue: Missing Android Licenses

**Solution**:
```bash
export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=/opt/android-sdk
export PATH=$PATH:$ANDROID_HOME/platform-tools

# Accept licenses
yes | flutter doctor --android-licenses
```

### Issue: Java Version Conflict

**Solution**:
```bash
# Check Java version
java -version

# Flutter uses Java 11 by default
# If you have Java 25, you may need to:
# 1. Install Java 11
# 2. Or update Gradle version in android/gradle/wrapper/gradle-wrapper.properties
```

### Issue: Build Fails with Gradle Error

**Solution**:
```bash
cd /home/danielg/Documents/PhytoPi/dashboard/android

# Clean build
./gradlew clean

# Try building again
cd ..
flutter build apk --release
```

### Issue: App Crashes on Launch

**Check**:
1. Check logcat for errors: `adb logcat | grep -i error`
2. Verify environment variables are loaded correctly
3. Check if Supabase is accessible from your device
4. Verify internet permission is in AndroidManifest.xml

---

## Quick Reference

### Essential Commands

```bash
# Check Flutter setup
flutter doctor -v

# Check connected devices
adb devices

# List Flutter devices
flutter devices

# Run app on Android
cd /home/danielg/Documents/PhytoPi/dashboard
export PLATFORM=android
source scripts/utils/load_env.sh
flutter run -d android

# Build APK
./scripts/build/build_mobile_android.sh apk

# Install APK
adb install build/app/outputs/flutter-apk/app-release.apk

# View logs
adb logcat | grep -i flutter

# Restart ADB
adb kill-server && adb start-server
```

### Environment Variables

```bash
# Android SDK
export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=/opt/android-sdk
export PATH=$PATH:$ANDROID_HOME/platform-tools

# Flutter (if needed)
export FLUTTER_ROOT=/home/danielg/.cache/flutter_sdk
export PATH=$PATH:$FLUTTER_ROOT/bin
```

### File Locations

- **Environment config**: `/home/danielg/Documents/PhytoPi/dashboard/.env.local`
- **APK output**: `/home/danielg/Documents/PhytoPi/dashboard/build/app/outputs/flutter-apk/app-release.apk`
- **Android config**: `/home/danielg/Documents/PhytoPi/dashboard/android/`
- **Supabase config**: `/home/danielg/Documents/PhytoPi/infra/supabase/`

---

## Next Steps

1. ✅ **Android platform added** to Flutter project
2. ✅ **Environment configured** for Android testing
3. ✅ **Device connected** and detected
4. ⏳ **Test the app** on your device
5. ⏳ **Test the app** on emulator (optional)
6. ⏳ **Build release APK** for distribution

---

## Additional Resources

- [Flutter Android Setup](https://docs.flutter.dev/get-started/install/linux)
- [Android Developer Guide](https://developer.android.com/studio)
- [ADB Documentation](https://developer.android.com/studio/command-line/adb)
- [Supabase Local Development](https://supabase.com/docs/guides/cli/local-development)

---

## Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Check Flutter logs: `adb logcat | grep -i flutter`
3. Verify Supabase is running: `cd infra/supabase && supabase status`
4. Check environment variables: `source scripts/utils/load_env.sh && echo $SUPABASE_URL`

---

**Last Updated**: 2025-01-21
**Flutter Version**: 3.35.7
**Android SDK**: /opt/android-sdk
**Device**: motorola one 5G ace (Android 11, API 30)

