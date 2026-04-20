# Multi-Platform Setup Guide

This document explains how to use PhytoPi Dashboard across different platforms: Web, Mobile (iOS/Android), and Kiosk (Linux/Raspberry Pi).

## Overview

The PhytoPi Dashboard uses a single Flutter codebase that automatically adapts to different platforms:

- **Web**: Full-featured dashboard with sidebar navigation
- **Mobile**: Mobile-optimized UI with bottom navigation
- **Kiosk**: Fullscreen display mode for Raspberry Pi or dedicated displays

## Platform Detection

The app automatically detects the platform using `PlatformDetector`:

```dart
import 'core/platform/platform_detector.dart';

// Check current platform
if (PlatformDetector.isWeb) {
  // Web-specific code
} else if (PlatformDetector.isMobile) {
  // Mobile-specific code
} else if (PlatformDetector.isKiosk) {
  // Kiosk-specific code
}
```

## Building for Different Platforms

### Web

Build for web deployment:

```bash
./scripts/build_web.sh
```

Or manually:

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
```

### Android Mobile

Build Android APK:

```bash
./scripts/build_mobile_android.sh apk
```

Build Android App Bundle (for Play Store):

```bash
./scripts/build_mobile_android.sh appbundle
```

Or manually:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
```

### iOS Mobile

Build for iOS (macOS only):

```bash
./scripts/build_mobile_ios.sh
```

Or manually:

```bash
flutter build ios --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
```

### Kiosk Mode (Linux/Raspberry Pi)

Build for kiosk mode:

```bash
KIOSK_MODE=true ./scripts/build_kiosk.sh
```

Or manually:

```bash
flutter build linux --release \
  --dart-define=KIOSK_MODE=true \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
```

## Platform-Specific Features

### Web

- Sidebar navigation with NavigationRail
- Multi-column layout
- Responsive design
- Full feature set

### Mobile

- Bottom navigation bar
- Touch-optimized UI
- Safe area handling
- Mobile-specific gestures

### Kiosk Mode

- Fullscreen display
- Auto-refresh (every 30 seconds)
- Large text for viewing distance
- No navigation menus
- Landscape orientation preferred
- Back button disabled
- System UI hidden

## Environment Variables

Set these environment variables before building:

```bash
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_ANON_KEY="your-anon-key"
```

For kiosk mode:

```bash
export KIOSK_MODE="true"
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_ANON_KEY="your-anon-key"
```

## Running Locally

### Web

```bash
flutter run -d chrome --web-port 3000
```

### Android

```bash
flutter run -d android
```

### iOS

```bash
flutter run -d ios
```

### Linux (Kiosk)

```bash
flutter run -d linux --dart-define=KIOSK_MODE=true
```

## Kiosk Mode Setup for Raspberry Pi

### 1. Install Flutter on Raspberry Pi

Follow the Flutter Linux installation guide for ARM architecture.

### 2. Build the App

```bash
./scripts/build_kiosk.sh
```

### 3. Create Systemd Service

Create `/etc/systemd/system/phytopi-kiosk.service`:

```ini
[Unit]
Description=PhytoPi Kiosk
After=graphical.target

[Service]
Type=simple
User=pi
Environment=DISPLAY=:0
Environment=KIOSK_MODE=true
Environment=SUPABASE_URL=https://your-project.supabase.co
Environment=SUPABASE_ANON_KEY=your-anon-key
WorkingDirectory=/home/pi/phytopi/build/linux/x64/release/bundle
ExecStart=/home/pi/phytopi/build/linux/x64/release/bundle/phytopi_dashboard
Restart=always
RestartSec=10

[Install]
WantedBy=graphical.target
```

### 4. Enable and Start Service

```bash
sudo systemctl enable phytopi-kiosk.service
sudo systemctl start phytopi-kiosk.service
```

### 5. Configure Display

Disable screen blanking:

```bash
sudo raspi-config
# Navigate to Display Options > Screen Blanking > Disable
```

Or edit `/boot/config.txt`:

```
disable_overscan=1
hdmi_force_hotplug=1
hdmi_group=2
hdmi_mode=82
```

### 6. Auto-login (Optional)

Enable auto-login to desktop:

```bash
sudo raspi-config
# Navigate to System Options > Boot / Auto Login > Desktop Autologin
```

## Platform-Specific Configuration

### AppConfig

The `AppConfig` class provides platform-specific settings:

```dart
import 'core/config/app_config.dart';

// Platform-specific app name
String appName = AppConfig.appName; // "PhytoPi Kiosk", "PhytoPi Mobile", or "PhytoPi Dashboard"

// Auto-refresh (kiosk mode only)
bool autoRefresh = AppConfig.enableAutoRefresh;

// Navigation (disabled in kiosk mode)
bool navigation = AppConfig.enableNavigation;

// Auto-refresh interval
int interval = AppConfig.autoRefreshInterval; // 30s for kiosk, 60s for others
```

## Architecture

### Platform Detection

- `lib/core/platform/platform_detector.dart`: Detects current platform
- Uses compile-time flags (`--dart-define=KIOSK_MODE=true`) and runtime checks

### Platform Wrappers

- `lib/shared/widgets/platform_wrapper.dart`: Applies platform-specific UI wrappers
- Handles safe areas, fullscreen, etc.

### Platform-Specific UI

- `lib/features/dashboard/screens/dashboard_screen.dart`: Contains platform-specific layouts
- `_buildKioskLayout()`: Kiosk mode UI
- `_buildMobileLayout()`: Mobile UI
- `_buildWebLayout()`: Web UI

## Troubleshooting

### Kiosk Mode Not Activating

1. Check that `KIOSK_MODE=true` is set during build
2. Verify you're running on Linux (not Windows/macOS)
3. Check platform detection: `PlatformDetector.isKiosk`

### Platform Detection Issues

The platform detector checks:
1. Compile-time flag: `--dart-define=KIOSK_MODE=true`
2. Runtime environment variable: `Platform.environment['KIOSK_MODE']`
3. Operating system: Linux = kiosk/desktop, Android/iOS = mobile, Web = web

### Build Issues

- **Web**: Ensure `flutter config --enable-web` is set
- **Android**: Install Android SDK and accept licenses
- **iOS**: Requires macOS and Xcode
- **Linux**: Enable Linux desktop support: `flutter config --enable-linux-desktop`

## Development Tips

1. **Test on each platform**: Use `flutter run -d <device>` to test on different platforms
2. **Platform-specific debugging**: Use `PlatformDetector.currentPlatform` to debug
3. **Responsive design**: Use `PlatformDetector.isLargeScreen(context)` for responsive layouts
4. **Conditional compilation**: Use `--dart-define` for platform-specific features

## Next Steps

- Add platform-specific features as needed
- Customize UI for each platform
- Add platform-specific plugins (e.g., `wakelock` for kiosk mode)
- Set up CI/CD for multi-platform builds

