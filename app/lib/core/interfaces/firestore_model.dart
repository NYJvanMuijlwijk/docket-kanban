import 'package:cloud_firestore/cloud_firestore.dart';

/// Model interface for Firestore documents
abstract interface class FirestoreModel<T> {
  /// The unique identifier for this model, typically the Firestore document ID.
  String get id;

  /// Converts this model to a JSON map for storage in Firestore.
  Map<String, Object?> toFirestore(T model, SetOptions? options);

  /// Creates an instance of this model from a Firestore document snapshot.
  T fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  );
}
