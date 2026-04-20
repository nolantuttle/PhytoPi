# Android Testing Setup Guide

## Environment Configuration

The Android SDK is installed at `/opt/android-sdk` (via Arch Linux package manager).

### Permanent Setup

Add these lines to your `~/.bashrc` (already added):

```bash
export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=/opt/android-sdk
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

**Important:** After adding these, either:
- Restart your terminal, OR
- Run: `source ~/.bashrc`

### For Current Session

Before running Flutter commands, set these environment variables:

```bash
export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=/opt/android-sdk
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

## Environment Setup with .env Files

### 1. Create .env File

Create a `.env` file in the `dashboard` directory:

```bash
cd dashboard
cp env.example .env
```

Edit `.env` with your Supabase credentials:

```bash
# For local development
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=your-local-anon-key-here

# OR for production/remote
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-production-anon-key-here
```

**Note:** `.env` files are already in `.gitignore` and won't be committed.

## Testing on Android

### 1. Connect Android Device

Enable USB debugging on your Android device:
- Settings → About Phone → Tap "Build Number" 7 times
- Settings → Developer Options → Enable "USB Debugging"
- Connect device via USB

### 2. Verify Device Connection

```bash
# Check if device is detected (Android SDK paths are auto-loaded)
cd dashboard
source scripts/load_env.sh
adb devices
```

You should see your device listed. If it shows "unauthorized", check your phone for a USB debugging authorization prompt.

### 3. Run Flutter App (Using .env)

**Option A: Use the test script (recommended)**

```bash
cd dashboard
./scripts/test_android.sh
```

**Option B: Manual run**

```bash
cd dashboard

# Load environment from .env
source scripts/load_env.sh

# Run on Android
flutter run -d android
```

### 4. Build APK for Testing

```bash
cd dashboard

# Build APK (automatically loads .env)
./scripts/build_mobile_android.sh apk

# Install on connected device
adb install build/app/outputs/flutter-apk/app-release.apk
```

The build script automatically loads environment variables from `.env` files.

## Troubleshooting

### Flutter Cache Warning

If you see:
```
mkdir: cannot stat '/home/danielg/.cache/flutter_sdk': Permission denied
unionfs failed
```

This is a unionfs/filesystem issue but shouldn't prevent Flutter from working. You can ignore it for now, or try:

```bash
# Try setting a different cache location
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

### Android SDK Not Found

If Flutter still can't find Android SDK:

```bash
# Explicitly tell Flutter where the SDK is
flutter config --android-sdk /opt/android-sdk
```

### No Devices Found

1. Check USB connection: `adb devices`
2. If device shows "unauthorized", check phone for authorization prompt
3. Restart ADB: `adb kill-server && adb start-server`
4. Check USB debugging is enabled on device

### License Acceptance

To accept Android licenses:

```bash
export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=/opt/android-sdk
export PATH=$PATH:$ANDROID_HOME/platform-tools
yes | flutter doctor --android-licenses
```

## Quick Test Script

A `test_android.sh` script is available in the `scripts/` directory. It automatically:
- Loads environment variables from `.env` files
- Sets up Android SDK paths
- Checks for connected devices
- Runs the Flutter app

**Usage:**

```bash
cd dashboard
./scripts/test_android.sh
```

Make sure you have a `.env` file with your Supabase credentials first!

## Next Steps

1. ✅ Android SDK installed at `/opt/android-sdk`
2. ✅ ADB working (`adb devices` shows devices)
3. ⏳ Connect Android device or start emulator
4. ⏳ Set Supabase environment variables
5. ⏳ Run `flutter run -d android`

