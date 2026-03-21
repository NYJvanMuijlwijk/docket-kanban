import 'dart:async';

import 'package:hive/hive.dart';
import 'package:kanban_board/core/seed_transformer.dart';
import 'package:kanban_board/features/board/domain/board.dart';
import 'package:kanban_board/features/board/domain/board_repository.dart';
import 'package:uuid/uuid.dart';

class HiveBoardRepository implements BoardRepository {
  HiveBoardRepository(this._box) {
    _subscription = _box.watch().listen((_) => _emit());
  }

  static const boxName = 'boards';

  final Box<Map<dynamic, dynamic>> _box;
  final _uuid = const Uuid();
  final _controller = StreamController<List<Board>>.broadcast();
  late final StreamSubscription<BoxEvent> _subscription;

  List<Board> _readAll() {
    final boards = _box.values
        .map(
          (raw) => Board.fromJson(Map<String, dynamic>.from(raw)),
        )
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return boards;
  }

  void _emit() {
    _controller.add(_readAll());
  }

  @override
  Future<List<Board>> getBoards() async => _readAll();

  @override
  Future<Board?> getBoard(String id) async {
    final raw = _box.get(id);
    if (raw == null) return null;
    return Board.fromJson(Map<String, dynamic>.from(raw));
  }

  @override
  Future<Board> createBoard(String name) async {
    final now = DateTime.now();
    final board = Board(
      id: _uuid.v4(),
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    await _box.put(board.id, board.toJson());
    return board;
  }

  @override
  Future<void> updateBoard(Board board) async {
    if (!_box.containsKey(board.id)) {
      throw ArgumentError('Board not found: ${board.id}');
    }
    await _box.put(board.id, board.toJson());
  }

  @override
  Future<void> deleteBoard(String id) async {
    if (!_box.containsKey(id)) {
      throw ArgumentError('Board not found: $id');
    }
    await _box.delete(id);
  }

  @override
  Stream<List<Board>> watchBoards() {
    return _controller.stream
        .transform(SeedTransformer<List<Board>>(_readAll));
  }

  @override
  Stream<Board?> watchBoard(String id) {
    return watchBoards().map(
      (boards) {
        for (final board in boards) {
          if (board.id == id) return board;
        }
        return null;
      },
    );
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_controller.close());
  }
}
