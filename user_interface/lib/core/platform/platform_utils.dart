// import 'dart:io' show Platform; // Removed to prevent web crashes
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'platform_detector.dart';

/// Platform-specific utilities and helpers
class PlatformUtils {
  /// Get the default font size for the current platform
  static double getDefaultFontSize(BuildContext context) {
    if (PlatformDetector.isKiosk) {
      return 18.0; // Larger font for kiosk viewing distance
    } else if (PlatformDetector.isMobile) {
      return 14.0; // Standard mobile font size
    } else {
      return 16.0; // Standard web/desktop font size
    }
  }

  /// Get the default padding for the current platform
  static EdgeInsets getDefaultPadding(BuildContext context) {
    if (PlatformDetector.isKiosk) {
      return const EdgeInsets.all(32.0); // Larger padding for kiosk
    } else if (PlatformDetector.isMobile) {
      return const EdgeInsets.all(16.0); // Standard mobile padding
    } else {
      return const EdgeInsets.all(24.0); // Standard web/desktop padding
    }
  }

  /// Get the default icon size for the current platform
  static double getDefaultIconSize() {
    if (PlatformDetector.isKiosk) {
      return 48.0; // Larger icons for kiosk
    } else if (PlatformDetector.isMobile) {
      return 24.0; // Standard mobile icon size
    } else {
      return 32.0; // Standard web/desktop icon size
    }
  }

  /// Check if the device is in landscape orientation
  static bool isLandscape(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    return orientation == Orientation.landscape;
  }

  /// Get the appropriate number of columns for a grid based on platform
  static int getGridColumnCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (PlatformDetector.isKiosk) {
      // Kiosk mode: more columns for larger displays
      if (width > 1920) return 4;
      if (width > 1280) return 3;
      return 2;
    } else if (PlatformDetector.isMobile) {
      // Mobile: single column
      return 1;
    } else {
      // Web/Desktop: responsive columns
      if (width > 1200) return 3;
      if (width > 800) return 2;
      return 1;
    }
  }

  /// Get platform-specific navigation bar height
  static double getNavigationBarHeight() {
    if (PlatformDetector.isKiosk) {
      return 0; // No navigation bar in kiosk mode
    } else if (PlatformDetector.isMobile) {
      return kBottomNavigationBarHeight; // Standard bottom navigation
    } else {
      return 0; // Web uses sidebar, not bottom nav
    }
  }

  /// Check if platform supports file system access
  static bool supportsFileSystem() {
    return !kIsWeb && PlatformDetector.isDesktop;
  }

  /// Check if platform supports notifications
  static bool supportsNotifications() {
    // Web and mobile support notifications, but implementation differs
    return true;
  }

  /// Get platform name as string
  static String getPlatformName() {
    if (kIsWeb) return 'Web';
    if (PlatformDetector.isAndroid) return 'Android';
    if (PlatformDetector.isIOS) return 'iOS';
    if (PlatformDetector.isLinux) return 'Linux';
    if (PlatformDetector.isWindows) return 'Windows';
    if (PlatformDetector.isMacOS) return 'macOS';
    return 'Unknown';
  }

  /// Get device type description
  static String getDeviceType() {
    if (PlatformDetector.isKiosk) return 'Kiosk';
    if (PlatformDetector.isMobile) return 'Mobile';
    if (PlatformDetector.isDesktop) return 'Desktop';
    if (PlatformDetector.isWeb) return 'Web';
    return 'Unknown';
  }

  /// Check if app should show debug banner
  static bool shouldShowDebugBanner() {
    // Don't show debug banner in kiosk mode
    return !PlatformDetector.isKiosk;
  }

  /// Get appropriate animation duration for platform
  static Duration getAnimationDuration() {
    // Kiosk might want slower animations for visibility
    if (PlatformDetector.isKiosk) {
      return const Duration(milliseconds: 400);
    }
    // Standard animation duration
    return const Duration(milliseconds: 300);
  }

  /// Check if platform supports background tasks
  static bool supportsBackgroundTasks() {
    // Mobile platforms support background tasks better than web
    return PlatformDetector.isMobile;
  }

  /// Get platform-specific max width for content
  static double? getMaxContentWidth(BuildContext context) {
    if (PlatformDetector.isKiosk) {
      return null; // Full width for kiosk
    } else if (PlatformDetector.isMobile) {
      return null; // Full width for mobile
    } else {
      // Limit width on web/desktop for better readability
      return 1400.0;
    }
  }
}

