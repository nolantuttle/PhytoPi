import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../widgets/chart_axis_utils.dart';
import '../widgets/dashboard_chart.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  String _selectedTimeFrame = 'All'; // Default to show all available data

  // Time frame options mapping to duration in minutes
  final Map<String, int> _timeFrames = {
    '1h': 60,
    '6h': 360,
    '12h': 720,
    '24h': 1440,
    '7d': 10080,
    'All': 0, // Special case for all available data
  };

  List<FlSpot> _filterDataByTimeFrame(List<FlSpot> data) {
    if (data.isEmpty) return [];
    if (_selectedTimeFrame == 'All') return data;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final durationMinutes = _timeFrames[_selectedTimeFrame] ?? 60;
    final cutoff = now - (durationMinutes * 60 * 1000);
    
    return data.where((spot) => spot.x >= cutoff).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, child) {
        final selectedDevice = deviceProvider.selectedDevice;
        final historicalReadings = deviceProvider.historicalReadings;

        final tempPoints = _filterDataByTimeFrame(historicalReadings['temp_c'] ?? []);
        final humidityPoints = _filterDataByTimeFrame(historicalReadings['humidity'] ?? []);
        final soilPoints = _filterDataByTimeFrame(historicalReadings['soil_moisture'] ?? []);
        final waterPoints = _filterDataByTimeFrame(historicalReadings['water_level_frequency'] ?? historicalReadings['water_level'] ?? []);
        final pressurePoints = _filterDataByTimeFrame(historicalReadings['pressure'] ?? []);
        final gasPoints = _filterDataByTimeFrame(historicalReadings['gas_resistance'] ?? []);
        final gasY = gasResistanceAxisBounds(gasPoints);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Title and Time Frame Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Charts',
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTimeFrame,
                          items: _timeFrames.keys.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value == 'All' ? 'All Available' :
                                value == '1h' ? 'Last Hour' :
                                value == '6h' ? 'Last 6 Hours' :
                                value == '12h' ? 'Last 12 Hours' :
                                value == '24h' ? 'Last 24 Hours' :
                                'Last 7 Days'
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedTimeFrame = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                if (selectedDevice == null)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withOpacity(0.5)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.device_unknown, size: 48, color: Colors.amber),
                          const SizedBox(height: 16),
                          Text(
                            'No Device Selected',
                            style: theme.textTheme.titleLarge?.copyWith(color: Colors.amber[900]),
                          ),
                          const SizedBox(height: 8),
                          const Text('Please select a device to view charts.'),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // Temperature Chart
                  _buildChartContainer(
                    context,
                    DashboardChart(
                      title: 'Temperature',
                      dataPoints: tempPoints,
                      minY: 10,
                      maxY: 40,
                      unit: '°C',
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Humidity Chart
                  _buildChartContainer(
                    context,
                    DashboardChart(
                      title: 'Humidity',
                      dataPoints: humidityPoints,
                      minY: 20,
                      maxY: 100,
                      unit: '%',
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Soil Moisture Chart
                  _buildChartContainer(
                    context,
                    DashboardChart(
                      title: 'Soil Moisture',
                      dataPoints: soilPoints,
                      minY: 0,
                      maxY: 100,
                      unit: '%',
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Water Level Chart (5-state or legacy %)
                  _buildChartContainer(
                    context,
                    DashboardChart(
                      title: 'Water Level',
                      dataPoints: waterPoints,
                      minY: 0,
                      maxY: (historicalReadings['water_level_frequency']?.isNotEmpty ?? false) ? 4 : 100,
                      unit: (historicalReadings['water_level_frequency']?.isNotEmpty ?? false) ? 'level' : '%',
                      color: Colors.cyan,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Pressure Chart
                  _buildChartContainer(
                    context,
                    DashboardChart(
                      title: 'Pressure',
                      dataPoints: pressurePoints,
                      minY: 900,
                      maxY: 1100,
                      unit: 'hPa',
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Gas / VOC Chart
                  _buildChartContainer(
                    context,
                    DashboardChart(
                      title: 'Gas / VOC (kΩ — higher often means cleaner air)',
                      dataPoints: gasPoints,
                      minY: gasY.minY,
                      maxY: gasY.maxY,
                      unit: 'kOhm',
                      color: Colors.teal,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChartContainer(BuildContext context, Widget chart) {
    return SizedBox(
      height: 300,
      width: double.infinity,
      child: chart,
    );
  }
}
