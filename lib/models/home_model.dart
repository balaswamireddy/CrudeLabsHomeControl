import 'board_model.dart';

class Home {
  final String id;
  final String userId;
  final String name;
  final String? wallpaperPath;
  final List<Board> boards;

  Home({
    required this.id,
    required this.userId,
    required this.name,
    this.wallpaperPath,
    required this.boards,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'wallpaper_path': wallpaperPath,
      'boards': boards.map((board) => board.toJson()).toList(),
    };
  }

  factory Home.fromJson(Map<String, dynamic> json) {
    return Home(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      wallpaperPath: json['wallpaper_path'],
      boards: json['boards'] != null
          ? (json['boards'] as List)
                .map((board) => Board.fromJson(board))
                .toList()
          : [],
    );
  }
}
