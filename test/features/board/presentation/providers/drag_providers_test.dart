import 'dart:ui' show SemanticsAction;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_board/features/board/domain/kanban_card.dart';
import 'package:kanban_board/features/board/presentation/auto_scroll_handler.dart';
import 'package:kanban_board/features/board/presentation/providers/drag_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 3, 24);

  KanbanCard makeCard({
    String id = 'card-1',
    String columnId = 'col-a',
    String title = 'Test card',
    String order = 'a0',
  }) {
    return KanbanCard(
      id: id,
      columnId: columnId,
      title: title,
      order: order,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('KanbanDragController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    KanbanDragState readState() =>
        container.read(kanbanDragControllerProvider);

    KanbanDragController readNotifier() =>
        container.read(kanbanDragControllerProvider.notifier);

    test('initial state is empty', () {
      final state = readState();
      expect(state.isDragging, isFalse);
      expect(state.draggedCard, isNull);
      expect(state.sourceColumnId, isNull);
      expect(state.originalIndex, isNull);
      expect(state.hoverColumnId, isNull);
      expect(state.hoverIndex, isNull);
    });

    test('startDrag sets all active fields', () {
      final card = makeCard();
      readNotifier().startDrag(
        card: card,
        sourceColumnId: 'col-a',
        originalIndex: 2,
      );
      final state = readState();
      expect(state.isDragging, isTrue);
      expect(state.draggedCard, card);
      expect(state.sourceColumnId, 'col-a');
      expect(state.originalIndex, 2);
      expect(state.hoverColumnId, 'col-a');
    });

    test('endDrag clears all state', () {
      readNotifier().startDrag(
        card: makeCard(),
        sourceColumnId: 'col-a',
        originalIndex: 0,
      );
      readNotifier().endDrag();
      expect(readState().isDragging, isFalse);
      expect(readState().draggedCard, isNull);
    });

    test('updateHover sets hoverColumnId and hoverIndex', () {
      readNotifier().startDrag(
        card: makeCard(),
        sourceColumnId: 'col-a',
        originalIndex: 0,
      );
      readNotifier().updateHover(columnId: 'col-b', index: 3);
      expect(readState().hoverColumnId, 'col-b');
      expect(readState().hoverIndex, 3);
    });

    group('adjacency suppression', () {
      test('same col hover at originalIndex → null', () {
        readNotifier().startDrag(
          card: makeCard(),
          sourceColumnId: 'col-a',
          originalIndex: 2,
        );
        readNotifier().updateHover(columnId: 'col-a', index: 2);
        expect(readState().hoverIndex, isNull);
      });

      test('same col hover at originalIndex+1 → null', () {
        readNotifier().startDrag(
          card: makeCard(),
          sourceColumnId: 'col-a',
          originalIndex: 2,
        );
        readNotifier().updateHover(columnId: 'col-a', index: 3);
        expect(readState().hoverIndex, isNull);
      });

      test('same col hover at originalIndex-1 → kept', () {
        readNotifier().startDrag(
          card: makeCard(),
          sourceColumnId: 'col-a',
          originalIndex: 2,
        );
        readNotifier().updateHover(columnId: 'col-a', index: 1);
        expect(readState().hoverIndex, 1);
      });

      test('same col hover at originalIndex+2 → kept', () {
        readNotifier().startDrag(
          card: makeCard(),
          sourceColumnId: 'col-a',
          originalIndex: 2,
        );
        readNotifier().updateHover(columnId: 'col-a', index: 4);
        expect(readState().hoverIndex, 4);
      });
    });

    test('cross-column: no suppression at originalIndex', () {
      readNotifier().startDrag(
        card: makeCard(),
        sourceColumnId: 'col-a',
        originalIndex: 2,
      );
      readNotifier().updateHover(columnId: 'col-b', index: 2);
      expect(readState().hoverIndex, 2);
    });

    test('cross-column: no suppression at originalIndex+1', () {
      readNotifier().startDrag(
        card: makeCard(),
        sourceColumnId: 'col-a',
        originalIndex: 2,
      );
      readNotifier().updateHover(columnId: 'col-b', index: 3);
      expect(readState().hoverIndex, 3);
    });

    test('column append after card-level hover updates to cardCount', () {
      // Scenario: drag from col-a into col-b (3 cards). Pointer first
      // hovers over a card (index 1), then moves below all cards into
      // the column body — column DragTarget fires updateHover with
      // index = cardCount. The controller must accept the update so
      // the last gap (index == cardCount) activates.
      const cardCount = 3;

      readNotifier().startDrag(
        card: makeCard(),
        sourceColumnId: 'col-a',
        originalIndex: 0,
      );

      // Card-level target sets hover to a card index.
      readNotifier().updateHover(columnId: 'col-b', index: 1);
      expect(readState().hoverIndex, 1);

      // Column body target fires — must update to cardCount.
      readNotifier().updateHover(columnId: 'col-b', index: cardCount);
      expect(
        readState().hoverIndex,
        cardCount,
        reason: 'Column-level updateHover(cardCount) must not be blocked '
            'by a prior card-level hover',
      );
    });

    test('duplicate updateHover is a no-op (prevents oscillation)', () {
      readNotifier().startDrag(
        card: makeCard(),
        sourceColumnId: 'col-a',
        originalIndex: 0,
      );

      readNotifier().updateHover(columnId: 'col-b', index: 2);
      final stateAfterFirst = readState();

      // Same column + index again — state object should be identical
      // (no rebuild triggered).
      readNotifier().updateHover(columnId: 'col-b', index: 2);
      expect(
        identical(readState(), stateAfterFirst),
        isTrue,
        reason: 'Duplicate updateHover must not create a new state '
            'object — prevents rebuild oscillation from layout shifts',
      );
    });

    test('updateHover when not dragging is no-op', () {
      readNotifier().updateHover(columnId: 'col-a', index: 0);
      expect(readState().hoverColumnId, isNull);
    });

  });

  group('KanbanDragState.isAdjacencySuppressed', () {
    test('false when not dragging', () {
      expect(KanbanDragState.empty.isAdjacencySuppressed, isFalse);
    });

    test('false for cross-column', () {
      final state = KanbanDragState(
        draggedCard: makeCard(),
        sourceColumnId: 'col-a',
        originalIndex: 1,
        hoverColumnId: 'col-b',
        hoverIndex: 1,
      );
      expect(state.isAdjacencySuppressed, isFalse);
    });

    test('true at originalIndex same column', () {
      final state = KanbanDragState(
        draggedCard: makeCard(),
        sourceColumnId: 'col-a',
        originalIndex: 1,
        hoverColumnId: 'col-a',
        hoverIndex: 1,
      );
      expect(state.isAdjacencySuppressed, isTrue);
    });

    test('true at originalIndex+1 same column', () {
      final state = KanbanDragState(
        draggedCard: makeCard(),
        sourceColumnId: 'col-a',
        originalIndex: 1,
        hoverColumnId: 'col-a',
        hoverIndex: 2,
      );
      expect(state.isAdjacencySuppressed, isTrue);
    });

    test('false when hoverIndex null', () {
      final state = KanbanDragState(
        draggedCard: makeCard(),
        sourceColumnId: 'col-a',
        originalIndex: 1,
        hoverColumnId: 'col-a',
      );
      expect(state.isAdjacencySuppressed, isFalse);
    });
  });

  group('AutoScrollHandler', () {
    late ScrollController hCtrl;
    late ScrollController vCtrl;

    ScrollController makeCtrl({double initial = 500}) {
      final ctrl = ScrollController(initialScrollOffset: initial);
      final pos = _TestScrollPosition(
        initialPixels: initial,
        maxScrollExtent: 1000,
        viewportDimension: 500,
      );
      ctrl.attach(pos);
      return ctrl;
    }

    AutoScrollHandler makeHandler(_FakeTickerProvider t) {
      return AutoScrollHandler(
        horizontalController: hCtrl,
        verticalController: vCtrl,
        vsync: t,
      );
    }

    setUp(() {
      hCtrl = makeCtrl();
      vCtrl = makeCtrl();
    });

    tearDown(() {
      hCtrl.dispose();
      vCtrl.dispose();
    });

    // _onTick uses _lastTick == Duration.zero as a sentinel for "first
    // frame" and returns dt = 0. The warm-up tick must use a nonzero
    // elapsed so _lastTick advances past the sentinel. The second tick
    // then produces a real dt = (second - first).

    test('no-op when pointer is in center', () {
      final t = _FakeTickerProvider();
      final h = makeHandler(t)
        ..viewportSize = const Size(800, 600)
        ..pointerPosition = const Offset(400, 300)
        ..startAutoScroll();
      addTearDown(h.dispose);

      // Warm-up tick (dt = 0).
      t.latestTicker!.tick(const Duration(milliseconds: 16));
      final hBefore = hCtrl.position.pixels;
      final vBefore = vCtrl.position.pixels;
      // Real tick (dt = 16ms). Center => speed = 0.
      t.latestTicker!.tick(const Duration(milliseconds: 32));

      expect(hCtrl.position.pixels, hBefore);
      expect(vCtrl.position.pixels, vBefore);
    });

    test('scrolls backward near left edge', () {
      final t = _FakeTickerProvider();
      final h = makeHandler(t)
        ..viewportSize = const Size(800, 600)
        ..pointerPosition = const Offset(0, 300)
        ..startAutoScroll();
      addTearDown(h.dispose);

      final hBefore = hCtrl.position.pixels;
      t.latestTicker!
        ..tick(const Duration(milliseconds: 16))
        ..tick(const Duration(milliseconds: 32));

      expect(hCtrl.position.pixels, lessThan(hBefore));
      expect(vCtrl.position.pixels, 500);
    });

    test('scrolls forward near right edge', () {
      final t = _FakeTickerProvider();
      final h = makeHandler(t)
        ..viewportSize = const Size(800, 600)
        ..pointerPosition = const Offset(800, 300)
        ..startAutoScroll();
      addTearDown(h.dispose);

      final hBefore = hCtrl.position.pixels;
      t.latestTicker!
        ..tick(const Duration(milliseconds: 16))
        ..tick(const Duration(milliseconds: 32));

      expect(hCtrl.position.pixels, greaterThan(hBefore));
    });

    test('speed just inside edge zone', () {
      final t = _FakeTickerProvider();
      final h = makeHandler(t)
        ..viewportSize = const Size(800, 600)
        ..pointerPosition = const Offset(39, 300)
        ..startAutoScroll();
      addTearDown(h.dispose);

      // Warm-up.
      t.latestTicker!.tick(const Duration(seconds: 1));
      final hBefore = hCtrl.position.pixels;
      // dt = 1s. x=39 => depth=1, t=1/40.
      // speed = 50 + 550 * (1/40) = 63.75 px/s backward.
      t.latestTicker!.tick(const Duration(seconds: 2));

      const expected = 50.0 + 550.0 * (1.0 / 40.0);
      final delta = hCtrl.position.pixels - hBefore;
      expect(delta, closeTo(-expected, 0.01));
    });

    test('speed at very edge (clamped to 0)', () {
      final t = _FakeTickerProvider();
      final h = makeHandler(t)
        ..viewportSize = const Size(800, 600)
        ..pointerPosition = const Offset(0, 300)
        ..startAutoScroll();
      addTearDown(h.dispose);

      t.latestTicker!
        // dt = 1s. -600 px/s from 500 => clamped to 0.
        ..tick(const Duration(seconds: 1))
        ..tick(const Duration(seconds: 2));

      expect(hCtrl.position.pixels, 0);
    });

    test('linear interpolation at 50% depth', () {
      final t = _FakeTickerProvider();
      final h = AutoScrollHandler(
        horizontalController: hCtrl,
        verticalController: vCtrl,
        vsync: t,
        minSpeed: 100,
        maxSpeed: 500,
      )
        ..viewportSize = const Size(800, 600)
        ..pointerPosition = const Offset(20, 300)
        ..startAutoScroll();
      addTearDown(h.dispose);

      // Warm-up.
      t.latestTicker!.tick(const Duration(seconds: 1));
      final hBefore = hCtrl.position.pixels;
      // dt = 1s. x=20 => depth=20, t=0.5.
      // speed = 100 + 400 * 0.5 = 300 px/s backward.
      t.latestTicker!.tick(const Duration(seconds: 2));

      final delta = hCtrl.position.pixels - hBefore;
      expect(delta, closeTo(-300, 0.01));
    });

    test('diagonal: both axes scroll', () {
      final t = _FakeTickerProvider();
      final h = makeHandler(t)
        ..viewportSize = const Size(800, 600)
        ..pointerPosition = const Offset(10, 10)
        ..startAutoScroll();
      addTearDown(h.dispose);

      // Warm-up.
      t.latestTicker!.tick(const Duration(milliseconds: 16));
      final hBefore = hCtrl.position.pixels;
      final vBefore = vCtrl.position.pixels;
      t.latestTicker!.tick(const Duration(milliseconds: 32));

      expect(hCtrl.position.pixels, lessThan(hBefore));
      expect(vCtrl.position.pixels, lessThan(vBefore));
    });

    test('stopAutoScroll clears pointer', () {
      final t = _FakeTickerProvider();
      final h = makeHandler(t)
        ..viewportSize = const Size(800, 600)
        ..pointerPosition = const Offset(0, 300)
        ..startAutoScroll();
      addTearDown(h.dispose);

      h.stopAutoScroll();
      expect(h.pointerPosition, isNull);
    });
  });
}

// ── Test helpers ──────────────────────────────────────────────────

class _FakeTickerProvider implements TickerProvider {
  _FakeTicker? latestTicker;

  @override
  Ticker createTicker(TickerCallback onTick) {
    final ticker = _FakeTicker(onTick);
    latestTicker = ticker;
    return ticker;
  }
}

class _FakeTicker extends Ticker {
  _FakeTicker(this._onTick) : super(_noOp);

  @override
  bool get shouldScheduleTick => false;

  final TickerCallback _onTick;
  bool _started = false;

  @override
  TickerFuture start() {
    _started = true;
    return TickerFuture.complete();
  }

  @override
  void stop({bool canceled = false}) {
    _started = false;
  }

  @override
  void dispose() {
    _started = false;
    super.dispose();
  }

  void tick(Duration elapsed) {
    if (_started) _onTick(elapsed);
  }

  static void _noOp(Duration _) {}
}

class _TestScrollPosition extends ScrollPositionWithSingleContext {
  _TestScrollPosition({
    required double initialPixels,
    required double maxScrollExtent,
    required double viewportDimension,
  }) : super(
          physics: const ScrollPhysics(),
          context: _NoOpScrollContext(),
          initialPixels: initialPixels,
          keepScrollOffset: false,
        ) {
    applyContentDimensions(0, maxScrollExtent);
    applyViewportDimension(viewportDimension);
  }

  @override
  void jumpTo(double value) {
    if (pixels != value) {
      forcePixels(value);
    }
  }

  @override
  void restoreScrollOffset() {}

  @override
  void saveScrollOffset() {}
}

class _NoOpScrollContext implements ScrollContext {
  @override
  AxisDirection get axisDirection => AxisDirection.down;

  @override
  BuildContext? get notificationContext => null;

  @override
  BuildContext get storageContext =>
      throw UnimplementedError('not needed');

  @override
  TickerProvider get vsync => _FakeTickerProvider();

  @override
  double get devicePixelRatio => 1;

  @override
  void saveOffset(double offset) {}

  @override
  void setCanDrag(bool value) {}

  @override
  void setIgnorePointer(bool value) {}

  @override
  void setSemanticsActions(Set<SemanticsAction> actions) {}
}
