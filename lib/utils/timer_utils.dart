import 'package:flutter/material.dart';
import '../models/timer_model.dart';

class TimerUtils {
  static String getDescription(SwitchTimer timer) {
    if (timer.type == TimerType.scheduled) {
      return '${timer.time} on ${timer.days.join(', ')}';
    } else if (timer.type == TimerType.prescheduled) {
      if (timer.scheduledDate != null) {
        return '${timer.time} on ${timer.scheduledDate.toString().split(' ')[0]}';
      }
      return timer.time;
    } else {
      // TimerType.countdown
      final minutes = int.tryParse(timer.time) ?? 0;
      return '${minutes ~/ 60}h ${minutes % 60}m';
    }
  }

  static IconData getIcon(TimerType type) {
    if (type == TimerType.scheduled) {
      return Icons.schedule;
    } else if (type == TimerType.prescheduled) {
      return Icons.event;
    } else {
      return Icons.timer;
    }
  }
}
