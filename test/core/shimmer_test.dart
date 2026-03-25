import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_board/core/shimmer.dart';
import 'package:kanban_board/core/theme.dart';

void main() {
  group('ShimmerScope', () {
    testWidgets('renders child without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDarkTheme(),
          home: const Scaffold(
            body: ShimmerScope(
              child: SizedBox(width: 100, height: 50),
            ),
          ),
        ),
      );

      expect(find.byType(ShimmerScope), findsOneWidget);
    });

    testWidgets('disposes without leaking tickers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDarkTheme(),
          home: const Scaffold(
            body: ShimmerScope(
              child: SizedBox(width: 100, height: 50),
            ),
          ),
        ),
      );

      // Replace widget tree — triggers dispose.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      // No pending timers or tickers = test framework would complain.
      // Reaching here without error means disposal was clean.
    });

    testWidgets('of() returns animation controller', (tester) async {
      AnimationController? controller;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildDarkTheme(),
          home: Scaffold(
            body: ShimmerScope(
              child: Builder(
                builder: (context) {
                  controller = ShimmerScope.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      expect(controller, isNotNull);
      expect(controller!.isAnimating, isTrue);
    });

    testWidgets('maybeOf() returns null without ancestor', (tester) async {
      AnimationController? controller;
      var wasCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildDarkTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                controller = ShimmerScope.maybeOf(context);
                wasCalled = true;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(wasCalled, isTrue);
      expect(controller, isNull);
    });
  });

  group('ShimmerBlock', () {
    testWidgets('renders with specified dimensions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDarkTheme(),
          home: const Scaffold(
            body: ShimmerScope(
              child: ShimmerBlock(width: 200, height: 16),
            ),
          ),
        ),
      );

      expect(find.byType(ShimmerBlock), findsOneWidget);

      // ShimmerBlock should create a SizedBox with specified dimensions.
      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(ShimmerBlock),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBox.width, 200);
      expect(sizedBox.height, 16);
    });

    testWidgets('uses dark theme colors in dark mode', (tester) async {
      late ColorScheme colorScheme;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildDarkTheme(),
          home: Scaffold(
            body: ShimmerScope(
              child: Builder(
                builder: (context) {
                  colorScheme = Theme.of(context).colorScheme;
                  return const ShimmerBlock(width: 100, height: 16);
                },
              ),
            ),
          ),
        ),
      );

      // In dark mode, shimmer should use surfaceContainerHighest as base.
      // Verify the DecoratedBox/Container uses the right base color.
      final container = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(ShimmerBlock),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, colorScheme.surfaceContainerHighest);
    });

    testWidgets('uses light theme colors in light mode', (tester) async {
      late ColorScheme colorScheme;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: ShimmerScope(
              child: Builder(
                builder: (context) {
                  colorScheme = Theme.of(context).colorScheme;
                  return const ShimmerBlock(width: 100, height: 16);
                },
              ),
            ),
          ),
        ),
      );

      final container = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(ShimmerBlock),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, colorScheme.surfaceContainerLow);
    });

    testWidgets('uses custom borderRadius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDarkTheme(),
          home: const Scaffold(
            body: ShimmerScope(
              child: ShimmerBlock(width: 100, height: 16, borderRadius: 12),
            ),
          ),
        ),
      );

      final container = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(ShimmerBlock),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(
        decoration.borderRadius,
        BorderRadius.circular(12),
      );
    });

    testWidgets('dark and light themes produce different base colors',
        (tester) async {
      // The separate dark/light tests verify correct colors for each.
      // This test ensures the two themes produce visually distinct shimmers.
      final darkBase = buildDarkTheme().colorScheme.surfaceContainerHighest;
      final lightBase = buildLightTheme().colorScheme.surfaceContainerLow;
      expect(darkBase, isNot(equals(lightBase)));
    });
  });
}
