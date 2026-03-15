import 'package:app/features/auth/providers/firebase_auth_service_provider.dart';
import 'package:app/features/boards/models/board.dart';
import 'package:app/features/boards/repositories/board_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_boards_provider.g.dart';

/// Provider that watches the list of boards for a specific user.
@riverpod
Stream<List<Board>> userBoards(Ref ref) {
  final user = ref.watch(currentUserProvider);

  if (user == null) {
    return Stream.value([]);
  }

  return ref.watch(boardRepositoryProvider).watchBoardsForUser(user.uid);
}
