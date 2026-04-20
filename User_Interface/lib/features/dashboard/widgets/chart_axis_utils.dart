import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';

/// Y-axis bounds derived from data (padding keeps lines inside the chart area).
({double minY, double maxY}) gasResistanceAxisBounds(List<FlSpot> points) {
  if (points.isEmpty) {
    return (minY: 0.0, maxY: 500.0);
  }
  var yMin = points.map((e) => e.y).reduce(math.min);
  var yMax = points.map((e) => e.y).reduce(math.max);
  if (yMax <= yMin) {
    yMax = yMin + 1.0;
  }
  final span = yMax - yMin;
  var minY = math.max(0.0, yMin - span * 0.08);
  var maxY = yMax + span * 0.12;
  maxY = math.max(maxY, minY + 50.0);
  return (minY: minY, maxY: maxY);
}
