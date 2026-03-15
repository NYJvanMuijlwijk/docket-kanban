import 'package:app/features/boards/repositories/board_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'board_controller.g.dart';

/// Controller for managing board-related actions and state.
@riverpod
class BoardController extends _$BoardController {
  /// Creates a new board with the given title and owner ID.
  Future<void> createBoard({
    required String title,
    required String ownerId,
  }) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      await ref
          .read(boardRepositoryProvider)
          .createBoard(
            title: title,
            ownerId: ownerId,
          );
    });
  }

  @override
  FutureOr<void> build() {}
}
