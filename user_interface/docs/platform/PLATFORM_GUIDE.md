# PhytoPi Multi-Platform Development Guide

This guide explains how PhytoPi uses Flutter to support Web, Mobile (iOS/Android), and Kiosk (Linux/Raspberry Pi) platforms from a single codebase.

## Overview

PhytoPi Dashboard is built with Flutter and supports three deployment targets:

1. **Web**: Browser-based dashboard for desktop and mobile browsers
2. **Mobile**: Native iOS and Android apps
3. **Kiosk**: Linux desktop app optimized for Raspberry Pi and public displays

## Architecture

### Single Codebase, Multiple Platforms

The app uses platform detection to adapt the UI and behavior for each platform:

```
lib/
├── core/
│   ├── platform/
│   │   ├── platform_detector.dart    # Platform detection
│   │   └── platform_utils.dart       # Platform utilities
│   └── config/
│       └── app_config.dart            # Platform-specific config
├── features/
│   └── dashboard/
│       └── screens/
│           └── dashboard_screen.dart  # Platform-adaptive UI
├── shared/
│   └── widgets/
│       └── platform_wrapper.dart     # Platform wrappers
└── main.dart                          # Entry point with platform setup
```

### Platform Detection

The `PlatformDetector` class identifies the current platform:

```dart
// Detect platform
if (PlatformDetector.isKiosk) {
  // Kiosk mode
} else if (PlatformDetector.isMobile) {
  // Mobile app
} else if (PlatformDetector.isWeb) {
  // Web app
}
```

### Platform-Specific Features

#### Web
- Sidebar navigation
- Multi-column layouts
- Desktop-optimized UI
- Mouse/keyboard interactions
- Responsive design

#### Mobile
- Bottom navigation
- Touch-optimized UI
- Safe area handling
- Mobile-specific layouts
- Swipe gestures

#### Kiosk
- Fullscreen display
- Auto-refresh data
- Disabled navigation
- Landscape orientation
- Large fonts and icons
- Immersive system UI

## Development Workflow

### 1. Local Development

**Web:**
```bash
cd dashboard
./scripts/run_local.sh
```

**Mobile (Android):**
```bash
flutter run -d <android-device>
```

**Mobile (iOS):**
```bash
flutter run -d <ios-device>
```

**Kiosk (Linux):**
```bash
export KIOSK_MODE=true
flutter run -d linux
```

### 2. Building for Production

**Web:**
```bash
export SUPABASE_URL=https://your-project.supabase.co
export SUPABASE_ANON_KEY=your-anon-key
./scripts/build_web.sh
```

**Mobile (Android):**
```bash
export SUPABASE_URL=https://your-project.supabase.co
export SUPABASE_ANON_KEY=your-anon-key
./scripts/build_mobile_android.sh [apk|appbundle]
```

**Mobile (iOS):**
```bash
export SUPABASE_URL=https://your-project.supabase.co
export SUPABASE_ANON_KEY=your-anon-key
./scripts/build_mobile_ios.sh
```

**Kiosk:**
```bash
export SUPABASE_URL=https://your-project.supabase.co
export SUPABASE_ANON_KEY=your-anon-key
export KIOSK_MODE=true
./scripts/build_kiosk.sh
```

## Platform-Specific Implementation

### UI Adaptation

The dashboard screen adapts its layout based on platform:

```dart
Widget build(BuildContext context) {
  if (PlatformDetector.isKiosk) {
    return _buildKioskLayout(context);
  } else if (PlatformDetector.isMobile) {
    return _buildMobileLayout(context);
  } else {
    return _buildWebLayout(context);
  }
}
```

### Configuration

Platform-specific settings are configured in `app_config.dart`:

```dart
// Auto-refresh in kiosk mode
static bool get enableAutoRefresh => PlatformDetector.isKiosk;

// Navigation visibility
static bool get enableNavigation => !PlatformDetector.isKiosk;

// Fullscreen mode
static bool get enableFullScreen => PlatformDetector.isKiosk;
```

### Utilities

Platform utilities provide platform-specific values:

```dart
// Font sizes
final fontSize = PlatformUtils.getDefaultFontSize(context);

// Padding
final padding = PlatformUtils.getDefaultPadding(context);

// Icon sizes
final iconSize = PlatformUtils.getDefaultIconSize();

// Grid columns
final columns = PlatformUtils.getGridColumnCount(context);
```

## Deployment

### Web Deployment

1. Build the web app:
   ```bash
   ./scripts/build_web.sh
   ```

2. Deploy to Vercel, Netlify, or any static hosting

3. Set environment variables in hosting platform

### Mobile Deployment

#### Android
1. Build APK or App Bundle:
   ```bash
   ./scripts/build_mobile_android.sh appbundle
   ```

2. Upload to Google Play Console

3. Submit for review

#### iOS
1. Build iOS app:
   ```bash
   ./scripts/build_mobile_ios.sh
   ```

2. Open in Xcode for code signing

3. Upload to App Store Connect

### Kiosk Deployment

1. Build kiosk app:
   ```bash
   ./scripts/build_kiosk.sh
   ```

2. Transfer to Raspberry Pi

3. Set up autostart (see [KIOSK_DEPLOYMENT.md](./KIOSK_DEPLOYMENT.md))

## Testing

### Platform Testing

Test on all platforms to ensure compatibility:

```bash
# Web
flutter test
flutter run -d chrome

# Mobile
flutter test
flutter run -d <device>

# Kiosk
export KIOSK_MODE=true
flutter test
flutter run -d linux
```

### Platform-Specific Tests

Create platform-specific test files:

```dart
// test/platform/platform_detector_test.dart
test('Platform detection', () {
  expect(PlatformDetector.isKiosk, isFalse);
  expect(PlatformDetector.isMobile, isFalse);
  expect(PlatformDetector.isWeb, isTrue);
});
```

## Best Practices

### 1. Platform Detection

- Use `PlatformDetector` for conditional logic
- Avoid hardcoding platform checks
- Test on all platforms

### 2. UI Adaptation

- Create platform-specific layouts
- Use `ResponsiveLayout` for adaptive UIs
- Test on different screen sizes

### 3. Configuration

- Use `AppConfig` for platform-specific settings
- Avoid platform-specific code in business logic
- Keep platform code isolated

### 4. Utilities

- Use `PlatformUtils` for platform-specific values
- Don't duplicate platform detection logic
- Keep utilities platform-agnostic

### 5. Testing

- Test on all platforms
- Use platform-specific test files
- Verify platform detection works correctly

## Common Patterns

### Conditional Rendering

```dart
Widget build(BuildContext context) {
  return PlatformDetector.isKiosk
    ? KioskWidget()
    : PlatformDetector.isMobile
      ? MobileWidget()
      : WebWidget();
}
```

### Platform-Specific Values

```dart
final padding = PlatformDetector.isKiosk
  ? EdgeInsets.all(32.0)
  : PlatformDetector.isMobile
    ? EdgeInsets.all(16.0)
    : EdgeInsets.all(24.0);
```

### Responsive Layout

```dart
ResponsiveLayout(
  mobile: MobileLayout(),
  tablet: TabletLayout(),
  desktop: DesktopLayout(),
)
```

## Troubleshooting

### Platform Not Detected

1. Check `PlatformDetector` logic
2. Verify environment variables
3. Check compile-time flags
4. Test platform detection

### Platform-Specific Features Not Working

1. Verify platform detection
2. Check platform-specific configuration
3. Ensure platform-specific widgets are used
4. Test on target platform

### Build Issues

1. Verify Flutter platform support
2. Check platform-specific dependencies
3. Verify build scripts are executable
4. Check environment variables

## Resources

- [Flutter Platform Channels](https://docs.flutter.dev/development/platform-integration/platform-channels)
- [Flutter Responsive Design](https://docs.flutter.dev/development/ui/layout/responsive)
- [Flutter Desktop Support](https://docs.flutter.dev/development/platform-integration/desktop)
- [Flutter Web Support](https://docs.flutter.dev/development/platform-integration/web)
- [Kiosk Deployment Guide](./KIOSK_DEPLOYMENT.md)
- [Scripts Documentation](./scripts/README.md)

## Support

For issues or questions:
1. Check platform detection logic
2. Verify platform-specific configuration
3. Test on target platform
4. Consult Flutter documentation
5. Review platform-specific guides

