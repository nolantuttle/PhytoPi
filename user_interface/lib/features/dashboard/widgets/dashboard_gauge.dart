import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class DashboardGauge extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final String unit;
  final Color? color;
  /// Optional note under the title (e.g. BME680 gas interpretation).
  final String? subtitle;
  /// Optional background bands on the radial axis (same value space as [min]/[max]).
  final List<GaugeRange>? axisRanges;

  const DashboardGauge({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    this.color,
    this.subtitle,
    this.axisRanges,
  });

  /// BME680 gas resistance: dynamic axis so the needle stays on-scale; qualitative bands by kΩ tier.
  factory DashboardGauge.gasVoc({
    Key? key,
    required double value,
  }) {
    final maxAxis = math
        .max(100.0, math.max(value * 1.15, 500.0))
        .clamp(100.0, 500000.0);
    final third = maxAxis / 3;
    final ranges = <GaugeRange>[
      GaugeRange(
        startValue: 0,
        endValue: third,
        sizeUnit: GaugeSizeUnit.factor,
        startWidth: 0.2,
        endWidth: 0.2,
        color: Colors.orange.withOpacity(0.22),
      ),
      GaugeRange(
        startValue: third,
        endValue: third * 2,
        sizeUnit: GaugeSizeUnit.factor,
        startWidth: 0.2,
        endWidth: 0.2,
        color: Colors.amber.withOpacity(0.18),
      ),
      GaugeRange(
        startValue: third * 2,
        endValue: maxAxis,
        sizeUnit: GaugeSizeUnit.factor,
        startWidth: 0.2,
        endWidth: 0.2,
        color: Colors.green.withOpacity(0.2),
      ),
    ];
    return DashboardGauge(
      key: key,
      title: 'Gas / VOC',
      value: value,
      min: 0,
      max: maxAxis,
      unit: 'kOhm',
      color: Colors.teal,
      subtitle:
          'Higher kΩ → generally cleaner air (indicator)',
      axisRanges: ranges,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gaugeColor = color ?? theme.primaryColor;
    final clamped = value.clamp(min, max);

    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [theme.cardColor, theme.cardColor.withOpacity(0.85)]
              : [Colors.white, theme.colorScheme.surfaceContainerLow],
        ),
        boxShadow: [
          BoxShadow(
            color: gaugeColor.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: gaugeColor.withOpacity(0.14),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.75),
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: SfRadialGauge(
              axes: <RadialAxis>[
                RadialAxis(
                  minimum: min,
                  maximum: max,
                  showLabels: false,
                  showTicks: false,
                  ranges: axisRanges ?? <GaugeRange>[],
                  axisLineStyle: AxisLineStyle(
                    thickness: 0.2,
                    cornerStyle: CornerStyle.bothCurve,
                    color: theme.dividerColor.withOpacity(0.1),
                    thicknessUnit: GaugeSizeUnit.factor,
                  ),
                  pointers: <GaugePointer>[
                    RangePointer(
                      value: clamped,
                      cornerStyle: CornerStyle.bothCurve,
                      width: 0.2,
                      sizeUnit: GaugeSizeUnit.factor,
                      color: gaugeColor,
                      enableAnimation: true,
                      animationDuration: 1000,
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
                            clamped.toStringAsFixed(1),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: gaugeColor,
                            ),
                          ),
                          Text(
                            unit,
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
}
