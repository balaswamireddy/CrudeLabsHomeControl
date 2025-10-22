class Board {
  final String id;
  final String homeId;
  final String name;
  final DateTime createdAt;

  Board({
    required this.id,
    required this.homeId,
    required this.name,
    required this.createdAt,
  });

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      id: json['id'] as String,
      homeId: json['home_id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'home_id': homeId,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
