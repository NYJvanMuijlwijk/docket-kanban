import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Drives per-frame auto-scrolling on both axes when the pointer enters
/// edge zones during a drag operation.
///
/// Speed scales linearly from [minSpeed] at the zone boundary to [maxSpeed]
/// at the viewport edge. Corner positions scroll both axes simultaneously.
class AutoScrollHandler {
  AutoScrollHandler({
    required this.horizontalController,
    required this.verticalController,
    required TickerProvider vsync,
    this.edgeZone = 40.0,
    this.minSpeed = 50.0,
    this.maxSpeed = 600.0,
  }) {
    // Single ticker for the handler's lifetime. Started/stopped per drag;
    // disposed once in dispose().
    _ticker = vsync.createTicker(_onTick);
  }

  final ScrollController horizontalController;
  final ScrollController verticalController;

  /// Width of the edge zone in logical pixels from each viewport edge.
  final double edgeZone;

  /// Scroll speed (px/s) when the pointer just enters the edge zone.
  final double minSpeed;

  /// Scroll speed (px/s) when the pointer is at the very edge of the viewport.
  final double maxSpeed;

  /// Current viewport size used for edge zone calculations.
  Size? get viewportSize => _viewportSize;

  /// Current pointer position in viewport-local coordinates.
  Offset? get pointerPosition => _pointerPosition;
  set viewportSize(Size size) {
    _viewportSize = size;
  }
  set pointerPosition(Offset localPosition) {
    _pointerPosition = localPosition;
  }

  late final Ticker _ticker;
  Offset? _pointerPosition;
  Size? _viewportSize;
  Duration? _lastTick;
  bool _disposed = false;

  /// Begin monitoring the pointer for auto-scroll. Called when drag starts.
  void startAutoScroll() {
    if (_disposed) return;
    _lastTick = null;
    unawaited(_ticker.start());
  }

  /// Stop auto-scrolling. Called when drag ends or is cancelled.
  void stopAutoScroll() {
    _ticker.stop();
    _pointerPosition = null;
    _lastTick = null;
  }

  void dispose() {
    _disposed = true;
    _ticker.dispose();
  }

  void _onTick(Duration elapsed) {
    final pointer = _pointerPosition;
    final viewport = _viewportSize;
    if (pointer == null || viewport == null) {
      _lastTick = elapsed;
      return;
    }

    final lastTick = _lastTick;
    _lastTick = elapsed;
    if (lastTick == null) return;

    final dt =
        (elapsed - lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    if (dt <= 0) return;

    final hSpeed = _speedForAxis(pointer.dx, viewport.width);
    final vSpeed = _speedForAxis(pointer.dy, viewport.height);

    _applyScroll(horizontalController, hSpeed * dt);
    _applyScroll(verticalController, vSpeed * dt);
  }

  /// Returns a signed speed value: negative for scrolling toward the start
  /// (pointer near left/top edge), positive for scrolling toward the end
  /// (pointer near right/bottom edge), zero if outside both edge zones.
  double _speedForAxis(double pointerPos, double axisLength) {
    if (pointerPos < edgeZone) {
      // Near the start edge — scroll backward.
      final depth = edgeZone - pointerPos;
      return -_interpolateSpeed(depth);
    } else if (pointerPos > axisLength - edgeZone) {
      // Near the end edge — scroll forward.
      final depth = pointerPos - (axisLength - edgeZone);
      return _interpolateSpeed(depth);
    }
    return 0;
  }

  /// Linear interpolation: 0 depth → minSpeed, edgeZone depth → maxSpeed.
  double _interpolateSpeed(double depth) {
    final t = (depth / edgeZone).clamp(0.0, 1.0);
    return minSpeed + (maxSpeed - minSpeed) * t;
  }

  void _applyScroll(ScrollController controller, double delta) {
    if (delta == 0 || !controller.hasClients) return;
    final position = controller.position;
    final newOffset = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    controller.jumpTo(newOffset);
  }
}
