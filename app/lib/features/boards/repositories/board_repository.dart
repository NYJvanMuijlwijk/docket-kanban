import 'package:app/features/boards/models/board.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'board_repository.g.dart';

/// Repository for managing [Board]s
@riverpod
BoardRepository boardRepository(Ref ref) {
  return BoardRepository();
}

/// Repository class for handling data operations related to [Board]s.
class BoardRepository {
  /// The Firestore service used for data operations.
  final FirebaseFirestore db = FirebaseFirestore.instance;

  /// The Firestore collection path for boards.
  static const String collectionPath = 'boards';

  /// A reference to the Firestore collection for [Board]s
  /// with converters for serialization.
  CollectionReference<Board> get boardsCollection => db
      .collection(collectionPath)
      .withConverter(
        fromFirestore: (snapshot, _) => Board.fromFirestore(snapshot),
        toFirestore: (board, options) => board.toFirestore(board, options),
      );

  /// Streams a list of all [Board]s available to the user
  Stream<List<Board>> watchBoardsForUser(String userId) {
    return boardsCollection
        .where(
          Filter.or(
            Filter(BoardFields.ownerId, isEqualTo: userId),
            Filter(
              BoardFields.members,
              arrayContains: userId,
            ),
          ),
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) => doc.data()).toList(),
        );
  }

  /// Creates a new [Board] with the given title and owner.
  Future<void> createBoard({
    required String title,
    required String ownerId,
  }) async {
    final newBoard = Board(
      id: '', // Firestore will generate the ID
      title: title,
      ownerId: ownerId,
      members: [],
    );

    await boardsCollection.add(newBoard);
  }
}
