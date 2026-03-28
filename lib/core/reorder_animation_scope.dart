import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Drives FLIP-style (First, Last, Invert, Play) positional animations
/// for children that change order within a layout.
///
/// Usage:
/// 1. Wrap the parent layout (e.g., Column) with [ReorderAnimationScope].
/// 2. Wrap each reorderable child with [ReorderAnimationItem].
/// 3. Before triggering the setState that changes order,
///    call [ReorderAnimationScopeState.snapshotPositions]
///    to capture current offsets.
/// 4. After the rebuild, the scope automatically animates children from
///    their old positions to their new positions.
class ReorderAnimationScope extends StatefulWidget {
  const ReorderAnimationScope({
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOutCubic,
    super.key,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;

  @override
  State<ReorderAnimationScope> createState() => ReorderAnimationScopeState();
}

class ReorderAnimationScopeState extends State<ReorderAnimationScope>
    with TickerProviderStateMixin {
  final _items = <ValueKey<Object>, _ItemEntry>{};
  Map<ValueKey<Object>, Offset>? _snapshots;

  /// Call this BEFORE the setState that reorders children.
  /// Captures each tracked item's current global offset.
  void snapshotPositions() {
    _snapshots = {};
    for (final entry in _items.entries) {
      final box =
          entry.value.key.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.attached) {
        _snapshots![entry.key] = box.localToGlobal(Offset.zero);
      }
    }

    // Schedule the "Last" + "Invert" + "Play" phases after the next frame.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _animateFromSnapshots();
    });
  }

  void _register(ValueKey<Object> itemKey, _ItemEntry entry) {
    _items[itemKey] = entry;
  }

  void _unregister(ValueKey<Object> itemKey) {
    _items.remove(itemKey);
  }

  void _animateFromSnapshots() {
    final snapshots = _snapshots;
    if (snapshots == null) return;
    _snapshots = null;

    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    for (final entry in _items.entries) {
      final oldOffset = snapshots[entry.key];
      if (oldOffset == null) continue; // New item — no old position.

      final box =
          entry.value.key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;

      final newOffset = box.localToGlobal(Offset.zero);
      final delta = oldOffset - newOffset;

      // Skip if position didn't change (or reduce-motion).
      if (delta.dy.abs() < 0.5 || reduceMotion) {
        entry.value.clearAnimation();
        continue;
      }

      entry.value.animateFrom(delta.dy, widget.duration, widget.curve, this);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Wrapper for each reorderable child. Registers with the nearest
/// [ReorderAnimationScope] and applies translate animations.
class ReorderAnimationItem extends StatefulWidget {
  const ReorderAnimationItem({
    required this.itemKey,
    required this.child,
    super.key,
  });

  final ValueKey<Object> itemKey;
  final Widget child;

  @override
  State<ReorderAnimationItem> createState() => _ReorderAnimationItemState();
}

class _ReorderAnimationItemState extends State<ReorderAnimationItem> {
  final GlobalKey _key = GlobalKey();
  AnimationController? _controller;
  late Animation<double> _translateY;
  late Animation<double> _opacity;
  double _currentTranslateY = 0;
  double _currentOpacity = 1;
  ReorderAnimationScopeState? _scope;

  bool get _isAnimating =>
      _currentTranslateY != 0 || _currentOpacity != 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope =
        context.findAncestorStateOfType<ReorderAnimationScopeState>();
    if (scope != _scope) {
      _scope?._unregister(widget.itemKey);
      _scope = scope;
      _scope?._register(
        widget.itemKey,
        _ItemEntry(
          key: _key,
          animateFrom: _animateFrom,
          clearAnimation: _clear,
        ),
      );
    }
  }

  @override
  void dispose() {
    _scope?._unregister(widget.itemKey);
    _controller?.dispose();
    super.dispose();
  }

  void _animateFrom(
    double deltaY,
    Duration duration,
    Curve curve,
    TickerProvider vsync,
  ) {
    _controller?.dispose();
    _controller = AnimationController(vsync: vsync, duration: duration);
    final curved = CurvedAnimation(parent: _controller!, curve: curve);
    _translateY = Tween<double>(begin: deltaY, end: 0).animate(curved);
    _opacity = Tween<double>(begin: 0.6, end: 1).animate(curved);
    _controller!.addListener(() {
      setState(() {
        _currentTranslateY = _translateY.value;
        _currentOpacity = _opacity.value;
      });
    });
    unawaited(_controller!.forward());
  }

  void _clear() {
    _controller?.stop();
    if (_currentTranslateY != 0 || _currentOpacity != 1) {
      setState(() {
        _currentTranslateY = 0;
        _currentOpacity = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child = KeyedSubtree(key: _key, child: widget.child);

    if (_isAnimating) {
      child = Opacity(
        opacity: _currentOpacity,
        child: Transform.translate(
          offset: Offset(0, _currentTranslateY),
          child: child,
        ),
      );
    }

    return child;
  }
}

class _ItemEntry {
  _ItemEntry({
    required this.key,
    required this.animateFrom,
    required this.clearAnimation,
  });

  final GlobalKey key;
  final void Function(double, Duration, Curve, TickerProvider) animateFrom;
  final VoidCallback clearAnimation;
}
