import 'package:flutter/foundation.dart';

/// A kanban board — the top-level container for columns and cards.
///
/// [updatedAt] is stamped only on data mutations (rename). [lastUsedAt] is
/// stamped on board exit (dispose + app lifecycle) and drives the board list
/// sort order (most recently used first).
@immutable
class Board {
  const Board({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.lastUsedAt,
  });

  factory Board.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['createdAt'] as String);
    return Board(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: createdAt,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      // Migration: existing boards without lastUsedAt fall back to createdAt.
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.parse(json['lastUsedAt'] as String)
          : createdAt,
    );
  }

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastUsedAt;

  @override
  int get hashCode => Object.hash(id, name, createdAt, updatedAt, lastUsedAt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Board &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          lastUsedAt == other.lastUsedAt;

  @override
  String toString() => 'Board(id: $id, name: $name)';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastUsedAt': lastUsedAt.toIso8601String(),
    };
  }

  Board copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
  }) {
    return Board(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }
}
