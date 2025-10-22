import 'package:flutter/material.dart';
import '../services/streamlined_database_service.dart';
import '../models/streamlined_models.dart';
import '../widgets/glass_widgets.dart';
import 'package:intl/intl.dart';

/// Screen for viewing switch activity logs
class ActivityLogScreen extends StatefulWidget {
  final String homeId;
  final String homeName;
  final String? switchId; // Optional - show logs for specific switch

  const ActivityLogScreen({
    super.key,
    required this.homeId,
    required this.homeName,
    this.switchId,
  });

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final StreamlinedDatabaseService _databaseService =
      StreamlinedDatabaseService();

  // State
  List<SwitchActivity> _activities = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _filterType = 'all'; // all, manual, timer

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<Map<String, dynamic>> activitiesData;

      if (widget.switchId != null) {
        // Load activities for specific switch
        activitiesData = await _databaseService.getSwitchActivity(
          switchId: widget.switchId!,
          limit: 100,
        );
      } else {
        // Load activities for entire home
        activitiesData = await _databaseService.getHomeActivity(
          homeId: widget.homeId,
          limit: 200,
        );
      }

      final activities = activitiesData
          .map((data) => SwitchActivity.fromJson(data))
          .toList();

      setState(() {
        _activities = activities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load activities: $e';
        _isLoading = false;
      });
    }
  }

  List<SwitchActivity> get _filteredActivities {
    switch (_filterType) {
      case 'manual':
        return _activities.where((a) => a.isManualAction).toList();
      case 'timer':
        return _activities.where((a) => a.isTimerAction).toList();
      default:
        return _activities;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.switchId != null
              ? 'Switch Activity'
              : '${widget.homeName} Activity',
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActivities,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            _buildFilterRow(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? _buildErrorView()
                  : _buildActivityList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Text(
            'Filter:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All Activity'),
                  const SizedBox(width: 8),
                  _buildFilterChip('manual', 'Manual'),
                  const SizedBox(width: 8),
                  _buildFilterChip('timer', 'Timer'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filterType == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = value;
        });
      },
      selectedColor: Colors.blue.shade100,
      checkmarkColor: Colors.blue.shade800,
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadActivities,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityList() {
    final filteredActivities = _filteredActivities;

    if (filteredActivities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No Activity Found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _filterType == 'all'
                        ? 'No switch activity recorded yet.'
                        : 'No ${_filterType} activity found.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Group activities by date
    final groupedActivities = _groupActivitiesByDate(filteredActivities);

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: groupedActivities.length,
      itemBuilder: (context, index) {
        final dateGroup = groupedActivities[index];
        return _buildDateGroup(dateGroup);
      },
    );
  }

  List<ActivityDateGroup> _groupActivitiesByDate(
    List<SwitchActivity> activities,
  ) {
    final Map<String, List<SwitchActivity>> grouped = {};

    for (final activity in activities) {
      final dateKey = DateFormat('yyyy-MM-dd').format(activity.createdAt);
      grouped.putIfAbsent(dateKey, () => []).add(activity);
    }

    final groups = grouped.entries.map((entry) {
      final date = DateTime.parse(entry.key);
      return ActivityDateGroup(date: date, activities: entry.value);
    }).toList();

    // Sort by date descending (newest first)
    groups.sort((a, b) => b.date.compareTo(a.date));

    return groups;
  }

  Widget _buildDateGroup(ActivityDateGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            _formatDateHeader(group.date),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
        ),
        ...group.activities.map((activity) => _buildActivityTile(activity)),
        const SizedBox(height: 16),
      ],
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final activityDate = DateTime(date.year, date.month, date.day);

    if (activityDate == today) {
      return 'Today';
    } else if (activityDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('EEEE, MMM d').format(date);
    }
  }

  Widget _buildActivityTile(SwitchActivity activity) {
    return GlassCard(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: activity.isTurnedOn
                ? Colors.green.shade100
                : Colors.red.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            activity.isTurnedOn ? Icons.power : Icons.power_off,
            color: activity.isTurnedOn
                ? Colors.green.shade800
                : Colors.red.shade800,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                activity.switchName ?? 'Unknown Switch',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: activity.isTimerAction
                    ? Colors.purple.shade100
                    : Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                activity.isTimerAction ? 'TIMER' : 'MANUAL',
                style: TextStyle(
                  color: activity.isTimerAction
                      ? Colors.purple.shade800
                      : Colors.blue.shade800,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activity.actionDisplay,
              style: TextStyle(
                color: activity.isTurnedOn
                    ? Colors.green.shade700
                    : Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (activity.roomName != null &&
                    activity.boardName != null) ...[
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${activity.roomName} • ${activity.boardName}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  DateFormat('h:mm a').format(activity.createdAt),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: activity.userName != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person, size: 16),
                  Text(
                    activity.userName!,
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class ActivityDateGroup {
  final DateTime date;
  final List<SwitchActivity> activities;

  ActivityDateGroup({required this.date, required this.activities});
}
