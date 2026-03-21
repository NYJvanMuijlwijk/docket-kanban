import 'dart:async';

import 'package:kanban_board/features/board/domain/board.dart';
import 'package:kanban_board/features/board/domain/board_repository.dart';
import 'package:uuid/uuid.dart';

class FakeBoardRepository implements BoardRepository {
  FakeBoardRepository([List<Board>? initialBoards]) {
    if (initialBoards != null) {
      for (final board in initialBoards) {
        _boards[board.id] = board;
      }
    }
  }

  final Map<String, Board> _boards = {};
  final _controller = StreamController<List<Board>>.broadcast();
  static const _uuid = Uuid();

  List<Board> _sorted() {
    final list = _boards.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  void _emit() {
    _controller.add(_sorted());
  }

  @override
  Future<List<Board>> getBoards() async => _sorted();

  @override
  Future<Board?> getBoard(String id) async => _boards[id];

  @override
  Future<Board> createBoard(String name) async {
    final now = DateTime.now();
    final board = Board(
      id: _uuid.v4(),
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    _boards[board.id] = board;
    _emit();
    return board;
  }

  @override
  Future<void> updateBoard(Board board) async {
    if (!_boards.containsKey(board.id)) {
      throw ArgumentError('Board not found: ${board.id}');
    }
    _boards[board.id] = board;
    _emit();
  }

  @override
  Future<void> deleteBoard(String id) async {
    if (!_boards.containsKey(id)) {
      throw ArgumentError('Board not found: $id');
    }
    _boards.remove(id);
    _emit();
  }

  @override
  Stream<List<Board>> watchBoards() {
    return _controller.stream
        .transform(_SeedTransformer<List<Board>>(_sorted));
  }

  @override
  void dispose() {
    unawaited(_controller.close());
  }
}

class _SeedTransformer<T> extends StreamTransformerBase<T, T> {
  _SeedTransformer(this._seedFactory);

  final T Function() _seedFactory;

  @override
  Stream<T> bind(Stream<T> stream) {
    late StreamController<T> controller;
    StreamSubscription<T>? subscription;

    controller = StreamController<T>.broadcast(
      onListen: () {
        controller.add(_seedFactory());
        subscription = stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () {
        unawaited(subscription?.cancel());
      },
    );

    return controller.stream;
  }
}
