import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:phytopi_dashboard/shared/controllers/smooth_scroll_controller.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/device_provider.dart';
import 'charts_screen.dart';
import 'alerts_screen.dart';
import 'devices_screen.dart';
import 'ai_health_screen.dart';
import '../../settings/screens/profile_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../widgets/dashboard_gauge.dart';
import '../widgets/dashboard_chart.dart';
import '../widgets/water_level_gauge.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _autoRefreshTimer;
  int _mobileSelectedIndex = 0;
  int _webSelectedIndex = 0;
  int _kioskSelectedIndex = 0;
  late final ScrollController _mobileScrollController = SmoothScrollController(
    pointerScrollDuration: const Duration(milliseconds: 260),
    pointerScrollCurve: Curves.easeOutCubic,
    pointerScrollMultiplier: 0.34,
  );
  late final ScrollController _webScrollController = SmoothScrollController(
    pointerScrollDuration: const Duration(milliseconds: 260),
    pointerScrollCurve: Curves.easeOutCubic,
    pointerScrollMultiplier: 0.34,
  );

  // Theme colors - using Theme.of(context) primarily, but keeping accents for charts/gauges
  static const Color _accentColor = Color(0xFF2E7D32); // Green from AppTheme

  @override
  void initState() {
    super.initState();
    // Always auto-refresh to keep relative time displays ("X min ago") updated
    _setupAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _mobileScrollController.dispose();
    _webScrollController.dispose();
    super.dispose();
  }

  void _setupAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(
      Duration(seconds: AppConfig.autoRefreshInterval),
      (timer) {
        if (mounted) {
          setState(() {
            // Trigger rebuild to refresh data
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      // Platform-specific rendering
      if (PlatformDetector.isKiosk) {
        return _buildKioskLayout(context); // Keep existing Kiosk layout for now
      } else if (PlatformDetector.isMobile) {
        return _buildMobileLayout(context);
      } else {
        return _buildWebLayout(context);
      }
    } catch (e, stack) {
      debugPrint('DashboardScreen: Error in build - $e');
      debugPrint('Stack: $stack');
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error building dashboard: $e'),
            ],
          ),
        ),
      );
    }
  }

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Home'),
    _NavItem(icon: Icons.devices_outlined, activeIcon: Icons.devices, label: 'Devices'),
    _NavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: 'Charts'),
    _NavItem(icon: Icons.notifications_outlined, activeIcon: Icons.notifications, label: 'Alerts'),
    _NavItem(icon: Icons.health_and_safety_outlined, activeIcon: Icons.health_and_safety, label: 'AI Health'),
    _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
  ];

  void _showNavMenu(BuildContext context, int currentIndex, void Function(int) onSelect) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _navItems.length,
                itemBuilder: (ctx, i) {
                  final item = _navItems[i];
                  final selected = i == currentIndex;
                  return InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      onSelect(i);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: selected
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            selected ? item.activeIcon : item.icon,
                            color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            size: 26,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  if (authProvider.user == null) return const SizedBox.shrink();
                  return ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Sign out', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(ctx);
                      authProvider.signOut();
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKioskLayout(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNavMenu(
          context,
          _kioskSelectedIndex,
          (i) => setState(() => _kioskSelectedIndex = i),
        ),
        tooltip: 'Navigation',
        child: const Icon(Icons.menu_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: [
          Material(
            color: theme.colorScheme.surface,
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.eco, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Consumer<DeviceProvider>(
                      builder: (context, dp, _) {
                        final n = dp.selectedDevice?.name;
                        return Text(
                          (n != null && n.isNotEmpty) ? n : 'PhytoPi',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                  Text(
                    _navItems[_kioskSelectedIndex].label,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _kioskSelectedIndex,
              children: [
                _buildDashboardContent(context),
                const DevicesScreen(),
                const ChartsScreen(),
                const AlertsScreen(),
                const AiHealthScreen(),
                const ProfileScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }


  /// Mobile-specific layout
  Widget _buildMobileLayout(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Consumer<DeviceProvider>(
          builder: (context, dp, _) {
            final n = dp.selectedDevice?.name;
            return Text(
              (n != null && n.isNotEmpty) ? n : 'PhytoPi',
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => setState(() => _mobileSelectedIndex = 5),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNavMenu(
          context,
          _mobileSelectedIndex,
          (i) => setState(() => _mobileSelectedIndex = i),
        ),
        tooltip: 'Navigation',
        child: const Icon(Icons.menu_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: IndexedStack(
        index: _mobileSelectedIndex,
        children: [
          _buildDashboardContent(context),
          const DevicesScreen(),
          const ChartsScreen(),
          const AlertsScreen(),
          const AiHealthScreen(),
          const ProfileScreen(),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.eco, color: Colors.white, size: 48),
                SizedBox(height: 16),
                Text(
                  'PhytoPi Menu',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
           ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          const Divider(),
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  authProvider.signOut();
                },
              );
            },
          ),
        ],
      ),
    );
  }

  /// Web-specific layout
  Widget _buildWebLayout(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Consumer<DeviceProvider>(
          builder: (context, dp, _) {
            final n = dp.selectedDevice?.name;
            final label = (n != null && n.isNotEmpty) ? n : 'PhytoPi Dashboard';
            return Row(
              children: [
                const Icon(Icons.eco),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          // Claim Device moved to Devices tab
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _webSelectedIndex,
            onDestinationSelected: (index) => setState(() => _webSelectedIndex = index),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.devices_outlined),
                selectedIcon: Icon(Icons.devices),
                label: Text('Devices'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: Text('Charts'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.notifications_outlined),
                selectedIcon: Icon(Icons.notifications),
                label: Text('Alerts & Cmd'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.health_and_safety_outlined),
                selectedIcon: Icon(Icons.health_and_safety),
                label: Text('AI Health'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: Text('Profile'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(
              index: _webSelectedIndex,
              children: [
                _buildDashboardContent(context),
                const DevicesScreen(),
                const ChartsScreen(),
                const AlertsScreen(),
                const AiHealthScreen(),
                const ProfileScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceStatus(BuildContext context, ThemeData theme, DeviceProvider dp) {
    final state = dp.actuatorState;
    final device = dp.selectedDevice;

    String _sinceText(String? isoKey) {
      if (isoKey == null) return '';
      final ts = DateTime.tryParse(isoKey);
      if (ts == null) return '';
      final diff = DateTime.now().toUtc().difference(ts.toUtc());
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    }

    Widget _chip({
      required IconData icon,
      required String label,
      String? subtitle,
      required bool active,
      required bool ok,
    }) {
      final Color chipColor = !ok
          ? Colors.red
          : active
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant.withOpacity(0.5);
      final Color bgColor = !ok
          ? Colors.red.withOpacity(0.1)
          : active
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerLow;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: chipColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: chipColor),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: theme.textTheme.labelMedium?.copyWith(
                        color: chipColor, fontWeight: FontWeight.w600)),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: chipColor.withOpacity(0.8), fontSize: 10)),
              ],
            ),
          ],
        ),
      );
    }

    final bool lightsOn   = state?['lights_on'] as bool? ?? false;
    final bool pumpOn     = state?['pump_on']    as bool? ?? false;
    final int  fanDuty    = (state?['fan_duty']  as num?)?.toInt() ?? 0;
    final bool bmeOk      = state?['bme_ok']     as bool? ?? true;
    final bool soilOk     = state?['soil_ok']    as bool? ?? true;
    final String lightsTs = _sinceText(state?['lights_changed_at'] as String?);
    final String pumpTs   = _sinceText(state?['pump_changed_at']   as String?);
    final String fanTs    = _sinceText(state?['fan_changed_at']    as String?);
    final bool online     = device?.isOnline ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Device Status', style: theme.textTheme.titleLarge),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: online ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8,
                      color: online ? Colors.green : Colors.red),
                  const SizedBox(width: 4),
                  Text(online ? 'Online' : 'Offline',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: online ? Colors.green[700] : Colors.red[700])),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(
              icon: lightsOn ? Icons.lightbulb : Icons.lightbulb_outline,
              label: lightsOn ? 'Lights ON' : 'Lights OFF',
              subtitle: lightsTs,
              active: lightsOn,
              ok: true,
            ),
            _chip(
              icon: pumpOn ? Icons.water : Icons.water_drop_outlined,
              label: pumpOn ? 'Pump ON' : 'Pump OFF',
              subtitle: pumpTs,
              active: pumpOn,
              ok: true,
            ),
            _chip(
              icon: fanDuty > 0 ? Icons.air : Icons.air_outlined,
              label: fanDuty > 0 ? 'Fans $fanDuty%' : 'Fans OFF',
              subtitle: fanTs,
              active: fanDuty > 0,
              ok: true,
            ),
            _chip(
              icon: bmeOk ? Icons.sensors : Icons.sensors_off,
              label: bmeOk ? 'BME680 OK' : 'BME680 Error',
              subtitle: '',
              active: bmeOk,
              ok: bmeOk,
            ),
            _chip(
              icon: soilOk ? Icons.grass : Icons.grass_outlined,
              label: soilOk ? 'Soil Sensor OK' : 'Soil Sensor Error',
              subtitle: '',
              active: soilOk,
              ok: soilOk,
            ),
            _chip(
              icon: Icons.videocam_outlined,
              label: 'Live Camera',
              subtitle: 'AI Health tab',
              active: true,
              ok: true,
            ),
          ],
        ),
        if (state == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Status will appear once the device syncs (requires migration + firmware update).',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ),
      ],
    );
  }

  Widget _buildDashboardContent(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, child) {
        final selectedDevice = deviceProvider.selectedDevice;
        final hasReadings = deviceProvider.hasReadings;
        final latestReadings = deviceProvider.latestReadings;
        final historicalReadings = deviceProvider.historicalReadings;
        final lastUpdate = deviceProvider.lastUpdate;

        final tempPoints = historicalReadings['temp_c'] ?? [];
        final humidityPoints = historicalReadings['humidity'] ?? [];
        final soilPoints = historicalReadings['soil_moisture'] ?? [];
        final waterPoints = historicalReadings['water_level_frequency'] ?? historicalReadings['water_level'] ?? [];

        return SingleChildScrollView(
          controller: _webScrollController, // Shared controller for simplicity
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              if (selectedDevice == null)
                Container(
                  margin: const EdgeInsets.only(bottom: 32),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    border: Border.all(color: Colors.amber),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.amber),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No Device Selected',
                              style: theme.textTheme.titleMedium?.copyWith(color: Colors.amber[900]),
                            ),
                            const Text('Please select a device from the Devices tab to view readings.'),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          if (PlatformDetector.isWeb) {
                             setState(() => _webSelectedIndex = 1); // Switch to Devices tab
                          } else {
                             setState(() => _mobileSelectedIndex = 1);
                          }
                        },
                        child: const Text('Select Device'),
                      ),
                    ],
                  ),
                ),
              
              if (selectedDevice != null) ...[
                if (deviceProvider.hasWaterLevelLowAlert)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.water_drop, color: Colors.red, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Water Level Low',
                                style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.red[900], fontWeight: FontWeight.bold),
                              ),
                              const Text('Refill the reservoir. See Alerts & Commands for details.'),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (PlatformDetector.isWeb) _webSelectedIndex = 3;
                              else _mobileSelectedIndex = 3;
                            });
                          },
                          child: const Text('View Alerts'),
                        ),
                      ],
                    ),
                  ),
                // GAUGES ROW
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Live Readings', style: theme.textTheme.titleLarge),
                    if (lastUpdate != null)
                      Text(
                        'Updated ${DateTime.now().difference(lastUpdate.toLocal()).inMinutes} min ago (${DateFormat('HH:mm:ss').format(lastUpdate.toLocal())})',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Adaptive grid for gauges
                    final width = constraints.maxWidth;
                    final count = width > 800 ? 3 : (width > 500 ? 2 : 1);
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: (width - (16 * (count - 1))) / count,
                          height: 250,
                          child: DashboardGauge(
                            title: 'Temperature',
                            value: latestReadings['temp_c'] ?? 0,
                            min: 0,
                            max: 50,
                            unit: '°C',
                            color: Colors.orange,
                          ),
                        ),
                        SizedBox(
                          width: (width - (16 * (count - 1))) / count,
                          height: 250,
                          child: DashboardGauge(
                            title: 'Humidity',
                            value: latestReadings['humidity'] ?? 0,
                            min: 0,
                            max: 100,
                            unit: '%',
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(
                          width: (width - (16 * (count - 1))) / count,
                          height: 250,
                          child: DashboardGauge(
                            title: 'Soil Moisture',
                            value: latestReadings['soil_moisture'] ?? 0,
                            min: 0,
                            max: 100,
                            unit: '%',
                            color: Colors.green,
                          ),
                        ),
                        SizedBox(
                          width: (width - (16 * (count - 1))) / count,
                          height: 250,
                          child: WaterLevelGauge(
                            title: 'Water Level',
                            value: latestReadings['water_level_frequency'] ?? latestReadings['water_level'] ?? 0,
                          ),
                        ),
                        SizedBox(
                          width: (width - (16 * (count - 1))) / count,
                          height: 250,
                          child: DashboardGauge(
                            title: 'Pressure',
                            value: latestReadings['pressure'] ?? 0,
                            min: 900,
                            max: 1100,
                            unit: 'hPa',
                            color: Colors.purple,
                          ),
                        ),
                        SizedBox(
                          width: (width - (16 * (count - 1))) / count,
                          height: 250,
                          child: DashboardGauge.gasVoc(
                            value: latestReadings['gas_resistance'] ?? 0,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 40),

                // CHARTS ROW
                Text('History', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                Stack(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 700;
                        Widget tempChart = SizedBox(
                          height: 280,
                          child: DashboardChart(
                            title: 'Temperature Trend',
                            dataPoints: tempPoints,
                            minY: 10,
                            maxY: 40,
                            unit: '°C',
                            color: Colors.orange,
                          ),
                        );
                        Widget humidityChart = SizedBox(
                          height: 280,
                          child: DashboardChart(
                            title: 'Air Humidity Trend',
                            dataPoints: humidityPoints,
                            minY: 20,
                            maxY: 100,
                            unit: '%',
                            color: Colors.blue,
                          ),
                        );
                        return Column(
                          children: [
                            if (wide)
                              SizedBox(
                                height: 280,
                                child: Row(
                                  children: [
                                    Expanded(child: tempChart),
                                    const SizedBox(width: 16),
                                    Expanded(child: humidityChart),
                                  ],
                                ),
                              )
                            else ...[
                              tempChart,
                              const SizedBox(height: 16),
                              humidityChart,
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 280,
                              child: DashboardChart(
                                title: 'Soil Moisture Trend',
                                dataPoints: soilPoints,
                                minY: 0,
                                maxY: 100,
                                unit: '%',
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 280,
                              child: DashboardChart(
                                title: 'Water Level Trend',
                                dataPoints: waterPoints,
                                minY: 0,
                                maxY: (historicalReadings['water_level_frequency']?.isNotEmpty ?? false) ? 4 : 100,
                                unit: (historicalReadings['water_level_frequency']?.isNotEmpty ?? false) ? 'level' : '%',
                                color: Colors.cyan,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    if (!hasReadings)
                      Positioned.fill(
                        child: Container(
                          color: theme.scaffoldBackgroundColor.withOpacity(0.8),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.sensors_off, size: 48, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  'No Readings Available',
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                const Text('Waiting for data from device...'),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 32),
                // DEVICE STATUS SECTION
                _buildDeviceStatus(context, theme, deviceProvider),
              ],
            ],
          ),
        );
      }
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}
