class UserProfile {
  final String id;
  final String username;
  final String email;
  final String? location;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    this.location,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      location: json['location'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'location': location,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? username,
    String? email,
    String? location,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
