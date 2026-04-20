import '../platform/platform_detector.dart';

class AppConfig {
  // Supabase Configuration
  // If using String.fromEnvironment without const, it might pick up runtime changes, 
  // but usually environment variables need to be passed at compile/launch time via --dart-define
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '', // Empty default to force check
  );
  
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '', // Empty default to force check
  );
  
  // App Configuration - Platform-specific
  static String get appName {
    switch (PlatformDetector.currentPlatform) {
      case AppPlatform.kiosk:
        return 'PhytoPi Kiosk';
      case AppPlatform.mobile:
        return 'PhytoPi Mobile';
      case AppPlatform.web:
        return 'PhytoPi Dashboard';
      default:
        return 'PhytoPi';
    }
  }
  
  static const String appVersion = '1.0.0';
  
  // API Configuration
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:54321',
  );
  
  // Platform-specific configurations
  static bool get enableAutoRefresh {
    // Kiosk mode should auto-refresh data
    return PlatformDetector.isKiosk;
  }
  
  static bool get enableNavigation {
    // Kiosk mode might hide navigation menus
    return !PlatformDetector.isKiosk;
  }
  
  static bool get enableFullScreen {
    // Kiosk should be fullscreen
    return PlatformDetector.isKiosk;
  }
  
  static int get autoRefreshInterval {
    // Auto-refresh interval in seconds (kiosk mode)
    if (PlatformDetector.isKiosk) {
      return 30; // Refresh every 30 seconds for kiosk
    }
    return 60; // Default 60 seconds for other platforms
  }
  
  static bool get enableBackButton {
    // Disable back button in kiosk mode
    return !PlatformDetector.isKiosk;
  }
  
  // Feature Flags
  static const bool enableAnalytics = true;
  static const bool enableNotifications = true;
  static const bool enableMLInsights = true;

  /// Camera livestream URL for AI Health page. Use --dart-define=PHYTOPI_STREAM_URL=... at build.
  static const String streamUrl = String.fromEnvironment(
    'PHYTOPI_STREAM_URL',
    defaultValue: 'http://phytopi.local:8000/stream.mjpg',
  );
}
