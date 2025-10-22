import 'board_model.dart';

class Room {
  final String id;
  final String homeId;
  final String name;
  final String? description;
  final String? icon;
  final int? displayOrder;
  final Map<String, dynamic>? metadata;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<Board> boards;

  Room({
    required this.id,
    required this.homeId,
    required this.name,
    this.description,
    this.icon,
    this.displayOrder,
    this.metadata,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.boards = const [],
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'],
      homeId: json['home_id'],
      name: json['name'],
      description: json['description'],
      icon: json['icon'],
      displayOrder: json['display_order'],
      metadata: json['metadata'] as Map<String, dynamic>?,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      boards:
          (json['boards'] as List?)
              ?.map((board) => Board.fromJson(board))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'home_id': homeId,
      'name': name,
      'description': description,
      'icon': icon,
      'display_order': displayOrder,
      'metadata': metadata,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'boards': boards.map((board) => board.toJson()).toList(),
    };
  }

  Room copyWith({
    String? id,
    String? homeId,
    String? name,
    String? description,
    String? icon,
    int? displayOrder,
    Map<String, dynamic>? metadata,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Board>? boards,
  }) {
    return Room(
      id: id ?? this.id,
      homeId: homeId ?? this.homeId,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      displayOrder: displayOrder ?? this.displayOrder,
      metadata: metadata ?? this.metadata,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      boards: boards ?? this.boards,
    );
  }
}
