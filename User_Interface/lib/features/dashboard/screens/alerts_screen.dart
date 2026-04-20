import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/config/supabase_config.dart';
import '../providers/device_provider.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _alertsScrollController = ScrollController();
  final ScrollController _commandsScrollController = ScrollController();
  final ScrollController _schedulesScrollController = ScrollController();
  final ScrollController _thresholdsScrollController = ScrollController();
  // Commands state is driven entirely from DeviceProvider.actuatorState — no local defaults needed.
  String? _historySeverityFilter; // null = all, 'critical', 'high', 'medium', 'low'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _alertsScrollController.dispose();
    _commandsScrollController.dispose();
    _schedulesScrollController.dispose();
    _thresholdsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceProvider = context.watch<DeviceProvider>();
    final selectedDevice = deviceProvider.selectedDevice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts & Commands'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Alerts', icon: Icon(Icons.notifications)),
            Tab(text: 'Commands', icon: Icon(Icons.touch_app)),
            Tab(text: 'Schedules', icon: Icon(Icons.schedule)),
            Tab(text: 'Thresholds', icon: Icon(Icons.tune)),
          ],
        ),
      ),
      body: selectedDevice == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.devices_other, size: 64, color: theme.disabledColor),
                  const SizedBox(height: 16),
                  Text(
                    'Select a device to manage alerts and commands',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            )
          : IndexedStack(
              index: _tabController.index,
              children: [
                _buildAlertsTab(deviceProvider),
                _buildCommandsTab(deviceProvider),
                _buildSchedulesTab(deviceProvider),
                _buildThresholdsTab(deviceProvider),
              ],
            ),
    );
  }

  Widget _buildAlertsTab(DeviceProvider deviceProvider) {
    final theme = Theme.of(context);
    final activeAlerts = deviceProvider.activeAlerts;
    final alertHistory = deviceProvider.alertHistory;

    return ListView(
      controller: _alertsScrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // Active Alerts
        Text('Active Alerts', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (activeAlerts.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 48, color: Colors.green[300]),
                  const SizedBox(width: 16),
                  Text('No active alerts', style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          )
        else
          ...activeAlerts.map((a) => _buildAlertCard(theme, deviceProvider, a, resolved: false)),
        const SizedBox(height: 24),
        // Alert History
        Text('Alert History', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('All'),
              selected: _historySeverityFilter == null,
              onSelected: (_) => setState(() => _historySeverityFilter = null),
            ),
            FilterChip(
              label: const Text('Critical'),
              selected: _historySeverityFilter == 'critical',
              onSelected: (_) => setState(() => _historySeverityFilter = 'critical'),
            ),
            FilterChip(
              label: const Text('High'),
              selected: _historySeverityFilter == 'high',
              onSelected: (_) => setState(() => _historySeverityFilter = 'high'),
            ),
            FilterChip(
              label: const Text('Medium'),
              selected: _historySeverityFilter == 'medium',
              onSelected: (_) => setState(() => _historySeverityFilter = 'medium'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_filteredHistory(alertHistory).isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Icon(Icons.history, size: 48, color: theme.disabledColor),
                  const SizedBox(width: 16),
                  Text('No closed alerts yet', style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          )
        else
          ..._filteredHistory(alertHistory).map((a) => _buildAlertCard(theme, deviceProvider, a, resolved: true)),
      ],
    );
  }

  List<Map<String, dynamic>> _filteredHistory(List<Map<String, dynamic>> history) {
    if (_historySeverityFilter == null) return history;
    return history.where((a) => (a['severity'] as String? ?? '') == _historySeverityFilter).toList();
  }

  Widget _buildAlertCard(ThemeData theme, DeviceProvider deviceProvider, Map<String, dynamic> a, {required bool resolved}) {
    final type = a['type'] as String? ?? '';
    final message = a['message'] as String? ?? '';
    final severity = a['severity'] as String? ?? 'medium';
    final triggered = a['triggered_at'] != null ? DateTime.parse(a['triggered_at']).toLocal() : null;
    final closed = a['resolved_at'] != null ? DateTime.parse(a['resolved_at']).toLocal() : null;
    final id = a['id'] as String? ?? '';

    Color severityColor = Colors.grey;
    if (severity == 'critical') severityColor = Colors.red;
    else if (severity == 'high') severityColor = Colors.orange;
    else if (severity == 'medium') severityColor = Colors.amber;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: resolved ? theme.colorScheme.surfaceContainerHighest : null,
      child: ListTile(
        leading: Icon(
          type == 'water_level_low' ? Icons.water_drop : Icons.warning,
          color: severityColor,
        ),
        title: Text(message),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (triggered != null) Text('Created: ${DateFormat.yMd().add_Hm().format(triggered)}'),
            if (closed != null) Text('Closed: ${DateFormat.yMd().add_Hm().format(closed)}'),
          ],
        ),
        isThreeLine: true,
        trailing: resolved
            ? Chip(label: Text('Closed', style: TextStyle(fontSize: 12)))
            : FilledButton.tonal(
                onPressed: () async {
                  try {
                    await deviceProvider.closeAlert(id);
                    if (mounted) _showSnack('Alert closed');
                  } catch (e) {
                    if (mounted) _showSnack('Failed to close: $e');
                  }
                },
                child: const Text('Close'),
              ),
      ),
    );
  }

  Widget _buildCommandsTab(DeviceProvider deviceProvider) {
    final theme = Theme.of(context);
    final state = deviceProvider.actuatorState;
    final lightsOn = state?['lights_on'] as bool? ?? false;
    final pumpOn   = state?['pump_on']   as bool? ?? false;
    final fansOn   = ((state?['fan_duty'] as num?)?.toInt() ?? 0) > 0;

    return SingleChildScrollView(
      controller: _commandsScrollController,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Manual Controls', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          _commandCard(
            title: 'Lights',
            icon: Icons.lightbulb,
            onPressed: () async {
              final target = !lightsOn;
              try {
                await deviceProvider.toggleGrowLights(target);
                _showSnack('Lights ${target ? "ON" : "OFF"}');
              } catch (e) {
                _showSnack('Failed to toggle lights: $e');
              }
            },
            state: lightsOn,
          ),
          _commandCard(
            title: 'Pump',
            icon: Icons.water_drop,
            onPressed: () async {
              final target = !pumpOn;
              try {
                await deviceProvider.togglePump(target, durationSec: 30);
                _showSnack('Pump ${target ? "ON" : "OFF"} (30s)');
              } catch (e) {
                _showSnack('Failed to toggle pump: $e');
              }
            },
            state: pumpOn,
          ),
          _commandCard(
            title: 'Fans',
            icon: Icons.air,
            onPressed: () async {
              final target = !fansOn;
              try {
                await deviceProvider.toggleFans(target);
                _showSnack('Fans ${target ? "ON" : "OFF"}');
              } catch (e) {
                _showSnack('Failed to toggle fans: $e');
              }
            },
            state: fansOn,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await deviceProvider.runVentilation(durationSec: 300, dutyPercent: 80);
                _showSnack('Ventilation run for 5 min');
              } catch (e) {
                _showSnack('Failed to run ventilation: $e');
              }
            },
            icon: const Icon(Icons.air),
            label: const Text('Run Ventilation (5 min)'),
          ),
        ],
      ),
    );
  }

  Widget _commandCard({
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
    required bool state,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: state ? Colors.green : null),
        title: Text(title),
        trailing: FilledButton(
          onPressed: onPressed,
          child: Text(state ? 'Turn Off' : 'Turn On'),
        ),
      ),
    );
  }

  static const List<Map<String, String>> _scheduleTypes = [
    {'key': 'lights', 'label': 'Lights'},
    {'key': 'pump', 'label': 'Pump'},
    {'key': 'ventilation', 'label': 'Ventilation'},
  ];

  static String _formatDuration(int sec) {
    if (sec < 60) return '$sec sec';
    if (sec < 3600) return '${sec ~/ 60} min';
    if (sec < 86400) return '${sec ~/ 3600} hr';
    return '${sec ~/ 86400} day';
  }

  static String _formatScheduleWhen(BuildContext context, String? cron, int? intervalSec) {
    if (cron != null && cron.isNotEmpty) {
      final t = _cronToTimeOfDay(cron);
      return 'At ${t.format(context)}';
    }
    if (intervalSec != null && intervalSec > 0) return 'Every ${_formatDuration(intervalSec)}';
    return 'Not set';
  }

  /// Parse cron "minute hour" to TimeOfDay.
  static TimeOfDay _cronToTimeOfDay(String cron) {
    final parts = cron.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final min = int.tryParse(parts[0]) ?? 0;
      final hour = int.tryParse(parts[1]) ?? 8;
      return TimeOfDay(hour: hour.clamp(0, 23), minute: min.clamp(0, 59));
    }
    return const TimeOfDay(hour: 8, minute: 0);
  }

  /// Convert TimeOfDay to cron "minute hour" for backend.
  static String _timeOfDayToCron(TimeOfDay t) => '${t.minute} ${t.hour}';

  Widget _buildSchedulesTab(DeviceProvider deviceProvider) {
    final theme = Theme.of(context);
    final schedules = deviceProvider.schedules;

    return ListView(
      controller: _schedulesScrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Automate lights, pump, or ventilation. The device checks schedules every 60 seconds. Cron times ("At HH:mm") run on the device\'s local clock — ensure the Pi timezone matches yours.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _showAddScheduleDialog(context, deviceProvider),
          icon: const Icon(Icons.add),
          label: const Text('Add Schedule'),
        ),
        const SizedBox(height: 20),
        if (schedules.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.schedule, size: 48, color: theme.disabledColor),
                  const SizedBox(height: 16),
                  Text('No schedules', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Add a schedule to automate lights, pump, or ventilation.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...schedules.map((s) => _buildScheduleCard(theme, deviceProvider, s)),
      ],
    );
  }

  Widget _buildScheduleCard(ThemeData theme, DeviceProvider deviceProvider, Map<String, dynamic> s) {
    final type = s['schedule_type'] as String? ?? '';
    final label = _scheduleTypes.firstWhere((m) => m['key'] == type, orElse: () => {'label': type})['label']!;
    final cronExpr = s['cron_expr'] as String? ?? '';
    final intervalSec = s['interval_seconds'] as int?;
    final lastRun = s['last_run_at'] != null ? DateTime.tryParse(s['last_run_at'])?.toLocal() : null;
    final enabled = s['enabled'] as bool? ?? true;
    final id = s['id'] as String? ?? '';
    final payload = s['payload'] as Map<String, dynamic>? ?? {};
    final state = payload['state'] ?? true;
    final duration = payload['duration_sec'] as int? ?? 30;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  type == 'lights' ? Icons.lightbulb : type == 'pump' ? Icons.water_drop : Icons.air,
                  color: enabled ? theme.primaryColor : theme.disabledColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$label · Turn ${state ? "ON" : "OFF"}',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatScheduleWhen(context, cronExpr.isNotEmpty ? cronExpr : null, intervalSec),
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                      ),
                      if (type == 'pump' || type == 'ventilation')
                        Text(
                          'Duration: ${_formatDuration(duration)}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                        ),
                      if (lastRun != null)
                        Text(
                          'Last run: ${DateFormat.yMd().add_Hm().format(lastRun)}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                        ),
                      if (!enabled)
                        Text('Disabled', style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange)),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditScheduleDialog(context, deviceProvider, s),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Schedule'),
                            content: const Text('Remove this schedule?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (confirm == true && mounted) {
                          try {
                            await deviceProvider.deleteSchedule(id);
                            if (mounted) _showSnack('Schedule removed');
                          } catch (e) {
                            if (mounted) _showSnack('Failed: $e');
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddScheduleDialog(BuildContext context, DeviceProvider deviceProvider) {
    if (deviceProvider.selectedDevice == null) return;
    final device = deviceProvider.selectedDevice!;

    String? selectedType = 'lights';
    var useCron = true; // true = time-based, false = interval-based
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
    final intervalController = TextEditingController();
    var state = true;
    final durationController = TextEditingController(text: '30');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Schedule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'What to automate'),
                  items: _scheduleTypes
                      .map((m) => DropdownMenuItem(value: m['key']!, child: Text(m['label']!)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedType = v),
                ),
                const SizedBox(height: 20),
                Text('When', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('At time'), icon: Icon(Icons.schedule)),
                    ButtonSegment(value: false, label: Text('Every X'), icon: Icon(Icons.repeat)),
                  ],
                  selected: {useCron},
                  onSelectionChanged: (v) => setState(() {
                    useCron = v.first;
                    if (!useCron) intervalController.clear();
                  }),
                ),
                const SizedBox(height: 16),
                if (useCron) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SchedulePresetChip(
                        label: '8:00 AM',
                        onTap: () => setState(() => selectedTime = const TimeOfDay(hour: 8, minute: 0)),
                      ),
                      _SchedulePresetChip(
                        label: '6:00 PM',
                        onTap: () => setState(() => selectedTime = const TimeOfDay(hour: 18, minute: 0)),
                      ),
                      _SchedulePresetChip(
                        label: 'Noon',
                        onTap: () => setState(() => selectedTime = const TimeOfDay(hour: 12, minute: 0)),
                      ),
                      _SchedulePresetChip(
                        label: 'Midnight',
                        onTap: () => setState(() => selectedTime = const TimeOfDay(hour: 0, minute: 0)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Time'),
                    subtitle: Text(selectedTime.format(ctx)),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: selectedTime,
                      );
                      if (picked != null) setState(() => selectedTime = picked);
                    },
                  ),
                ] else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SchedulePresetChip(
                        label: 'Every 6 hr',
                        onTap: () => setState(() => intervalController.text = '21600'),
                      ),
                      _SchedulePresetChip(
                        label: 'Every 12 hr',
                        onTap: () => setState(() => intervalController.text = '43200'),
                      ),
                      _SchedulePresetChip(
                        label: 'Every 24 hr',
                        onTap: () => setState(() => intervalController.text = '86400'),
                      ),
                      _SchedulePresetChip(
                        label: 'Every 1 hr',
                        onTap: () => setState(() => intervalController.text = '3600'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: intervalController,
                    decoration: const InputDecoration(
                      labelText: 'Interval (seconds)',
                      hintText: 'e.g. 3600 = hourly',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 20),
                SwitchListTile(
                  title: const Text('Turn ON'),
                  subtitle: Text(state ? 'Device will turn on' : 'Device will turn off'),
                  value: state,
                  onChanged: (v) => setState(() => state = v),
                ),
                if (selectedType == 'lights' || selectedType == 'pump' || selectedType == 'ventilation')
                  TextField(
                    controller: durationController,
                    decoration: InputDecoration(
                      labelText: 'Duration (seconds)',
                      hintText: selectedType == 'lights'
                          ? 'How long to stay on (0 = indefinitely)'
                          : 'How long to run (e.g. 30)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final cron = useCron ? _timeOfDayToCron(selectedTime) : '';
                final interval = useCron ? null : int.tryParse(intervalController.text);
                if (cron.isEmpty && (interval == null || interval <= 0)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Set a time or interval')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final payload = <String, dynamic>{'state': state};
                if (selectedType == 'lights' || selectedType == 'pump' || selectedType == 'ventilation') {
                  payload['duration_sec'] = int.tryParse(durationController.text) ?? (selectedType == 'lights' ? 0 : 30);
                }
                if (selectedType == 'ventilation') payload['duty_percent'] = 80;
                try {
                  await deviceProvider.createSchedule(
                    device.id,
                    selectedType!,
                    cronExpr: cron.isNotEmpty ? cron : null,
                    intervalSeconds: interval,
                    payload: payload,
                  );
                  if (context.mounted) _showSnack('Schedule added');
                } catch (e) {
                  if (context.mounted) _showSnack('Failed: $e');
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditScheduleDialog(BuildContext context, DeviceProvider deviceProvider, Map<String, dynamic> s) {
    final cronExpr = s['cron_expr']?.toString() ?? '';
    final intervalSec = s['interval_seconds'] as int?;
    var useCron = cronExpr.isNotEmpty;
    TimeOfDay selectedTime = _cronToTimeOfDay(cronExpr);
    final intervalController = TextEditingController(text: (intervalSec ?? 0) > 0 ? intervalSec.toString() : '');
    final payload = s['payload'] as Map<String, dynamic>? ?? {};
    var state = payload['state'] as bool? ?? true;
    final scheduleType = s['schedule_type'] as String? ?? 'lights';
    final durationDefault = scheduleType == 'lights' ? '0' : '30';
    final durationController = TextEditingController(text: (payload['duration_sec'] as int?)?.toString() ?? durationDefault);
    var enabled = s['enabled'] as bool? ?? true;
    final id = s['id'] as String? ?? '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Edit Schedule (${s['schedule_type']})'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('When', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('At time'), icon: Icon(Icons.schedule)),
                    ButtonSegment(value: false, label: Text('Every X'), icon: Icon(Icons.repeat)),
                  ],
                  selected: {useCron},
                  onSelectionChanged: (v) => setState(() {
                    useCron = v.first;
                    if (!useCron) intervalController.clear();
                  }),
                ),
                const SizedBox(height: 16),
                if (useCron)
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Time'),
                    subtitle: Text(selectedTime.format(ctx)),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: selectedTime,
                      );
                      if (picked != null) setState(() => selectedTime = picked);
                    },
                  )
                else
                  TextField(
                    controller: intervalController,
                    decoration: const InputDecoration(
                      labelText: 'Interval (seconds)',
                      hintText: 'e.g. 3600 = hourly',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                const SizedBox(height: 16),
                SwitchListTile(title: const Text('Turn ON'), value: state, onChanged: (v) => setState(() => state = v)),
                TextField(
                  controller: durationController,
                  decoration: InputDecoration(
                    labelText: 'Duration (seconds)',
                    hintText: scheduleType == 'lights'
                        ? 'How long to stay on (0 = indefinitely)'
                        : 'How long to run (e.g. 30)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                SwitchListTile(title: const Text('Enabled'), value: enabled, onChanged: (v) => setState(() => enabled = v)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final cron = useCron ? _timeOfDayToCron(selectedTime) : '';
                final interval = useCron ? null : int.tryParse(intervalController.text);
                if (!useCron && (interval == null || interval <= 0)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Enter a valid interval (seconds)')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final durationDefaultVal = scheduleType == 'lights' ? 0 : 30;
                final payloadData = <String, dynamic>{
                  'state': state,
                  'duration_sec': int.tryParse(durationController.text) ?? durationDefaultVal,
                };
                try {
                  await deviceProvider.updateSchedule(
                    id,
                    cronExpr: useCron ? cron : '',
                    intervalSeconds: useCron ? 0 : interval!,
                    payload: payloadData,
                    enabled: enabled,
                  );
                  if (context.mounted) _showSnack('Schedule updated');
                } catch (e) {
                  if (context.mounted) _showSnack('Failed: $e');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  static const List<Map<String, String>> _thresholdMetrics = [
    {'key': 'temp_c', 'label': 'Temperature (°C)'},
    {'key': 'humidity', 'label': 'Air Humidity (%)'},
    {'key': 'soil_moisture', 'label': 'Soil Moisture (%)'},
    {'key': 'pressure', 'label': 'Pressure (hPa)'},
    {'key': 'gas_resistance', 'label': 'Gas / VOC (kOhm)'},
    {'key': 'water_level_low', 'label': 'Water Level Low'},
    {'key': 'fan_duty', 'label': 'Fan / Ventilation Duty (%)'},
  ];

  Widget _buildThresholdsTab(DeviceProvider deviceProvider) {
    final theme = Theme.of(context);
    final thresholds = deviceProvider.thresholds;

    return ListView(
      controller: _thresholdsScrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Thresholds define min/max ranges for alerts. The device checks every 60 seconds and sends at most one alert per metric every 15 minutes.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 16),
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plant presets',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Apply default soil/temp/humidity thresholds plus light and pump schedules suited to indoor basil.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: !SupabaseConfig.isInitialized
                      ? null
                      : () async {
                          try {
                            await deviceProvider.applyBasilPreset();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Basil defaults applied (thresholds + schedules)'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Could not apply preset: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.local_florist_outlined),
                  label: const Text('Apply basil defaults'),
                ),
              ],
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _showAddThresholdDialog(context, deviceProvider),
          icon: const Icon(Icons.add),
          label: const Text('Add Threshold'),
        ),
        const SizedBox(height: 16),
        if (thresholds.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.tune, size: 48, color: theme.disabledColor),
                  const SizedBox(height: 16),
                  Text('No thresholds configured', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Add a threshold to get alerts when values go out of range.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...thresholds.map((t) => _buildThresholdCard(theme, deviceProvider, t)),
      ],
    );
  }

  Widget _buildThresholdCard(ThemeData theme, DeviceProvider deviceProvider, Map<String, dynamic> t) {
    final metric = t['metric'] as String? ?? '';
    final label = _thresholdMetrics.firstWhere(
      (m) => m['key'] == metric,
      orElse: () => {'label': metric},
    )['label']!;
    final minVal = t['min_value'] as num?;
    final maxVal = t['max_value'] as num?;
    final enabled = t['enabled'] as bool? ?? true;
    final id = t['id'] as String? ?? '';
    final isWaterLowMetric = metric == 'water_level_low';
    final waterCutoff = ((maxVal ?? minVal) as num?)?.toDouble();
    final detailsText = isWaterLowMetric
        ? 'Alert when water frequency drops below ${waterCutoff != null ? "${waterCutoff.toStringAsFixed(0)} Hz" : "configured cutoff"} ${enabled ? "" : "(disabled)"}'
        : 'Min: ${minVal != null ? minVal.toStringAsFixed(1) : "—"}  |  Max: ${maxVal != null ? maxVal.toStringAsFixed(1) : "—"}  ${enabled ? "" : "(disabled)"}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          enabled ? Icons.tune : Icons.tune_outlined,
          color: enabled ? theme.primaryColor : theme.disabledColor,
        ),
        title: Text(label),
        subtitle: Text(detailsText),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditThresholdDialog(context, deviceProvider, t),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Threshold'),
                    content: Text('Remove threshold for $label?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  try {
                    await deviceProvider.deleteThreshold(id);
                    if (mounted) _showSnack('Threshold removed');
                  } catch (e) {
                    if (mounted) _showSnack('Failed: $e');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddThresholdDialog(BuildContext context, DeviceProvider deviceProvider) {
    if (deviceProvider.selectedDevice == null) return;
    final device = deviceProvider.selectedDevice!;

    final availableMetrics = _thresholdMetrics
        .where((m) => !deviceProvider.thresholds.any((t) => t['metric'] == m['key']))
        .toList();

    if (availableMetrics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All metrics already have thresholds — use the edit button on any card to adjust them.'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    String? selectedMetric;
    final minController = TextEditingController();
    final maxController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Threshold'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedMetric,
                  isExpanded: true,
                  menuMaxHeight: 300,
                  decoration: const InputDecoration(
                    labelText: 'Metric',
                    hintText: 'Select a metric',
                  ),
                  items: availableMetrics
                      .map((m) => DropdownMenuItem(value: m['key']!, child: Text(m['label']!)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedMetric = v),
                ),
                const SizedBox(height: 4),
                Text(
                  'Alert fires when the reading goes below Min or above Max.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).hintColor),
                ),
                if (selectedMetric != null) ...[
                  const SizedBox(height: 8),
                  if (selectedMetric == 'fan_duty')
                    Text(
                      'Fan duty is a 0–100 % actuator value. Set Min to alert when ventilation is running below a target, or Max when it is unexpectedly high.',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).hintColor),
                    )
                  else
                    TextButton.icon(
                      icon: const Icon(Icons.auto_fix_high, size: 16),
                      label: const Text('Fill from recent data'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        final (sugMin, sugMax) = deviceProvider.suggestBoundsForMetric(selectedMetric!);
                        setState(() {
                          if (sugMin != null) minController.text = sugMin.toString();
                          if (sugMax != null) maxController.text = sugMax.toString();
                        });
                        if (sugMin == null && sugMax == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('No recent data available for this metric yet')),
                          );
                        }
                      },
                    ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: minController,
                  decoration: const InputDecoration(labelText: 'Min value (optional)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: maxController,
                  decoration: const InputDecoration(labelText: 'Max value (optional)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (selectedMetric == null) return;
                final minVal = double.tryParse(minController.text);
                final maxVal = double.tryParse(maxController.text);
                if (minVal == null && maxVal == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Enter at least min or max')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await deviceProvider.createThreshold(
                    device.id,
                    selectedMetric!,
                    minVal,
                    maxVal,
                  );
                  if (context.mounted) _showSnack('Threshold added');
                } catch (e) {
                  if (context.mounted) _showSnack('Failed: $e');
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditThresholdDialog(BuildContext context, DeviceProvider deviceProvider, Map<String, dynamic> t) {
    final minController = TextEditingController(text: (t['min_value'] as num?)?.toString());
    final maxController = TextEditingController(text: (t['max_value'] as num?)?.toString());
    var enabled = t['enabled'] as bool? ?? true;
    final id = t['id'] as String? ?? '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit Threshold'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _thresholdMetrics.firstWhere(
                    (m) => m['key'] == t['metric'],
                    orElse: () => {'label': t['metric'] as String? ?? ''},
                  )['label']!,
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: minController,
                  decoration: const InputDecoration(labelText: 'Min value'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: maxController,
                  decoration: const InputDecoration(labelText: 'Max value'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Enabled'),
                  value: enabled,
                  onChanged: (v) => setState(() => enabled = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await deviceProvider.updateThreshold(
                    id,
                    minValue: double.tryParse(minController.text),
                    maxValue: double.tryParse(maxController.text),
                    enabled: enabled,
                  );
                  if (context.mounted) _showSnack('Threshold updated');
                } catch (e) {
                  if (context.mounted) _showSnack('Failed: $e');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

class _SchedulePresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SchedulePresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}
