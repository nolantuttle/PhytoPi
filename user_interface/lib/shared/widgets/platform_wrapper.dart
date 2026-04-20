import 'package:flutter/material.dart';
import '../../core/platform/platform_detector.dart';
import '../../core/config/app_config.dart';

/// Platform wrapper that applies platform-specific UI modifications
class PlatformWrapper extends StatelessWidget {
  final Widget child;
  
  const PlatformWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Apply platform-specific wrappers
    if (PlatformDetector.isKiosk) {
      return KioskWrapper(child: child);
    } else if (PlatformDetector.isMobile) {
      return MobileWrapper(child: child);
    } else {
      return WebWrapper(child: child);
    }
  }
}

/// Kiosk mode wrapper - fullscreen, no navigation, auto-refresh
class KioskWrapper extends StatelessWidget {
  final Widget child;
  
  const KioskWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      // No app bar for kiosk - handled in child widget
      // Background can be set here if needed
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    );
  }
}

/// Mobile wrapper - safe area, mobile-optimized layout
class MobileWrapper extends StatelessWidget {
  final Widget child;
  
  const MobileWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: child,
      ),
    );
  }
}

/// Web wrapper - standard web layout
class WebWrapper extends StatelessWidget {
  final Widget child;
  
  const WebWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// Responsive layout widget that adapts to screen size
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;
  
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width >= 1200) {
      return desktop;
    } else if (width >= 600 && tablet != null) {
      return tablet!;
    } else {
      return mobile;
    }
  }
}

