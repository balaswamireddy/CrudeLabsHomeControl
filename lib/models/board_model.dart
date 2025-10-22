import 'switch_model.dart';

enum BoardStatus { online, offline, maintenance }

class Board {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? location;
  final BoardStatus status;
  final String? macAddress;
  final String? firmwareVersion;
  final DateTime? lastOnline;
  final Map<String, dynamic>? connectionInfo;
  final Map<String, dynamic>? metadata;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<SwitchDevice> switches;

  Board({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.location,
    this.status = BoardStatus.offline,
    this.macAddress,
    this.firmwareVersion,
    this.lastOnline,
    this.connectionInfo,
    this.metadata,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.switches = const [],
  });

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      id: json['id'],
      ownerId: json['owner_id'],
      name: json['name'],
      description: json['description'],
      location: json['location'],
      status: BoardStatus.values.firstWhere(
        (status) => status.name == (json['status'] ?? 'offline'),
        orElse: () => BoardStatus.offline,
      ),
      macAddress: json['mac_address'],
      firmwareVersion: json['firmware_version'],
      lastOnline: json['last_online'] != null
          ? DateTime.parse(json['last_online'])
          : null,
      connectionInfo: json['connection_info'] as Map<String, dynamic>?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      switches:
          (json['switches'] as List?)
              ?.map((switch_) => SwitchDevice.fromJson(switch_))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'description': description,
      'location': location,
      'status': status.name,
      'mac_address': macAddress,
      'firmware_version': firmwareVersion,
      'last_online': lastOnline?.toIso8601String(),
      'connection_info': connectionInfo,
      'metadata': metadata,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'switches': switches.map((switch_) => switch_.toJson()).toList(),
    };
  }

  Board copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    String? location,
    BoardStatus? status,
    String? macAddress,
    String? firmwareVersion,
    DateTime? lastOnline,
    Map<String, dynamic>? connectionInfo,
    Map<String, dynamic>? metadata,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<SwitchDevice>? switches,
  }) {
    return Board(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      status: status ?? this.status,
      macAddress: macAddress ?? this.macAddress,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      lastOnline: lastOnline ?? this.lastOnline,
      connectionInfo: connectionInfo ?? this.connectionInfo,
      metadata: metadata ?? this.metadata,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      switches: switches ?? this.switches,
    );
  }
}
