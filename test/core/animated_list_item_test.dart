import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_board/core/animated_list_item.dart';

void main() {
  group('AnimatedListItem', () {
    testWidgets('renders child immediately when reduce motion is on', (
      tester,
    ) async {
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

      // No FadeTransition under AnimatedListItem when reduce-motion is active.
      // (MaterialApp's route transitions also use FadeTransition, so scope.)
      expect(
        find.descendant(
          of: find.byType(AnimatedListItem),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
        reason: 'Reduce-motion skips animation entirely — no controller',
      );
    });

    testWidgets('renders child immediately when skipAnimation is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedListItem(
              staggerIndex: 0,
              skipAnimation: true,
              child: Text('Skipped'),
            ),
          ),
        ),
      );

      expect(find.text('Skipped'), findsOneWidget);

      expect(
        find.descendant(
          of: find.byType(AnimatedListItem),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
        reason: 'skipAnimation bypasses controller allocation',
      );
    });

    testWidgets('starts invisible and fades/slides in with animation', (
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

      // Scope finders to AnimatedListItem subtree to avoid route transitions.
      final itemFinder = find.byType(AnimatedListItem);

      // Initial state: opacity 0, offset below final position.
      final fadeBefore = tester.widget<FadeTransition>(
        find.descendant(of: itemFinder, matching: find.byType(FadeTransition)),
      );
      expect(fadeBefore.opacity.value, 0.0);

      final transformBefore = tester.widget<Transform>(
        find.descendant(of: itemFinder, matching: find.byType(Transform)),
      );
      // Default slideOffset is 12.0 — starts below.
      expect(transformBefore.transform.getTranslation().y, 12.0);

      // Advance past animation duration.
      await tester.pumpAndSettle();

      // Final state: fully visible at origin.
      final fadeAfter = tester.widget<FadeTransition>(
        find.descendant(of: itemFinder, matching: find.byType(FadeTransition)),
      );
      expect(fadeAfter.opacity.value, 1.0);

      final transformAfter = tester.widget<Transform>(
        find.descendant(of: itemFinder, matching: find.byType(Transform)),
      );
      expect(transformAfter.transform.getTranslation().y, 0.0);
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

      final firstFade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.ancestor(
            of: find.text('First'),
            matching: find.byType(AnimatedListItem),
          ),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(
        firstFade.opacity.value,
        greaterThan(0),
        reason: 'First item (index 0) should have started animating',
      );

      final fourthFade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.ancestor(
            of: find.text('Fourth'),
            matching: find.byType(AnimatedListItem),
          ),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(
        fourthFade.opacity.value,
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

      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(AnimatedListItem),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fade.opacity.value, 1.0);
    });
  });
}
