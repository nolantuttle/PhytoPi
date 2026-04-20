import 'dart:async';
import 'dart:ui' show clampDouble;

import 'package:flutter/animation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// ScrollController that animates pointer wheel deltas instead of jumping instantly.
class SmoothScrollController extends ScrollController {
  SmoothScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    this.pointerScrollDuration = const Duration(milliseconds: 360),
    this.pointerScrollCurve = Curves.easeOutCubic,
    this.pointerScrollMultiplier = 1.0,
  });

  /// Base duration for animating each pointer scroll delta.
  final Duration pointerScrollDuration;

  /// Animation curve applied to pointer scroll motion.
  final Curve pointerScrollCurve;

  /// Multiplier applied to the incoming pointer scroll delta.
  final double pointerScrollMultiplier;

  @override
  SmoothScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return SmoothScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      pointerScrollDuration: pointerScrollDuration,
      pointerScrollCurve: pointerScrollCurve,
      pointerScrollMultiplier: pointerScrollMultiplier,
    );
  }
}

class SmoothScrollPosition extends ScrollPositionWithSingleContext {
  SmoothScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.pointerScrollDuration,
    required this.pointerScrollCurve,
    required this.pointerScrollMultiplier,
  });

  final Duration pointerScrollDuration;
  final Curve pointerScrollCurve;
  final double pointerScrollMultiplier;
  Future<void>? _activePointerAnimation;

  @override
  void applyClampedPointerSignal(PointerScrollEvent pointerSignal) {
    final double scaledDelta =
        pointerSignal.scrollDelta.dy * pointerScrollMultiplier;
    if (scaledDelta == 0.0) return;

    final double adjustedDelta =
        physics.applyPhysicsToUserOffset(this, scaledDelta);
    if (adjustedDelta == 0.0) return;

    final double target = clampDouble(
      pixels + adjustedDelta,
      minScrollExtent,
      maxScrollExtent,
    );
    if (target == pixels) return;

    final Duration duration = _durationForDelta(target - pixels);
    goIdle();
    final Future<void> animation = animateTo(
      target,
      duration: duration,
      curve: pointerScrollCurve,
    );
    _activePointerAnimation = animation;
    animation.whenComplete(() {
      if (identical(_activePointerAnimation, animation)) {
        _activePointerAnimation = null;
      }
    });
  }

  Duration _durationForDelta(double delta) {
    final double magnitude = delta.abs();
    final int baseMs = pointerScrollDuration.inMilliseconds;
    final double multiplier = (magnitude / 200).clamp(0.4, 1.5);
    return Duration(milliseconds: (baseMs * multiplier).round());
  }
}

