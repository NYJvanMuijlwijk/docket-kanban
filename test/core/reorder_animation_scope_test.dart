import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_board/core/reorder_animation_scope.dart';

void main() {
  group('ReorderAnimationScope', () {
    testWidgets('renders children without animation on initial build', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReorderAnimationScope(
              child: Column(
                children: [
                  ReorderAnimationItem(
                    itemKey: ValueKey('a'),
                    child: SizedBox(height: 50, child: Text('A')),
                  ),
                  ReorderAnimationItem(
                    itemKey: ValueKey('b'),
                    child: SizedBox(height: 50, child: Text('B')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);

      // No Transform.translate should be wrapping children on first build.
      // The ReorderAnimationItem renders its child directly when idle.
      final transforms = tester.widgetList<Transform>(find.byType(Transform));
      for (final t in transforms) {
        expect(t.transform.getTranslation().y, 0.0);
      }
    });

    testWidgets('animates children to new positions after reorder', (
      tester,
    ) async {
      final items = ['a', 'b', 'c'];

      await tester.pumpWidget(
        _ReorderTestHarness(items: List.of(items)),
      );
      await tester.pumpAndSettle();

      // Trigger reorder: move 'a' to end → ['b', 'c', 'a'].
      tester
          .state<_ReorderTestHarnessState>(
            find.byType(_ReorderTestHarness),
          )
          .reorder(['b', 'c', 'a']);

      // Pump one frame — post-frame callback fires, animations start.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      // 'b' moved up (from index 1 to 0), so its translate Y should be
      // positive (animating FROM below, i.e. old position was lower).
      final bTranslateY = _getTranslateY(tester, 'b');
      expect(
        bTranslateY,
        greaterThan(0),
        reason: 'b should be animating from its old (lower) position',
      );

      // After settling, all translates should be zero.
      await tester.pumpAndSettle();
      expect(_getTranslateY(tester, 'a'), 0.0);
      expect(_getTranslateY(tester, 'b'), 0.0);
      expect(_getTranslateY(tester, 'c'), 0.0);
    });

    testWidgets('skips animation when reduce-motion is enabled', (
      tester,
    ) async {
      final items = ['a', 'b'];

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _ReorderTestHarness(items: List.of(items)),
        ),
      );
      await tester.pumpAndSettle();

      tester
          .state<_ReorderTestHarnessState>(
            find.byType(_ReorderTestHarness),
          )
          .reorder(['b', 'a']);
      await tester.pump();

      // With reduce-motion, translate should be zero immediately.
      expect(_getTranslateY(tester, 'a'), 0.0);
      expect(_getTranslateY(tester, 'b'), 0.0);
    });
  });
}

/// Extracts the Y translate applied by ReorderAnimationItem.
/// Returns 0.0 when no Transform is present (idle / reduce-motion).
double _getTranslateY(WidgetTester tester, String label) {
  final itemFinder = find.ancestor(
    of: find.text(label.toUpperCase()),
    matching: find.byType(ReorderAnimationItem),
  );
  final transformFinder = find.descendant(
    of: itemFinder,
    matching: find.byType(Transform),
  );
  if (transformFinder.evaluate().isEmpty) return 0;
  final transform = tester.widget<Transform>(transformFinder);
  return transform.transform.getTranslation().y;
}

/// Test harness that wraps items in ReorderAnimationScope and exposes
/// a reorder method that snapshots + rebuilds in the correct order.
class _ReorderTestHarness extends StatefulWidget {
  const _ReorderTestHarness({required this.items});
  final List<String> items;

  @override
  State<_ReorderTestHarness> createState() => _ReorderTestHarnessState();
}

class _ReorderTestHarnessState extends State<_ReorderTestHarness> {
  final GlobalKey<ReorderAnimationScopeState> _scopeKey =
      GlobalKey<ReorderAnimationScopeState>();
  late List<String> _items = widget.items;

  void reorder(List<String> newOrder) {
    _scopeKey.currentState!.snapshotPositions();
    setState(() => _items = newOrder);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ReorderAnimationScope(
          key: _scopeKey,
          child: Column(
            children: [
              for (final item in _items)
                ReorderAnimationItem(
                  key: ValueKey(item),
                  itemKey: ValueKey(item),
                  child: SizedBox(
                    height: 60,
                    child: Center(child: Text(item.toUpperCase())),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
