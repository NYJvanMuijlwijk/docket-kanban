import 'package:flutter/foundation.dart';

/// Maximum length for column names, shared across creation and rename forms.
const maxColumnNameLength = 50;

@immutable
class KanbanColumn {
  const KanbanColumn({
    required this.id,
    required this.boardId,
    required this.name,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
  });

  factory KanbanColumn.fromJson(Map<String, dynamic> json) {
    return KanbanColumn(
      id: json['id'] as String,
      boardId: json['boardId'] as String,
      name: json['name'] as String,
      order: json['order'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final String id;
  final String boardId;
  final String name;
  final String order;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  int get hashCode =>
      Object.hash(id, boardId, name, order, createdAt, updatedAt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KanbanColumn &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          boardId == other.boardId &&
          name == other.name &&
          order == other.order &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  String toString() => 'KanbanColumn(id: $id, name: $name)';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'boardId': boardId,
      'name': name,
      'order': order,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  KanbanColumn copyWith({
    String? id,
    String? boardId,
    String? name,
    String? order,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return KanbanColumn(
      id: id ?? this.id,
      boardId: boardId ?? this.boardId,
      name: name ?? this.name,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
