# Platform Detection & Utilities

This directory contains platform detection and utility classes for supporting multiple platforms (Web, Mobile, Kiosk) in a single Flutter codebase.

## Files

### `platform_detector.dart`
Main platform detection class that identifies the current platform:
- `AppPlatform` enum: web, mobile, kiosk, desktop
- `PlatformDetector` class: Static methods for platform detection
- Runtime and compile-time kiosk mode detection

### `platform_utils.dart`
Platform-specific utility functions:
- Font sizes, padding, icon sizes
- Grid column counts
- Navigation bar heights
- Animation durations
- Platform capabilities checking

## Usage

### Platform Detection

```dart
import 'package:phytopi_dashboard/core/platform/platform_detector.dart';

// Check platform type
if (PlatformDetector.isKiosk) {
  // Kiosk-specific code
} else if (PlatformDetector.isMobile) {
  // Mobile-specific code
} else if (PlatformDetector.isWeb) {
  // Web-specific code
}

// Get current platform
final platform = PlatformDetector.currentPlatform;
switch (platform) {
  case AppPlatform.kiosk:
    // Kiosk code
    break;
  case AppPlatform.mobile:
    // Mobile code
    break;
  case AppPlatform.web:
    // Web code
    break;
  default:
    // Desktop code
}
```

### Platform Utilities

```dart
import 'package:phytopi_dashboard/core/platform/platform_utils.dart';

// Get platform-specific font size
final fontSize = PlatformUtils.getDefaultFontSize(context);

// Get platform-specific padding
final padding = PlatformUtils.getDefaultPadding(context);

// Get platform-specific icon size
final iconSize = PlatformUtils.getDefaultIconSize();

// Get grid column count
final columns = PlatformUtils.getGridColumnCount(context);

// Check platform capabilities
if (PlatformUtils.supportsFileSystem()) {
  // File system operations
}

if (PlatformUtils.supportsNotifications()) {
  // Notification operations
}
```

### Responsive Layout

```dart
import 'package:phytopi_dashboard/shared/widgets/platform_wrapper.dart';

// Use responsive layout widget
ResponsiveLayout(
  mobile: MobileWidget(),
  tablet: TabletWidget(),
  desktop: DesktopWidget(),
)
```

## Platform-Specific Features

### Kiosk Mode
- Fullscreen display
- Auto-refresh data
- Disabled navigation
- Landscape orientation
- Large fonts and icons
- Immersive system UI

### Mobile
- Bottom navigation
- Touch-optimized UI
- Safe area handling
- Mobile-specific layouts
- Swipe gestures

### Web
- Sidebar navigation
- Multi-column layouts
- Desktop-optimized UI
- Mouse/keyboard interactions
- Responsive design

## Configuration

### Enable Kiosk Mode

**Compile-time (recommended):**
```bash
flutter build linux --release --dart-define=KIOSK_MODE=true
```

**Runtime:**
```bash
export KIOSK_MODE=true
./phytopi_dashboard
```

### Platform-Specific Configuration

Platform-specific settings are configured in `app_config.dart`:
- `enableAutoRefresh`: Auto-refresh in kiosk mode
- `enableNavigation`: Show/hide navigation
- `enableFullScreen`: Fullscreen mode
- `autoRefreshInterval`: Refresh interval
- `enableBackButton`: Enable/disable back button

## Best Practices

1. **Use PlatformDetector for conditional logic:**
   ```dart
   if (PlatformDetector.isKiosk) {
     // Kiosk-specific code
   }
   ```

2. **Use PlatformUtils for platform-specific values:**
   ```dart
   final padding = PlatformUtils.getDefaultPadding(context);
   ```

3. **Create platform-specific widgets:**
   ```dart
   Widget build(BuildContext context) {
     if (PlatformDetector.isKiosk) {
       return KioskWidget();
     } else if (PlatformDetector.isMobile) {
       return MobileWidget();
     } else {
       return WebWidget();
     }
   }
   ```

4. **Use ResponsiveLayout for adaptive UIs:**
   ```dart
   ResponsiveLayout(
     mobile: MobileLayout(),
     tablet: TabletLayout(),
     desktop: DesktopLayout(),
   )
   ```

5. **Test on all platforms:**
   - Web: `flutter run -d chrome`
   - Mobile: `flutter run -d <device>`
   - Kiosk: `flutter run -d linux --dart-define=KIOSK_MODE=true`

## Testing

### Test Platform Detection
```dart
test('Platform detection', () {
  // Test kiosk mode detection
  expect(PlatformDetector.isKiosk, isTrue);
  
  // Test mobile detection
  expect(PlatformDetector.isMobile, isTrue);
  
  // Test web detection
  expect(PlatformDetector.isWeb, isTrue);
});
```

### Test Platform Utilities
```dart
test('Platform utilities', () {
  final context = MockBuildContext();
  
  // Test font size
  final fontSize = PlatformUtils.getDefaultFontSize(context);
  expect(fontSize, greaterThan(0));
  
  // Test padding
  final padding = PlatformUtils.getDefaultPadding(context);
  expect(padding, isNotNull);
});
```

## Troubleshooting

### Kiosk Mode Not Detected
- Check `KIOSK_MODE` environment variable
- Verify compile-time flag: `--dart-define=KIOSK_MODE=true`
- Check platform detection logic in `platform_detector.dart`

### Platform-Specific Features Not Working
- Verify platform detection is working
- Check platform-specific configuration in `app_config.dart`
- Ensure platform-specific widgets are being used

### Build Issues
- Verify Flutter platform support: `flutter doctor`
- Check platform-specific dependencies in `pubspec.yaml`
- Verify build scripts are executable: `chmod +x scripts/*.sh`

## Resources

- [Flutter Platform Channels](https://docs.flutter.dev/development/platform-integration/platform-channels)
- [Flutter Responsive Design](https://docs.flutter.dev/development/ui/layout/responsive)
- [Flutter Desktop Support](https://docs.flutter.dev/development/platform-integration/desktop)

