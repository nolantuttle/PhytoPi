# Android Emulator Setup Guide

This guide explains how to set up and use an Android emulator for testing the PhytoPi Flutter app.

## Quick Start

### Option 1: Using Flutter (Simplest)

```bash
cd /home/danielg/Documents/PhytoPi/dashboard

# Create an emulator
flutter emulators --create --name phytopi_emulator

# Start the emulator
flutter emulators --launch phytopi_emulator

# Run the app (wait for emulator to boot first)
./scripts/dev/test_android_emulator.sh
```

### Option 2: Using Android Studio (Recommended)

1. **Install Android Studio**:
   ```bash
   yay -S android-studio
   ```
   Or download from: https://developer.android.com/studio

2. **Open Android Studio**:
   - Go to **Tools** → **SDK Manager**
   - Install **Android SDK Platform-Tools**
   - Install **Android Emulator**
   - Install a system image (e.g., Android 13 - API 33)

3. **Create an AVD**:
   - Go to **Tools** → **Device Manager**
   - Click **Create Device**
   - Select a device (e.g., Pixel 5)
   - Select a system image (e.g., Android 13 - API 33)
   - Click **Finish**

4. **Start the emulator**:
   - Click the **Play** button next to your AVD
   - Or run: `flutter emulators --launch <emulator-name>`

5. **Run the app**:
   ```bash
   cd /home/danielg/Documents/PhytoPi/dashboard
   ./scripts/dev/test_android_emulator.sh
   ```

## Important: Emulator Network Configuration

When using an emulator, you need to use a special IP address to connect to services running on your host machine:

- **Host machine IP**: `10.0.2.2` (this is the emulator's special IP for the host machine)
- **Localhost on emulator**: `127.0.0.1` or `localhost` (refers to the emulator itself)

### Supabase Configuration for Emulator

The emulator test script automatically configures the environment to use `10.0.2.2` for Supabase:

```bash
SUPABASE_URL=http://10.0.2.2:54321  # Emulator's host machine IP
```

This allows the emulator to connect to Supabase running on your host machine.

## Using the Emulator Scripts

### Setup Emulator

```bash
./scripts/dev/setup_emulator.sh
```

This script:
- Checks if Android SDK is installed
- Checks if emulator tools are available
- Creates a new emulator if needed

### Start Emulator

```bash
./scripts/dev/start_emulator.sh [emulator-name]
```

This script:
- Checks for available emulators
- Starts the specified emulator (or `phytopi_emulator` by default)
- Waits for the emulator to boot
- Verifies the emulator is ready

### Test App on Emulator

```bash
./scripts/dev/test_android_emulator.sh
```

This script:
- Starts the emulator if not running
- Configures environment for emulator (uses `10.0.2.2` for Supabase)
- Runs the Flutter app on the emulator

## Troubleshooting

### Emulator Won't Start

1. **Check if emulator tools are installed**:
   ```bash
   which emulator
   ls -la /opt/android-sdk/emulator/
   ```

2. **Check available system images**:
   ```bash
   ls -la /opt/android-sdk/system-images/
   ```

3. **Check AVD configuration**:
   ```bash
   ls -la ~/.android/avd/
   ```

### Emulator Can't Connect to Supabase

1. **Verify Supabase is running on host machine**:
   ```bash
   cd infra/supabase
   supabase status
   ```

2. **Check Supabase URL in emulator**:
   - Should be: `http://10.0.2.2:54321`
   - NOT: `http://localhost:54321` or `http://127.0.0.1:54321`

3. **Test connection from emulator**:
   ```bash
   adb shell
   curl http://10.0.2.2:54321
   ```

### Emulator is Slow

1. **Enable hardware acceleration**:
   - Install KVM (if using Linux)
   - Enable virtualization in BIOS
   - Use x86/x86_64 system images (not ARM)

2. **Increase emulator RAM**:
   - Edit AVD configuration in Android Studio
   - Increase RAM allocation (e.g., 2048MB or 4096MB)

3. **Use a lighter system image**:
   - Use Google APIs (not Google Play)
   - Use a lower API level (e.g., API 30 instead of API 33)

### Flutter Can't Find Emulator

1. **List available emulators**:
   ```bash
   flutter emulators
   ```

2. **Check ADB devices**:
   ```bash
   adb devices
   ```

3. **Restart ADB server**:
   ```bash
   adb kill-server
   adb start-server
   ```

## Comparison: Emulator vs Physical Device

### Advantages of Emulator

- ✅ No physical device needed
- ✅ Easy to test different Android versions
- ✅ Consistent testing environment
- ✅ No USB connection issues
- ✅ Easy to reset/reinstall

### Advantages of Physical Device

- ✅ More realistic performance
- ✅ Real hardware features (camera, sensors)
- ✅ Better for testing touch interactions
- ✅ Faster app startup

## Environment Configuration

When using an emulator, the test script automatically:

1. **Detects emulator**:
   - Checks if an emulator is running
   - Starts one if needed

2. **Configures Supabase URL**:
   - Uses `10.0.2.2` instead of local IP
   - This is the emulator's special IP for the host machine

3. **Sets up environment variables**:
   - Loads from `.env.local`
   - Overrides `SUPABASE_URL` for emulator

## Quick Reference

```bash
# Create emulator
flutter emulators --create --name phytopi_emulator

# List emulators
flutter emulators

# Start emulator
flutter emulators --launch phytopi_emulator

# Check running devices
adb devices

# Run app on emulator
./scripts/dev/test_android_emulator.sh

# Stop emulator
adb emu kill
```

## Next Steps

1. ✅ Set up Android emulator
2. ✅ Start the emulator
3. ✅ Run the app: `./scripts/dev/test_android_emulator.sh`
4. ✅ Test the app features

---

**Last Updated**: 2025-01-21
**Flutter Version**: 3.35.7
**Android SDK**: /opt/android-sdk

