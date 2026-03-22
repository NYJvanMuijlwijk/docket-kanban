import 'package:kanban_board/features/board/domain/kanban_card.dart';
import 'package:kanban_board/features/board/presentation/providers/board_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'card_providers.g.dart';

@riverpod
class CardList extends _$CardList {
  @override
  Stream<List<KanbanCard>> build(String columnId) {
    final repository = ref.watch(boardRepositoryProvider);
    return repository.watchCards(columnId);
  }

  Future<KanbanCard> createCard({
    required String title,
    String description = '',
  }) {
    final repository = ref.read(boardRepositoryProvider);
    return repository.createCard(
      columnId: columnId,
      title: title,
      description: description,
    );
  }

  Future<void> updateCard({
    required String id,
    required String title,
    required String description,
  }) async {
    final repository = ref.read(boardRepositoryProvider);
    final card = await repository.getCard(id);
    if (card == null) {
      throw ArgumentError('Card not found: $id');
    }
    await repository.updateCard(
      card.copyWith(
        title: title,
        description: description,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteCard(String id) {
    final repository = ref.read(boardRepositoryProvider);
    return repository.deleteCard(id);
  }
}
