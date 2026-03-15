import 'package:app/core/interfaces/firestore_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Fields used in the Firestore collection for [Board]s
abstract class BoardFields {
  /// The field name for the owner ID in the Firestore document.
  static const String ownerId = 'ownerId';

  /// The field name for the title in the Firestore document.
  static const String title = 'title';

  /// The field name for the members list in the Firestore document.
  static const String members = 'members';
}

/// A Kanban board
class Board implements FirestoreModel<Board> {
  /// Creates a new instance of [Board]
  const Board({
    required this.id,
    required this.ownerId,
    required this.title,
    this.members = const [],
  });

  /// Creates a [Board] instance from a Firestore document snapshot.
  factory Board.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    if (data == null) {
      throw StateError('Board document data is null');
    }

    return Board(
      id: doc.id,
      title: data[BoardFields.title] as String? ?? 'Untitled Board',
      ownerId: data[BoardFields.ownerId] as String? ?? '',
      members: List<String>.from(
        data[BoardFields.members] as List<dynamic>? ?? [],
      ),
    );
  }

  /// The unique identifier for the board.
  @override
  final String id;

  /// The ID of the user who owns the board.
  final String ownerId;

  /// The title of the board.
  final String title;

  /// The list of member user IDs who have access to the board.
  final List<String> members;

  @override
  Board fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    return Board.fromFirestore(snapshot);
  }

  @override
  Map<String, Object?> toFirestore(Board model, SetOptions? options) {
    return {
      BoardFields.title: model.title,
      BoardFields.ownerId: model.ownerId,
      BoardFields.members: model.members,
    };
  }
}
