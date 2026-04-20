# Development Scripts

This directory contains scripts for development and testing.

## Scripts

### `run_local.sh`
Run the Flutter app locally for web development.

**Usage:**
```bash
./scripts/dev/run_local.sh
```

### `test_android.sh`
Test the Flutter app on a physical Android device.

**Usage:**
```bash
./scripts/dev/test_android.sh
```

**Requirements:**
- Android device connected via USB
- USB debugging enabled
- Device authorized for USB debugging
- USB connection mode set to "File Transfer" or "PTP"

### `test_android_emulator.sh`
Test the Flutter app on an Android emulator.

**Usage:**
```bash
./scripts/dev/test_android_emulator.sh
```

**Requirements:**
- Android Studio installed
- Android emulator created
- Emulator running (or will be started automatically)

**Setup:**
1. Install Android Studio: `yay -S android-studio`
2. Open Android Studio → Tools → SDK Manager
3. Install Android SDK Platform-Tools, Android Emulator, and a system image
4. Create an AVD: Tools → Device Manager → Create Device
5. Start the emulator
6. Run the script

**Note:** The script automatically configures the environment to use `10.0.2.2` for Supabase (the emulator's special IP for the host machine).

### `setup_emulator.sh`
Set up an Android emulator (helper script).

**Usage:**
```bash
./scripts/dev/setup_emulator.sh
```

### `start_emulator.sh`
Start an Android emulator.

**Usage:**
```bash
./scripts/dev/start_emulator.sh [emulator-name]
```

### `test_kiosk.sh`
Test the Flutter app in kiosk mode.

**Usage:**
```bash
./scripts/dev/test_kiosk.sh
```

### `fix_android_connection.sh`
Fix Android device connection issues.

**Usage:**
```bash
./scripts/dev/fix_android_connection.sh
```

### `quick_fix_adb.sh`
Quick fix for ADB connection issues.

**Usage:**
```bash
./scripts/dev/quick_fix_adb.sh
```

### `install_apk.sh`
Manually install APK on Android device.

**Usage:**
```bash
./scripts/dev/install_apk.sh [apk_path]
```

### `troubleshoot_install.sh`
Troubleshoot Android APK installation issues.

**Usage:**
```bash
./scripts/dev/troubleshoot_install.sh
```

## Quick Reference

### Testing on Physical Device

```bash
# Connect device and enable USB debugging
./scripts/dev/test_android.sh
```

### Testing on Emulator

```bash
# Install Android Studio first
yay -S android-studio

# Create emulator in Android Studio
# Tools → Device Manager → Create Device

# Start emulator and run app
./scripts/dev/test_android_emulator.sh
```

### Fixing Connection Issues

```bash
# Quick fix for ADB issues
./scripts/dev/quick_fix_adb.sh

# Detailed connection fix
./scripts/dev/fix_android_connection.sh
```

## Environment Configuration

All scripts automatically load environment variables from `.env` files:
- `.env.local` (highest priority)
- `.env.android` (platform-specific)
- `.env` (general)

For emulator testing, the script automatically uses `10.0.2.2` for Supabase (the emulator's host machine IP).

## Troubleshooting

### Device Not Detected
- Check USB cable connection
- Enable USB debugging on device
- Change USB connection mode to "File Transfer"
- Run: `./scripts/dev/quick_fix_adb.sh`

### Emulator Won't Start
- Install Android Studio
- Install system images via Android Studio
- Create AVD via Android Studio

### Installation Failed
- Enable "Install from unknown sources" on device
- Check device storage
- Run: `./scripts/dev/troubleshoot_install.sh`

## See Also

- [Android Testing Guide](../../docs/platform/ANDROID_TESTING_GUIDE.md)
- [Emulator Setup Guide](../../docs/platform/EMULATOR_SETUP.md)
- [Android Setup Guide](../../docs/platform/ANDROID_SETUP.md)
