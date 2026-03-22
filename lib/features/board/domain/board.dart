import 'dart:collection';

import 'package:flutter/foundation.dart';

@immutable
class Board {
  Board({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    List<String> columnOrder = const [],
  }) : columnOrder = UnmodifiableListView(columnOrder);

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      columnOrder: (json['columnOrder'] as List<dynamic>?)
              ?.cast<String>()
              .toList() ??
          const [],
    );
  }

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> columnOrder;

  @override
  int get hashCode =>
      Object.hash(id, name, createdAt, updatedAt, Object.hashAll(columnOrder));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Board &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          listEquals(columnOrder, other.columnOrder);

  @override
  String toString() => 'Board(id: $id, name: $name)';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'columnOrder': columnOrder,
    };
  }

  Board copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? columnOrder,
  }) {
    return Board(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      columnOrder: columnOrder ?? this.columnOrder,
    );
  }
}
