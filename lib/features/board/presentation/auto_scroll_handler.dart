import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Drives per-frame auto-scrolling on both axes when the pointer enters
/// edge zones during a drag operation.
///
/// Edge zone width and maximum scroll speed scale with viewport dimensions
/// so that drag-to-scroll feels proportional on both phones and desktops.
/// Speed scales linearly from [minSpeed] at the zone boundary to the
/// viewport-derived max speed at the viewport edge. Corner positions scroll
/// both axes simultaneously.
class AutoScrollHandler {
  AutoScrollHandler({
    required this.horizontalController,
    required this.verticalController,
    required TickerProvider vsync,
    this.minSpeed = 50.0,
    double? maxSpeed,
  }) : _maxSpeedOverride = maxSpeed {
    // Single ticker for the handler's lifetime. Started/stopped per drag;
    // disposed once in dispose().
    _ticker = vsync.createTicker(_onTick);
  }

  final ScrollController horizontalController;
  final ScrollController verticalController;

  /// Scroll speed (px/s) when the pointer just enters the edge zone.
  final double minSpeed;

  /// [RenderBox] used by drag handlers to convert global pointer coordinates
  /// to viewport-local. Set by the scroll view's [LayoutBuilder] each frame.
  RenderBox? viewportRenderBox;

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

  /// Optional fixed max speed — when null, max speed scales with viewport
  /// (50% of longest axis, clamped 600–900 px/s).
  final double? _maxSpeedOverride;

  late final Ticker _ticker;
  Offset? _pointerPosition;
  Size? _viewportSize;
  Duration? _lastTick;
  bool _disposed = false;

  /// Max scroll speed — scales with viewport so larger screens scroll faster.
  double get _effectiveMaxSpeed {
    if (_maxSpeedOverride != null) return _maxSpeedOverride;
    final viewport = _viewportSize;
    if (viewport == null) return 600;
    return (math.max(viewport.width, viewport.height) * 0.5)
        .clamp(600, 900);
  }

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

  /// Edge zone for a given axis: 5% of axis length, clamped 30–60px.
  double _edgeZoneForAxis(double axisLength) {
    return (axisLength * 0.05).clamp(30, 60);
  }

  /// Returns a signed speed value: negative for scrolling toward the start
  /// (pointer near left/top edge), positive for scrolling toward the end
  /// (pointer near right/bottom edge), zero if outside both edge zones.
  double _speedForAxis(double pointerPos, double axisLength) {
    final zone = _edgeZoneForAxis(axisLength);
    if (pointerPos < zone) {
      // Near the start edge — scroll backward.
      final depth = zone - pointerPos;
      return -_interpolateSpeed(depth, zone);
    } else if (pointerPos > axisLength - zone) {
      // Near the end edge — scroll forward.
      final depth = pointerPos - (axisLength - zone);
      return _interpolateSpeed(depth, zone);
    }
    return 0;
  }

  /// Linear interpolation: 0 depth -> minSpeed, full zone depth -> max speed.
  double _interpolateSpeed(double depth, double zone) {
    final t = (depth / zone).clamp(0.0, 1.0);
    return minSpeed + (_effectiveMaxSpeed - minSpeed) * t;
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
