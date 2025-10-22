enum TimerType {
  scheduled, // Regular scheduled timer (runs on specified days and time)
  prescheduled, // One-time future schedule
  countdown, // Countdown timer
}

class SwitchTimer {
  final String id;
  final String switchId;
  final String? name;
  final TimerType type;
  final String
  time; // For scheduled and prescheduled: HH:mm, for countdown: duration in minutes
  final List<String> days; // Empty for prescheduled and countdown
  final bool state;
  final bool isEnabled;
  final DateTime? scheduledDate; // Only for prescheduled type
  final DateTime? lastRun;
  final DateTime? nextRun;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SwitchTimer({
    required this.id,
    required this.switchId,
    this.name,
    required this.type,
    required this.time,
    required this.days,
    required this.state,
    required this.isEnabled,
    this.scheduledDate,
    this.lastRun,
    this.nextRun,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory SwitchTimer.fromJson(Map<String, dynamic> json) {
    return SwitchTimer(
      id: json['id'],
      switchId: json['switch_id'],
      name: json['name'],
      type: TimerType.values.firstWhere(
        (e) =>
            e.name.toLowerCase() == (json['type'] ?? 'scheduled').toLowerCase(),
        orElse: () => TimerType.scheduled,
      ),
      time: json['time'],
      days: List<String>.from(json['days'] ?? []),
      state: json['state'] ?? true,
      isEnabled: json['is_enabled'] ?? true,
      scheduledDate: json['scheduled_date'] != null
          ? DateTime.parse(json['scheduled_date'])
          : null,
      lastRun: json['last_run'] != null
          ? DateTime.parse(json['last_run'])
          : null,
      nextRun: json['next_run'] != null
          ? DateTime.parse(json['next_run'])
          : null,
      createdBy: json['created_by'],
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
      'switch_id': switchId,
      'name': name,
      'type': type.name.toLowerCase(),
      'time': time,
      'days': days,
      'state': state,
      'is_enabled': isEnabled,
      'scheduled_date': scheduledDate?.toIso8601String(),
      'last_run': lastRun?.toIso8601String(),
      'next_run': nextRun?.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  SwitchTimer copyWith({
    String? id,
    String? switchId,
    String? name,
    TimerType? type,
    String? time,
    List<String>? days,
    bool? state,
    bool? isEnabled,
    DateTime? scheduledDate,
    DateTime? lastRun,
    DateTime? nextRun,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SwitchTimer(
      id: id ?? this.id,
      switchId: switchId ?? this.switchId,
      name: name ?? this.name,
      type: type ?? this.type,
      time: time ?? this.time,
      days: days ?? this.days,
      state: state ?? this.state,
      isEnabled: isEnabled ?? this.isEnabled,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      lastRun: lastRun ?? this.lastRun,
      nextRun: nextRun ?? this.nextRun,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
