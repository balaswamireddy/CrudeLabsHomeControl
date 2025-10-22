import 'switch_type.dart';

class SwitchDevice {
  final String id;
  final String boardId;
  final String name;
  final SwitchType type;
  final String? icon;
  final int position;
  final bool state;
  final bool isEnabled;
  final DateTime? lastStateChange;
  final double? powerRating;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SwitchDevice({
    required this.id,
    required this.boardId,
    required this.name,
    required this.type,
    this.icon,
    required this.position,
    required this.state,
    this.isEnabled = true,
    this.lastStateChange,
    this.powerRating,
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  factory SwitchDevice.fromJson(Map<String, dynamic> json) {
    return SwitchDevice(
      id: json['id'],
      boardId: json['board_id'],
      name: json['name'],
      type: SwitchType.values.firstWhere(
        (type) => type.name == (json['type'] ?? 'light'),
        orElse: () => SwitchType.light,
      ),
      icon: json['icon'],
      position: json['position'] ?? 0,
      state: json['state'] ?? false,
      isEnabled: json['is_enabled'] ?? true,
      lastStateChange: json['last_state_change'] != null
          ? DateTime.parse(json['last_state_change'])
          : null,
      powerRating: json['power_rating']?.toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'board_id': boardId,
      'name': name,
      'type': type.name,
      'icon': icon,
      'position': position,
      'state': state,
      'is_enabled': isEnabled,
      'last_state_change': lastStateChange?.toIso8601String(),
      'power_rating': powerRating,
      'metadata': metadata,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  SwitchDevice copyWith({
    String? id,
    String? boardId,
    String? name,
    SwitchType? type,
    String? icon,
    int? position,
    bool? state,
    bool? isEnabled,
    DateTime? lastStateChange,
    double? powerRating,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SwitchDevice(
      id: id ?? this.id,
      boardId: boardId ?? this.boardId,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      position: position ?? this.position,
      state: state ?? this.state,
      isEnabled: isEnabled ?? this.isEnabled,
      lastStateChange: lastStateChange ?? this.lastStateChange,
      powerRating: powerRating ?? this.powerRating,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
