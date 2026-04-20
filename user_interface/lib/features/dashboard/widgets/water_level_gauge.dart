import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

/// 5-state water level gauge: Empty (0), Low (1), Mid (2), High (3), Full (4).
/// Uses photoelectric frequency mapping. Optional [showRawHz] for debug.
class WaterLevelGauge extends StatelessWidget {
  final String title;
  final double value; // 0-4 state, 0-100%, or raw Hz (photoelectric)
  final bool showRawHz;
  final double? rawHz;

  static const List<String> _labels = ['Empty', 'Low', 'Mid', 'High', 'Full'];

  const WaterLevelGauge({
    super.key,
    required this.title,
    required this.value,
    this.showRawHz = false,
    this.rawHz,
  });

  /// Converts value to 0-4 state. Handles: 0-4 (state), 0-100 (%), or raw Hz (photoelectric).
  /// Hz bands: <35=Empty, 35-83=Low, 67-158=Mid, 142-308=High, >292=Full.
  int get _state {
    if (value >= 0 && value <= 4) return value.round().clamp(0, 4);
    if (value > 4 && value <= 100) return (value / 25).round().clamp(0, 4);
    // Raw Hz from photoelectric sensor: convert to 0-4
    if (value > 100) return _hzToState(value.round());
    return 0;
  }

  static int _hzToState(int hz) {
    if (hz < 35) return 0;
    if (hz < 83) return 1;
    if (hz < 158) return 2;
    if (hz < 308) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = _state;
    final label = _labels[state];
    final color = _colorForState(state);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SfRadialGauge(
              axes: <RadialAxis>[
                RadialAxis(
                  minimum: 0,
                  maximum: 4,
                  showLabels: false,
                  showTicks: false,
                  axisLineStyle: AxisLineStyle(
                    thickness: 0.2,
                    cornerStyle: CornerStyle.bothCurve,
                    color: theme.dividerColor.withOpacity(0.1),
                    thicknessUnit: GaugeSizeUnit.factor,
                  ),
                  pointers: <GaugePointer>[
                    RangePointer(
                      value: state.toDouble(),
                      cornerStyle: CornerStyle.bothCurve,
                      width: 0.2,
                      sizeUnit: GaugeSizeUnit.factor,
                      color: color,
                      enableAnimation: true,
                      animationDuration: 500,
                    ),
                  ],
                  annotations: <GaugeAnnotation>[
                    GaugeAnnotation(
                      positionFactor: 0.1,
                      angle: 90,
                      widget: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          if (showRawHz && rawHz != null)
                            Text(
                              '${rawHz!.toStringAsFixed(0)} Hz',
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForState(int state) {
    switch (state) {
      case 0: return Colors.red;
      case 1: return Colors.orange;
      case 2: return Colors.amber;
      case 3: return Colors.lightGreen;
      case 4: return Colors.green;
      default: return Colors.cyan;
    }
  }
}
