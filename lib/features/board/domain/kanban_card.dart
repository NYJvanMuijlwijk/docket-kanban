import 'package:flutter/foundation.dart';

@immutable
class KanbanCard {
  const KanbanCard({
    required this.id,
    required this.columnId,
    required this.title,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
  });

  factory KanbanCard.fromJson(Map<String, dynamic> json) {
    return KanbanCard(
      id: json['id'] as String,
      columnId: json['columnId'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      order: json['order'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final String id;
  final String columnId;
  final String title;
  final String description;
  final String order;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  int get hashCode =>
      Object.hash(
        id,
        columnId,
        title,
        description,
        order,
        createdAt,
        updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KanbanCard &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          columnId == other.columnId &&
          title == other.title &&
          description == other.description &&
          order == other.order &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  String toString() => 'KanbanCard(id: $id, title: $title)';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'columnId': columnId,
      'title': title,
      'description': description,
      'order': order,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  KanbanCard copyWith({
    String? id,
    String? columnId,
    String? title,
    String? description,
    String? order,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return KanbanCard(
      id: id ?? this.id,
      columnId: columnId ?? this.columnId,
      title: title ?? this.title,
      description: description ?? this.description,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
