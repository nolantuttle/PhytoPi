import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/config/supabase_config.dart';
import '../models/device_model.dart';
import '../models/sensor_model.dart';

class DeviceProvider extends ChangeNotifier {
  static const int _maxHistoryPoints = 10000; // Store up to ~1 week of minute-by-minute data

  /// Legacy rows may store raw ADC (0–255); map to % using same scale as firmware (SOIL_ADC_MAX=150).
  static double _normalizeSoilMoisture(double v) {
    if (v > 100 && v <= 255) {
      return (v * 100 / 150).clamp(0.0, 100.0);
    }
    return v.clamp(0.0, 100.0);
  }

  List<Device> _devices = [];
  Device? _selectedDevice;
  List<Sensor> _sensors = [];
  
  // Map sensor type (e.g., 'temp_c') to the latest value
  Map<String, double> _latestReadings = {};
  
  // Map sensor type to a list of data points for charts
  Map<String, List<FlSpot>> _historicalReadings = {};
  
  DateTime? _lastUpdate;
  bool _isLoading = false;
  String? _error;
  bool _hasReadings = false;
  
  RealtimeChannel? _readingsSubscription;
  RealtimeChannel? _alertsSubscription;
  RealtimeChannel? _devicesSubscription;
  RealtimeChannel? _actuatorSubscription;
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _thresholds = [];
  List<Map<String, dynamic>> _schedules = [];
  Map<String, dynamic>? _actuatorState;
  Timer? _offlineCheckTimer;
  Timer? _deviceRefreshTimer;

  /// Matches [FAN_MIN_DUTY_WHEN_ON] in controller firmware for `toggle_fans` ON.
  static const int _fanToggleOnDuty = 80;

  /// Cancels stale background refetches when a new command is sent.
  int _actuatorReconcileGeneration = 0;

  List<Device> get devices => _devices;
  List<Map<String, dynamic>> get alerts => _alerts;
  List<Map<String, dynamic>> get thresholds => _thresholds;
  List<Map<String, dynamic>> get schedules => _schedules;
  Map<String, dynamic>? get actuatorState => _actuatorState;
  Device? get selectedDevice => _selectedDevice;
  List<Sensor> get sensors => _sensors;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasReadings => _hasReadings;
  DateTime? get lastUpdate => _lastUpdate;
  
  Map<String, double> get latestReadings => _latestReadings;
  Map<String, List<FlSpot>> get historicalReadings => _historicalReadings;

  DeviceProvider() {
    _loadDevices();
  }

  /// Reload devices from Supabase (e.g. after user signs in on kiosk).
  Future<void> refreshDevices() async {
    await _loadDevices();
  }

  Future<void> _sendCommand(String commandType, Map<String, dynamic> payload) async {
    if (!SupabaseConfig.isInitialized) {
      throw Exception('Supabase not configured — cannot send command');
    }
    if (_selectedDevice == null) {
      throw Exception('No device selected — cannot send command');
    }
    await SupabaseConfig.client!
        .from(SupabaseConfig.deviceCommandsTable)
        .insert({
      'device_id': _selectedDevice!.id,
      'command_type': commandType,
      'payload': payload,
    });
  }

  /// Update Commands tab immediately; Pi applies the command ~2s later so a straight
  /// refetch would keep showing the old row and feel "stuck".
  void _applyOptimisticActuatorPatch(Map<String, dynamic> patch) {
    final id = _selectedDevice?.id;
    if (id == null) return;
    final base = _actuatorState != null
        ? Map<String, dynamic>.from(_actuatorState!)
        : <String, dynamic>{'device_id': id};
    base.addAll(patch);
    _actuatorState = base;
    notifyListeners();
  }

  /// Refetch a few times after the device has time to run the queued command.
  void _scheduleActuatorReconcileWithServer() {
    if (!SupabaseConfig.isInitialized) return;
    final id = _selectedDevice?.id;
    if (id == null) return;
    final gen = ++_actuatorReconcileGeneration;
    unawaited(Future<void>(() async {
      const delays = [
        Duration(milliseconds: 800),
        Duration(milliseconds: 2500),
        Duration(milliseconds: 5000),
      ];
      for (final d in delays) {
        await Future<void>.delayed(d);
        if (gen != _actuatorReconcileGeneration) return;
        if (_selectedDevice?.id != id) return;
        await _fetchActuatorState(id);
      }
    }));
  }

  Future<void> toggleGrowLights(bool on) async {
    try {
      await _sendCommand('toggle_light', {'state': on});
      _applyOptimisticActuatorPatch({'lights_on': on});
      _scheduleActuatorReconcileWithServer();
    } catch (e) {
      _error = e.toString();
      debugPrint('DeviceProvider: Error toggling grow lights: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> togglePump(bool on, {int? durationSec}) async {
    try {
      final payload = <String, dynamic>{'state': on};
      if (durationSec != null) payload['duration_sec'] = durationSec;
      await _sendCommand('toggle_pump', payload);
      _applyOptimisticActuatorPatch({'pump_on': on});
      _scheduleActuatorReconcileWithServer();
    } catch (e) {
      _error = e.toString();
      debugPrint('DeviceProvider: Error toggling pump: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleFans(bool on) async {
    try {
      await _sendCommand('toggle_fans', {'state': on});
      _applyOptimisticActuatorPatch({'fan_duty': on ? _fanToggleOnDuty : 0});
      _scheduleActuatorReconcileWithServer();
    } catch (e) {
      _error = e.toString();
      debugPrint('DeviceProvider: Error toggling fans: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setFanSpeed(int fanId, int dutyPercent) async {
    try {
      await _sendCommand('set_fan_speed', {
        'fan_id': fanId,
        'duty_percent': dutyPercent.clamp(0, 100),
      });
      final d = dutyPercent.clamp(0, 100);
      _applyOptimisticActuatorPatch({'fan_duty': d});
      _scheduleActuatorReconcileWithServer();
    } catch (e) {
      _error = e.toString();
      debugPrint('DeviceProvider: Error setting fan speed: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> runVentilation({int durationSec = 300, int dutyPercent = 80}) async {
    try {
      await _sendCommand('run_ventilation', {
        'duration_sec': durationSec,
        'duty_percent': dutyPercent,
      });
      final d = dutyPercent.clamp(0, 100);
      _applyOptimisticActuatorPatch({'fan_duty': d});
      _scheduleActuatorReconcileWithServer();
    } catch (e) {
      _error = e.toString();
      debugPrint('DeviceProvider: Error running ventilation: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _loadDevices({bool silent = false}) async {
    if (!SupabaseConfig.isInitialized) {
      _loadDemoDevices();
      return;
    }

    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final response = await SupabaseConfig.client!
          .from(SupabaseConfig.devicesTable)
          .select('id, name, last_seen, status, updated_at, created_at, registered_at')
          .order('created_at');

      final data = response as List<dynamic>;
      final lastReadingByDevice = await _fetchLatestReadingByDevice();
      _devices = data.map((json) {
        final row = Map<String, dynamic>.from(json as Map);
        final deviceId = row['id']?.toString();
        final lastReadingAt = deviceId != null ? lastReadingByDevice[deviceId] : null;
        if (lastReadingAt != null) {
          row['last_reading_at'] = lastReadingAt.toUtc().toIso8601String();
        }
        return Device.fromJson(row);
      }).toList();
      
      // Auto-select first device if none selected
      if (_selectedDevice == null && _devices.isNotEmpty) {
        selectDevice(_devices.first);
      }

      _subscribeToDevices();
      _startOfflineCheckTimer();
      _startDeviceRefreshTimer();
      
    } catch (e) {
      if (!silent) _error = e.toString();
      debugPrint('DeviceProvider: Error loading devices: $e');
    } finally {
      if (!silent) _isLoading = false;
      notifyListeners();
    }
  }

  void _subscribeToDevices() {
    if (_devicesSubscription != null) {
      SupabaseConfig.client?.removeChannel(_devicesSubscription!);
      _devicesSubscription = null;
    }
    _devicesSubscription = SupabaseConfig.client!
        .channel('device_units')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConfig.devicesTable,
          callback: (payload) {
            final record = Map<String, dynamic>.from(payload.newRecord);
            final id = record['id'] as String?;
            if (id == null) return;
            final idx = _devices.indexWhere((d) => d.id == id);
            if (idx >= 0) {
              // Merge: Realtime UPDATE may only send changed cols; preserve existing when missing
              final existing = _devices[idx];
              final merged = {
                'id': existing.id,
                'name': record['name'] ?? existing.name,
                'status': record['status'],
                'last_seen': record['last_seen'] ?? existing.lastSeen?.toUtc().toIso8601String(),
                'last_reading_at': existing.lastReadingAt?.toUtc().toIso8601String(),
                'updated_at': record['updated_at'],
                'is_online': record['is_online'],
              };
              _devices[idx] = Device.fromJson(merged);
              notifyListeners();
            }
          },
        )
        .subscribe();
  }

  void _startOfflineCheckTimer() {
    _offlineCheckTimer?.cancel();
    // Rebuild UI every 15s so isOnline getter re-evaluates (devices may have gone offline)
    _offlineCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_devices.isNotEmpty) notifyListeners();
    });
  }

  void _startDeviceRefreshTimer() {
    _deviceRefreshTimer?.cancel();
    // Refresh devices every 45s to pick up last_seen (fallback if Realtime misses updates)
    _deviceRefreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (SupabaseConfig.isInitialized && _devices.isNotEmpty) {
        _loadDevices(silent: true);
      }
    });
  }

  Future<Map<String, DateTime>> _fetchLatestReadingByDevice() async {
    final out = <String, DateTime>{};
    try {
      // Fallback online signal: if readings are arriving recently, device is active.
      final cutoff = DateTime.now().toUtc().subtract(const Duration(seconds: 120)).toIso8601String();
      final response = await SupabaseConfig.client!
          .from(SupabaseConfig.readingsTable)
          .select('ts, sensors!inner(device_id)')
          .gte('ts', cutoff)
          .order('ts', ascending: false)
          .limit(1000);

      for (final item in (response as List<dynamic>)) {
        final row = Map<String, dynamic>.from(item as Map);
        final tsRaw = row['ts']?.toString();
        if (tsRaw == null || tsRaw.isEmpty) continue;
        final ts = DateTime.tryParse(tsRaw);
        if (ts == null) continue;

        final sensorsObj = row['sensors'];
        String? deviceId;
        if (sensorsObj is Map<String, dynamic>) {
          deviceId = sensorsObj['device_id']?.toString();
        } else if (sensorsObj is List && sensorsObj.isNotEmpty && sensorsObj.first is Map<String, dynamic>) {
          deviceId = (sensorsObj.first as Map<String, dynamic>)['device_id']?.toString();
        }
        if (deviceId == null || deviceId.isEmpty) continue;

        out.putIfAbsent(deviceId, () => ts);
      }
    } catch (e) {
      debugPrint('DeviceProvider: readings-based online fallback unavailable: $e');
    }
    return out;
  }

  void _loadDemoDevices() {
    _devices = [
      Device(id: 'demo-1', name: 'Living Room PhytoPi', lastSeen: DateTime.now()),
      Device(id: 'demo-2', name: 'Bedroom PhytoPi', lastSeen: DateTime.now().subtract(const Duration(hours: 2))),
    ];
    
    if (_selectedDevice == null && _devices.isNotEmpty) {
      selectDevice(_devices.first);
    } else {
      notifyListeners();
    }
  }

  void selectDevice(Device device) {
    if (_selectedDevice?.id == device.id) return;
    
    _selectedDevice = device;
    _latestReadings.clear();
    _historicalReadings.clear();
    _sensors.clear();
    _alerts.clear();
    _thresholds.clear();
    _schedules.clear();
    _actuatorState = null;
    _lastUpdate = null;
    _hasReadings = false;
    
    notifyListeners();
    
    if (SupabaseConfig.isInitialized) {
      _fetchSensorsAndSubscribe(device.id);
    } else {
      _simulateDemoReadings();
    }
  }

  void clearSelection() {
    _unsubscribe();
    _selectedDevice = null;
    _sensors = [];
    _latestReadings = {};
    _historicalReadings = {};
    _hasReadings = false;
    _lastUpdate = null;
    notifyListeners();
  }

  Future<void> _fetchSensorsAndSubscribe(String deviceId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Fetch sensors with their types
      final response = await SupabaseConfig.client!
          .from(SupabaseConfig.sensorsTable)
          .select('*, sensor_types(*)')
          .eq('device_id', deviceId);
      
      final data = response as List<dynamic>;
      _sensors = data.map((json) => Sensor.fromJson(json)).toList();
      
      if (_sensors.isNotEmpty) {
        await _fetchInitialHistory();
        _subscribeToReadings();
      }
      await _fetchAlerts(deviceId);
      _subscribeToAlerts(deviceId);
      await _fetchThresholds(deviceId);
      await _fetchSchedules(deviceId);
      await _fetchActuatorState(deviceId);
      _subscribeToActuatorState(deviceId);

    } catch (e) {
      _error = e.toString();
      debugPrint('DeviceProvider: Error loading sensors: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchInitialHistory() async {
    try {
      // For each sensor, fetch initial history (up to limit)
      for (final sensor in _sensors) {
        if (sensor.sensorType == null) continue;
        
        final typeKey = sensor.sensorType!.key;
        
        final response = await SupabaseConfig.client!
            .from(SupabaseConfig.readingsTable)
            .select('value, ts')
            .eq('sensor_id', sensor.id)
            .order('ts', ascending: false)
            .limit(_maxHistoryPoints);
            
        final data = response as List<dynamic>;
        if (data.isNotEmpty) {
          // Update latest reading from the most recent one
          final latest = data.first;
          var latestVal = (latest['value'] as num).toDouble();
          if (typeKey == 'soil_moisture') {
            latestVal = _normalizeSoilMoisture(latestVal);
          }
          _latestReadings[typeKey] = latestVal;
          _lastUpdate = DateTime.parse(latest['ts']); // This will be roughly the last update
          
          // Build history (reversed because we fetched descending)
          final points = data.map((r) {
             var val = (r['value'] as num).toDouble();
             if (typeKey == 'soil_moisture') {
               val = _normalizeSoilMoisture(val);
             }
             final ts = DateTime.parse(r['ts']).millisecondsSinceEpoch.toDouble();
             return FlSpot(ts, val);
          }).toList();

          // Ensure points are sorted by X (time) to prevent chart loops
          points.sort((a, b) => a.x.compareTo(b.x));
          
          _historicalReadings[typeKey] = points;
          
          _hasReadings = true;
        }
      }
    } catch (e) {
      debugPrint('DeviceProvider: Error fetching history: $e');
    }
  }

  void _subscribeToReadings() {
    _unsubscribe();

    _readingsSubscription = SupabaseConfig.client!
        .channel('public:${SupabaseConfig.readingsTable}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConfig.readingsTable,
          callback: (payload) {
            _handleNewReading(payload.newRecord);
          },
        )
        .subscribe();
  }

  void _handleNewReading(Map<String, dynamic> record) {
    try {
      final sensorId = record['sensor_id'] as String?;
      if (sensorId == null) return;

      dynamic rawValue = record['value'];
      final double value;
      if (rawValue is num) {
        value = rawValue.toDouble();
      } else if (rawValue is String) {
        value = double.tryParse(rawValue) ?? 0.0;
      } else {
        return; // Unknown format
      }

      final tsString = record['ts'] as String?;
      final ts = tsString != null ? DateTime.parse(tsString) : DateTime.now();
      
      final sensor = _sensors.firstWhere(
        (s) => s.id == sensorId,
        orElse: () => Sensor(id: '', deviceId: '', typeId: '', metadata: {}),
      );
      
      if (sensor.id.isEmpty || sensor.sensorType == null) return;
      
      final typeKey = sensor.sensorType!.key;
      final displayValue =
          typeKey == 'soil_moisture' ? _normalizeSoilMoisture(value) : value;

      _latestReadings[typeKey] = displayValue;
      _lastUpdate = ts;
      _hasReadings = true;

      // Keep Device.lastReadingAt in sync so isOnline reflects live data arrival.
      final deviceId = sensor.deviceId;
      final devIdx = _devices.indexWhere((d) => d.id == deviceId);
      if (devIdx >= 0) {
        final updated = _devices[devIdx].copyWith(lastReadingAt: ts);
        _devices[devIdx] = updated;
        if (_selectedDevice?.id == deviceId) {
          _selectedDevice = updated;
        }
      }

      // Update history
      final currentHistory = _historicalReadings[typeKey] ?? [];
      final newTimestamp = ts.millisecondsSinceEpoch.toDouble();
      
      // Add new point
      currentHistory.add(FlSpot(newTimestamp, displayValue));
      
      // Keep only last N points, but after sorting to ensure we keep the newest ones
      // Sort by X (time) to prevent chart loops
      currentHistory.sort((a, b) => a.x.compareTo(b.x));
      
      if (currentHistory.length > _maxHistoryPoints) {
        // Remove oldest points (first ones after sort)
        final excess = currentHistory.length - _maxHistoryPoints;
        currentHistory.removeRange(0, excess);
      }
      
      _historicalReadings[typeKey] = List.from(currentHistory);
      
      notifyListeners();
    } catch (e) {
      debugPrint('DeviceProvider: Error handling new reading: $e');
    }
  }

  void _unsubscribe() {
    if (_readingsSubscription != null) {
      SupabaseConfig.client?.removeChannel(_readingsSubscription!);
      _readingsSubscription = null;
    }
    if (_alertsSubscription != null) {
      SupabaseConfig.client?.removeChannel(_alertsSubscription!);
      _alertsSubscription = null;
    }
    if (_actuatorSubscription != null) {
      SupabaseConfig.client?.removeChannel(_actuatorSubscription!);
      _actuatorSubscription = null;
    }
    // Keep _devicesSubscription and _offlineCheckTimer - they persist across device selection
  }

  Future<void> _fetchAlerts(String deviceId) async {
    try {
      final response = await SupabaseConfig.client!
          .from(SupabaseConfig.alertsTable)
          .select()
          .eq('device_id', deviceId)
          .order('triggered_at', ascending: false)
          .limit(50);
      _alerts = List<Map<String, dynamic>>.from(response as List);
      notifyListeners();
    } catch (e) {
      debugPrint('DeviceProvider: Error fetching alerts: $e');
    }
  }

  void _subscribeToAlerts(String deviceId) {
    if (_alertsSubscription != null) {
      SupabaseConfig.client?.removeChannel(_alertsSubscription!);
      _alertsSubscription = null;
    }
    _alertsSubscription = SupabaseConfig.client!
        .channel('alerts_$deviceId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConfig.alertsTable,
          callback: (payload) {
            final record = Map<String, dynamic>.from(payload.newRecord);
            if (record['device_id'] == deviceId) {
              _alerts.insert(0, record);
              notifyListeners();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConfig.alertsTable,
          callback: (payload) {
            final record = Map<String, dynamic>.from(payload.newRecord);
            if (record['device_id'] == deviceId) {
              final idx = _alerts.indexWhere((a) => a['id'] == record['id']);
              if (idx >= 0) {
                _alerts[idx] = record;
                notifyListeners();
              }
            }
          },
        )
        .subscribe();
  }

  bool get hasWaterLevelLowAlert =>
      _alerts.any((a) =>
          a['type'] == 'water_level_low' && a['resolved_at'] == null);

  List<Map<String, dynamic>> get activeAlerts =>
      _alerts.where((a) => a['resolved_at'] == null).toList();

  List<Map<String, dynamic>> get alertHistory =>
      _alerts.where((a) => a['resolved_at'] != null).toList();

  /// Returns (suggestedMin, suggestedMax) for a metric key derived from
  /// recent reading history already loaded in [_historicalReadings].
  /// The bounds are widened by ~10 % of range so they sit just outside
  /// observed values.  Returns (null, null) when no data is available
  /// (e.g. fan_duty which has no sensor reading series).
  (double?, double?) suggestBoundsForMetric(String metricKey) {
    if (metricKey == 'fan_duty') return (null, null);

    final points = _historicalReadings[metricKey];
    if (points != null && points.isNotEmpty) {
      var minVal = points.map((p) => p.y).reduce((a, b) => a < b ? a : b);
      var maxVal = points.map((p) => p.y).reduce((a, b) => a > b ? a : b);
      final padding = (maxVal - minVal) * 0.10;
      // At least 1-unit padding to avoid zero-width range on flat signals
      final pad = padding < 1.0 ? 1.0 : padding;
      return (
        double.parse((minVal - pad).toStringAsFixed(1)),
        double.parse((maxVal + pad).toStringAsFixed(1)),
      );
    }
    // Fallback: use single latest reading with ±10 % heuristic
    final latest = _latestReadings[metricKey];
    if (latest != null) {
      final pad = (latest.abs() * 0.10).clamp(1.0, double.infinity);
      return (
        double.parse((latest - pad).toStringAsFixed(1)),
        double.parse((latest + pad).toStringAsFixed(1)),
      );
    }
    return (null, null);
  }

  Future<void> _fetchThresholds(String deviceId) async {
    try {
      final response = await SupabaseConfig.client!
          .from(SupabaseConfig.deviceThresholdsTable)
          .select()
          .eq('device_id', deviceId)
          .order('metric');
      _thresholds = List<Map<String, dynamic>>.from(response as List);
      notifyListeners();
    } catch (e) {
      debugPrint('DeviceProvider: Error fetching thresholds: $e');
    }
  }

  Future<void> createThreshold(String deviceId, String metric, double? minValue, double? maxValue) async {
    if (!SupabaseConfig.isInitialized) throw Exception('Supabase not configured');
    await SupabaseConfig.client!
        .from(SupabaseConfig.deviceThresholdsTable)
        .insert({
      'device_id': deviceId,
      'metric': metric,
      'min_value': minValue,
      'max_value': maxValue,
      'enabled': true,
    });
    await _fetchThresholds(deviceId);
  }

  Future<void> updateThreshold(String id, {double? minValue, double? maxValue, bool? enabled}) async {
    if (!SupabaseConfig.isInitialized) throw Exception('Supabase not configured');
    final updates = <String, dynamic>{};
    if (minValue != null) updates['min_value'] = minValue;
    if (maxValue != null) updates['max_value'] = maxValue;
    if (enabled != null) updates['enabled'] = enabled;
    if (updates.isEmpty) return;
    await SupabaseConfig.client!
        .from(SupabaseConfig.deviceThresholdsTable)
        .update(updates)
        .eq('id', id);
    if (_selectedDevice != null) await _fetchThresholds(_selectedDevice!.id);
  }

  Future<void> _fetchSchedules(String deviceId) async {
    try {
      final response = await SupabaseConfig.client!
          .from(SupabaseConfig.schedulesTable)
          .select()
          .eq('device_id', deviceId)
          .order('schedule_type');
      _schedules = List<Map<String, dynamic>>.from(response as List);
      notifyListeners();
    } catch (e) {
      debugPrint('DeviceProvider: Error fetching schedules: $e');
    }
  }

  Future<void> createSchedule(String deviceId, String scheduleType, {String? cronExpr, int? intervalSeconds, Map<String, dynamic>? payload}) async {
    if (!SupabaseConfig.isInitialized) throw Exception('Supabase not configured');
    await SupabaseConfig.client!
        .from(SupabaseConfig.schedulesTable)
        .insert({
      'device_id': deviceId,
      'schedule_type': scheduleType,
      'cron_expr': cronExpr,
      'interval_seconds': intervalSeconds,
      'payload': payload ?? {},
      'enabled': true,
    });
    await _fetchSchedules(deviceId);
  }

  Future<void> updateSchedule(String id, {String? cronExpr, int? intervalSeconds, Map<String, dynamic>? payload, bool? enabled}) async {
    if (!SupabaseConfig.isInitialized) throw Exception('Supabase not configured');
    final updates = <String, dynamic>{};
    if (cronExpr != null) updates['cron_expr'] = cronExpr;
    if (intervalSeconds != null) updates['interval_seconds'] = intervalSeconds;
    if (payload != null) updates['payload'] = payload;
    if (enabled != null) updates['enabled'] = enabled;
    if (updates.isEmpty) return;
    await SupabaseConfig.client!
        .from(SupabaseConfig.schedulesTable)
        .update(updates)
        .eq('id', id);
    if (_selectedDevice != null) await _fetchSchedules(_selectedDevice!.id);
  }

  Future<void> deleteSchedule(String id) async {
    if (!SupabaseConfig.isInitialized) throw Exception('Supabase not configured');
    await SupabaseConfig.client!
        .from(SupabaseConfig.schedulesTable)
        .delete()
        .eq('id', id);
    if (_selectedDevice != null) await _fetchSchedules(_selectedDevice!.id);
  }

  Future<void> deleteThreshold(String id) async {
    if (!SupabaseConfig.isInitialized) throw Exception('Supabase not configured');
    await SupabaseConfig.client!
        .from(SupabaseConfig.deviceThresholdsTable)
        .delete()
        .eq('id', id);
    if (_selectedDevice != null) await _fetchThresholds(_selectedDevice!.id);
  }

  Future<void> _fetchActuatorState(String deviceId) async {
    if (!SupabaseConfig.isInitialized) return;
    try {
      final res = await SupabaseConfig.client!
          .from('device_actuator_state')
          .select()
          .eq('device_id', deviceId)
          .maybeSingle();
      _actuatorState = res != null ? Map<String, dynamic>.from(res as Map) : null;
      notifyListeners();
    } catch (e) {
      debugPrint('DeviceProvider: Error fetching actuator state: $e');
    }
  }

  void _subscribeToActuatorState(String deviceId) {
    if (_actuatorSubscription != null) {
      SupabaseConfig.client?.removeChannel(_actuatorSubscription!);
      _actuatorSubscription = null;
    }
    _actuatorSubscription = SupabaseConfig.client!
        .channel('actuator_$deviceId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          table: 'device_actuator_state',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'device_id',
            value: deviceId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty) {
              _actuatorState = Map<String, dynamic>.from(record);
              notifyListeners();
            }
          },
        )
        .subscribe();
  }

  Future<void> closeAlert(String alertId) async {
    if (!SupabaseConfig.isInitialized) return;
    try {
      await SupabaseConfig.client!
          .from(SupabaseConfig.alertsTable)
          .update({'resolved_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', alertId);
      // Local update for immediate UI feedback (Realtime will also fire)
      final idx = _alerts.indexWhere((a) => a['id'] == alertId);
      if (idx >= 0) {
        _alerts[idx] = {..._alerts[idx], 'resolved_at': DateTime.now().toUtc().toIso8601String()};
        notifyListeners();
      }
    } catch (e) {
      debugPrint('DeviceProvider: Error closing alert: $e');
      rethrow;
    }
  }
  
  // Demo Mode Simulation
  Timer? _demoTimer;
  
  void _simulateDemoReadings() {
    _demoTimer?.cancel();
    
    // Set initial values
    _latestReadings = {
      'temp_c': 22.5,
      'humidity': 65.0,
      'light_lux': 850.0, // Lux
      'soil_moisture': 45.0,
      'water_level': 80.0,
      'water_level_frequency': 2.0, // 0-4: Empty, Low, Mid, High, Full
      'pressure': 1013.0,
      'gas_resistance': 320.0,
    };
    _hasReadings = true;
    _lastUpdate = DateTime.now();
    
    // Generate initial history
    final now = DateTime.now();
    _historicalReadings = {
      'temp_c': List.generate(10, (i) {
        final ts = now.subtract(Duration(minutes: (10 - i) * 5)).millisecondsSinceEpoch.toDouble();
        return FlSpot(ts, 20 + Random().nextDouble() * 5);
      }),
      'humidity': List.generate(10, (i) {
        final ts = now.subtract(Duration(minutes: (10 - i) * 5)).millisecondsSinceEpoch.toDouble();
        return FlSpot(ts, 60 + Random().nextDouble() * 10);
      }),
      'light_lux': List.generate(10, (i) {
        final ts = now.subtract(Duration(minutes: (10 - i) * 5)).millisecondsSinceEpoch.toDouble();
        return FlSpot(ts, 800 + Random().nextDouble() * 100);
      }),
      'soil_moisture': List.generate(10, (i) {
        final ts = now.subtract(Duration(minutes: (10 - i) * 5)).millisecondsSinceEpoch.toDouble();
        return FlSpot(ts, 40 + Random().nextDouble() * 10);
      }),
      'water_level': List.generate(10, (i) {
        final ts = now.subtract(Duration(minutes: (10 - i) * 5)).millisecondsSinceEpoch.toDouble();
        return FlSpot(ts, 75 + Random().nextDouble() * 5);
      }),
      'water_level_frequency': List.generate(10, (i) {
        final ts = now.subtract(Duration(minutes: (10 - i) * 5)).millisecondsSinceEpoch.toDouble();
        return FlSpot(ts, (2 + Random().nextDouble()).clamp(0.0, 4.0));
      }),
      'pressure': List.generate(10, (i) {
        final ts = now.subtract(Duration(minutes: (10 - i) * 5)).millisecondsSinceEpoch.toDouble();
        return FlSpot(ts, 1010 + Random().nextDouble() * 10);
      }),
      'gas_resistance': List.generate(10, (i) {
        final ts = now.subtract(Duration(minutes: (10 - i) * 5)).millisecondsSinceEpoch.toDouble();
        return FlSpot(ts, 200 + Random().nextDouble() * 450);
      }),
    };
    notifyListeners();

    _demoTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_selectedDevice == null) {
        timer.cancel();
        return;
      }
      
      // Update values with random walk
      final currentTemp = _latestReadings['temp_c'] ?? 22.0;
      final newTemp = currentTemp + (Random().nextDouble() - 0.5);
      _latestReadings['temp_c'] = newTemp;
      
      final currentHum = _latestReadings['humidity'] ?? 60.0;
      final newHum = currentHum + (Random().nextDouble() - 0.5) * 2;
      _latestReadings['humidity'] = newHum;

      final currentLight = _latestReadings['light_lux'] ?? 800.0;
      final newLight = (currentLight + (Random().nextDouble() - 0.5) * 50).clamp(0.0, 2000.0);
      _latestReadings['light_lux'] = newLight;

      final currentSoil = _latestReadings['soil_moisture'] ?? 45.0;
      final newSoil = (currentSoil + (Random().nextDouble() - 0.5) * 2).clamp(0.0, 100.0);
      _latestReadings['soil_moisture'] = newSoil;

      final currentWater = _latestReadings['water_level'] ?? 80.0;
      final newWater = (currentWater + (Random().nextDouble() - 0.5)).clamp(0.0, 100.0);
      _latestReadings['water_level'] = newWater;

      final now = DateTime.now();
      _lastUpdate = now;
      
      // Update history
      final ts = now.millisecondsSinceEpoch.toDouble();
      for (final key in ['temp_c', 'humidity', 'light_lux', 'soil_moisture', 'water_level', 'water_level_frequency', 'pressure', 'gas_resistance']) {
         final history = _historicalReadings[key] ?? []; // Handle potential null if key not in initial map (though it should be)
         if (history.length >= 20) history.removeAt(0);
         
         double val = 0.0;
         if (key == 'temp_c') val = newTemp;
         else if (key == 'humidity') val = newHum;
         else if (key == 'light_lux') val = newLight;
         else if (key == 'soil_moisture') val = newSoil;
         else if (key == 'water_level') val = newWater;
         else if (key == 'water_level_frequency') val = (2 + Random().nextDouble()).clamp(0.0, 4.0);
         else if (key == 'pressure') val = 1010 + Random().nextDouble() * 10;
         else if (key == 'gas_resistance') {
           final g = _latestReadings['gas_resistance'] ?? 300.0;
           val = (g + (Random().nextDouble() - 0.5) * 40).clamp(50.0, 2000.0);
           _latestReadings['gas_resistance'] = val;
         }

         history.add(FlSpot(ts, val));
         _historicalReadings[key] = List.from(history);
      }

      notifyListeners();
    });
  }

  @override
  void dispose() {
    _unsubscribe();
    if (_devicesSubscription != null) {
      SupabaseConfig.client?.removeChannel(_devicesSubscription!);
      _devicesSubscription = null;
    }
    _offlineCheckTimer?.cancel();
    _offlineCheckTimer = null;
    _deviceRefreshTimer?.cancel();
    _deviceRefreshTimer = null;
    _demoTimer?.cancel();
    super.dispose();
  }
  
  /// Apply default thresholds and schedules for indoor basil (server RPC).
  Future<void> applyBasilPreset() async {
    if (!SupabaseConfig.isInitialized) {
      throw Exception('Supabase not configured');
    }
    final device = _selectedDevice;
    if (device == null) {
      throw Exception('No device selected');
    }
    await SupabaseConfig.client!.rpc(
      'apply_plant_preset',
      params: {
        'p_device_id': device.id,
        'p_preset': 'basil',
      },
    );
    await _fetchThresholds(device.id);
    await _fetchSchedules(device.id);
    notifyListeners();
  }

  Future<void> updateDeviceName(String deviceId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw Exception('Device name cannot be empty');
    }
    if (!SupabaseConfig.isInitialized) {
      final idx = _devices.indexWhere((d) => d.id == deviceId);
      if (idx >= 0) {
        _devices[idx] = _devices[idx].copyWith(name: trimmed);
        if (_selectedDevice?.id == deviceId) {
          _selectedDevice = _selectedDevice!.copyWith(name: trimmed);
        }
        notifyListeners();
      }
      return;
    }
    await SupabaseConfig.client!
        .from(SupabaseConfig.devicesTable)
        .update({'name': trimmed}).eq('id', deviceId);
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx >= 0) {
      _devices[idx] = _devices[idx].copyWith(name: trimmed);
    }
    if (_selectedDevice?.id == deviceId) {
      _selectedDevice = _selectedDevice!.copyWith(name: trimmed);
    }
    notifyListeners();
  }

  Future<void> claimDevice(String serialNumber) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (!SupabaseConfig.isInitialized) {
        // Demo mode
        final short =
            serialNumber.length > 8 ? serialNumber.substring(0, 8) : serialNumber;
        final newDevice = Device(
          id: serialNumber,
          name: 'PhytoPi $short',
          lastSeen: DateTime.now(),
        );
        _devices.add(newDevice);
        selectDevice(newDevice);
        return;
      }

      final response = await SupabaseConfig.client!
          .rpc('claim_device_by_serial', params: {'serial_text': serialNumber});
      
      // Re-fetch devices to ensure list is up to date
      await _loadDevices();
      
      // Select the newly claimed device
      if (response != null) {
        final data = response as Map<String, dynamic>;
        final newDeviceId = data['id'];
        try {
          final newDevice = _devices.firstWhere((d) => d.id == newDeviceId);
          selectDevice(newDevice);
        } catch (_) {
          // Should not happen if _loadDevices worked
        }
      }
      
    } catch (e) {
      _error = e.toString();
      debugPrint('DeviceProvider: Error claiming device: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
