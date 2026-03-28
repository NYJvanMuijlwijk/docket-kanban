import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_board/core/animated_list_item.dart';

void main() {
  group('AnimatedListItem', () {
    testWidgets('renders child immediately when reduce motion is on', (
      tester,
    ) async {
      // MediaQuery.disableAnimationsOf returns true when
      // disableAnimations is set.
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: AnimatedListItem(
                staggerIndex: 0,
                child: Text('Hello'),
              ),
            ),
          ),
        ),
      );

      // Should be visible immediately — no animation.
      expect(find.text('Hello'), findsOneWidget);

      // Opacity wrapper should NOT be present (no controller allocated).
      expect(
        find.byType(Opacity),
        findsNothing,
        reason: 'Reduce-motion skips animation entirely',
      );
    });

    testWidgets('starts invisible and fades in with animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedListItem(
              staggerIndex: 0,
              staggerDelay: Duration.zero,
              child: Text('Animated'),
            ),
          ),
        ),
      );

      // Initial state: opacity 0.
      final opacityBefore = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacityBefore.opacity, 0.0);

      // Advance past animation duration.
      await tester.pumpAndSettle();

      // Final state: opacity 1.
      final opacityAfter = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacityAfter.opacity, 1.0);
    });

    testWidgets('stagger delays animation start by index', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AnimatedListItem(
                  staggerIndex: 0,
                  staggerDelay: Duration(milliseconds: 100),
                  child: Text('First'),
                ),
                AnimatedListItem(
                  staggerIndex: 3,
                  staggerDelay: Duration(milliseconds: 100),
                  child: Text('Fourth'),
                ),
              ],
            ),
          ),
        ),
      );

      // AnimationController timing in tests:
      // pumpWidget → didChangeDependencies → Future.delayed scheduled
      // pump()     → zero-delay timer fires, forward() called
      // pump(16ms) → first vsync tick registered
      // pump(16ms) → second tick: controller value > 0
      //
      // Total elapsed: ~32ms — well under the fourth item's 300ms delay.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      final firstOpacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.text('First'),
          matching: find.byType(Opacity),
        ),
      );
      expect(
        firstOpacity.opacity,
        greaterThan(0),
        reason: 'First item (index 0) should have started animating',
      );

      final fourthOpacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.text('Fourth'),
          matching: find.byType(Opacity),
        ),
      );
      expect(
        fourthOpacity.opacity,
        0.0,
        reason: 'Fourth item (index 3, 300ms delay) should not have started',
      );

      // Settle all pending timers to avoid "Timer still pending" assertion.
      await tester.pumpAndSettle();
    });

    testWidgets('clamps stagger index to maxStaggerIndex', (tester) async {
      // Index 100 with max 8 should behave like index 8.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedListItem(
              staggerIndex: 100,
              child: Text('Capped'),
            ),
          ),
        ),
      );

      // After max delay (8 * 50ms = 400ms) + full duration (300ms) = 700ms,
      // the animation should be complete.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 1.0);
    });
  });
}
