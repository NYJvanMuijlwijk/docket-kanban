import 'dart:async';

import 'package:flutter/material.dart';

/// Provides a shared [AnimationController] to descendant [ShimmerBlock]s
/// so all shimmer effects pulse in sync.
class ShimmerScope extends StatefulWidget {
  const ShimmerScope({required this.child, super.key});

  final Widget child;

  @override
  State<ShimmerScope> createState() => _ShimmerScopeState();

  static AnimationController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'No ShimmerScope found in widget tree');
    return controller!;
  }

  static AnimationController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ShimmerInherited>()
        ?.notifier;
  }
}

class _ShimmerScopeState extends State<ShimmerScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    unawaited(_controller.repeat());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerInherited(
      notifier: _controller,
      child: widget.child,
    );
  }
}

class _ShimmerInherited extends InheritedNotifier<AnimationController> {
  const _ShimmerInherited({
    required AnimationController super.notifier,
    required super.child,
  });
}

/// Translates the shimmer gradient across the block.
class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.progress);

  final double progress;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    // Slide the gradient from -width to +width.
    return Matrix4.translationValues(
      bounds.width * (2 * progress - 1),
      0,
      0,
    );
  }
}

/// A rounded rectangle with a shimmer animation.
///
/// Must be a descendant of [ShimmerScope]. Reads theme colors in [build]
/// (never cached in initState) for hot-reload and theme-switch correctness.
class ShimmerBlock extends StatelessWidget {
  const ShimmerBlock({
    required this.width,
    required this.height,
    this.borderRadius = 4,
    super.key,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final controller = ShimmerScope.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // Read theme inside the builder callback so colors update on
        // theme changes. The builder's context inherits Theme from above.
        final colorScheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final baseColor = isDark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainerLow;
        final highlightColor =
            isDark ? colorScheme.surfaceContainerHigh : colorScheme.surface;

        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(controller.value),
            ).createShader(bounds);
          },
          child: SizedBox(
            width: width,
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
          ),
        );
      },
    );
  }
}
