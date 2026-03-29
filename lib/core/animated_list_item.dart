import 'dart:async';

import 'package:flutter/material.dart';

/// Animates a child's entrance with a combined fade + vertical slide.
///
/// Each item receives a [staggerIndex] that offsets its start time,
/// creating a cascading reveal effect. Respects reduce-motion settings —
/// when animations are disabled, the child renders immediately with
/// no controller allocation.
///
/// Cap [staggerIndex] to [maxStaggerIndex] so late items in long lists
/// don't wait unreasonably long to appear.
class AnimatedListItem extends StatefulWidget {
  const AnimatedListItem({
    required this.staggerIndex,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.staggerDelay = const Duration(milliseconds: 50),
    this.maxStaggerIndex = 8,
    this.slideOffset = 12.0,
    this.skipAnimation = false,
    super.key,
  });

  final int staggerIndex;
  final Widget child;
  final Duration duration;
  final Duration staggerDelay;
  final int maxStaggerIndex;

  /// When true, the child renders immediately with no animation.
  /// Used for items that have already been seen and should not replay
  /// the entrance animation on provider rebuilds.
  final bool skipAnimation;

  /// Vertical offset in logical pixels. Positive = starts below final position.
  final double slideOffset;

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return; // Already initialized.

    if (widget.skipAnimation) return; // Already-seen item — no animation.

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) return; // Skip — build() renders child directly.

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    final curved = CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(curved);

    // Slide from below (positive Y offset) to origin.
    // Offset is in fractional units for SlideTransition, but we want
    // pixel control — so we use a custom Tween<Offset> with
    // Transform.translate instead.
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.slideOffset),
      end: Offset.zero,
    ).animate(curved);

    // Stagger: delay start based on clamped index.
    final clampedIndex = widget.staggerIndex.clamp(0, widget.maxStaggerIndex);
    final delay = widget.staggerDelay * clampedIndex;

    unawaited(
      Future.delayed(delay, () {
        if (mounted) unawaited(_controller!.forward());
      }),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduce-motion or controller not yet initialized: render immediately.
    if (_controller == null) return widget.child;

    return AnimatedBuilder(
      animation: _controller!,
      child: widget.child,
      builder: (context, child) {
        return Transform.translate(
          offset: _slideAnimation.value,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: child,
          ),
        );
      },
    );
  }
}
