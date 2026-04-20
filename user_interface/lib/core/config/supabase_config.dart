import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseConfig {
  static bool _isInitialized = false;
  
  static void markAsInitialized() {
    _isInitialized = true;
  }
  
  static SupabaseClient? get client {
    if (!_isInitialized) {
      return null;
    }
    try {
      // Check if Supabase.instance exists and is accessible
      final instance = Supabase.instance;
      if (instance == null) {
        return null;
      }
      return instance.client;
    } catch (e) {
      // Supabase was not initialized or instance is not available
      if (kDebugMode) {
        debugPrint('SupabaseConfig: Error accessing client - $e');
      }
      _isInitialized = false; // Reset flag if access fails
      return null;
    }
  }
  
  static bool get isInitialized {
    if (!_isInitialized) {
      return false;
    }
    // Double-check that we can actually access the instance
    try {
      final instance = Supabase.instance;
      return instance != null;
    } catch (e) {
      _isInitialized = false;
      return false;
    }
  }
  
  // Database Tables
  static const String devicesTable = 'device_units';
  static const String sensorsTable = 'sensors';
  static const String readingsTable = 'readings';
  static const String alertsTable = 'alerts';
  static const String usersTable = 'user_profiles';
  static const String userDevicesTable = 'user_devices';
  static const String mlInferencesTable = 'ml_inferences';
  static const String deviceCommandsTable = 'device_commands';
  static const String deviceThresholdsTable = 'device_thresholds';
  static const String schedulesTable = 'schedules';

  // Real-time Channels
  static const String readingsChannel = 'readings';
  static const String alertsChannel = 'alerts';
  static const String devicesChannel = 'device_units';
}
