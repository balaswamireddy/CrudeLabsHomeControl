import 'package:flutter/material.dart';
import '../services/streamlined_database_service.dart';
import '../models/streamlined_models.dart';
import '../widgets/glass_widgets.dart';

/// Screen for managing home sharing - inviting users and viewing shared homes
class HomeSharingScreen extends StatefulWidget {
  final String homeId;
  final String homeName;

  const HomeSharingScreen({
    super.key,
    required this.homeId,
    required this.homeName,
  });

  @override
  State<HomeSharingScreen> createState() => _HomeSharingScreenState();
}

class _HomeSharingScreenState extends State<HomeSharingScreen>
    with TickerProviderStateMixin {
  final StreamlinedDatabaseService _databaseService =
      StreamlinedDatabaseService();
  late TabController _tabController;

  // Controllers
  final _usernameController = TextEditingController();
  final _messageController = TextEditingController();

  // State
  List<HomeSharing> _pendingInvitations = [];
  List<String> _userPermissions = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;
  Set<String> _selectedPermissions = {'view', 'control'};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final accessLevel = await _databaseService.getHomeAccessLevel(
        widget.homeId,
      );
      final homeShares = await _databaseService.getHomeShares();

      setState(() {
        _userPermissions = accessLevel == 'owner'
            ? ['view', 'control', 'manage']
            : accessLevel == 'control'
            ? ['view', 'control']
            : accessLevel == 'view'
            ? ['view']
            : [];
        _pendingInvitations = homeShares
            .map((json) => HomeSharing.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _shareHome() async {
    if (_usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a username')));
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      await _databaseService.shareHome(
        homeId: widget.homeId,
        shareWithUsername: _usernameController.text.trim(),
        canControl: _selectedPermissions.contains('control'),
      );

      _usernameController.clear();
      _messageController.clear();
      _selectedPermissions = {'view', 'control'};

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitation sent successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to send invitation: $e';
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _removeHomeShare(String homeId, String sharedWithUserId) async {
    try {
      await _databaseService.removeHomeShare(
        homeId: homeId,
        sharedWithUserId: sharedWithUserId,
      );

      await _loadData(); // Refresh data

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Home share removed!'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to respond: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Share ${widget.homeName}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.share), text: 'Share Home'),
            Tab(icon: Icon(Icons.inbox), text: 'Invitations'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [_buildShareTab(), _buildInvitationsTab()],
              ),
      ),
    );
  }

  Widget _buildShareTab() {
    final canManage = _userPermissions.contains('manage');

    if (!canManage) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Access Denied',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'You need management permissions to share this home.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            '👥 Invite Someone to Your Home',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Share access to your smart home with family and friends. Choose what they can do.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 32),

          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Invite User',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: 'Enter their username',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      labelText: 'Message (Optional)',
                      hintText: 'Add a personal message',
                      prefixIcon: Icon(Icons.message),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Permissions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  _buildPermissionTile(
                    'view',
                    'View Only',
                    'Can see home status and switch states',
                    Icons.visibility,
                  ),
                  _buildPermissionTile(
                    'control',
                    'Control Switches',
                    'Can turn switches on/off and set timers',
                    Icons.touch_app,
                  ),
                  _buildPermissionTile(
                    'manage',
                    'Full Management',
                    'Can add/remove boards, share with others',
                    Icons.admin_panel_settings,
                  ),
                ],
              ),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSending ? null : _shareHome,
              child: _isSending
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Sending Invitation...'),
                      ],
                    )
                  : const Text('Send Invitation'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile(
    String permission,
    String title,
    String description,
    IconData icon,
  ) {
    final isSelected = _selectedPermissions.contains(permission);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) {
          setState(() {
            if (value == true) {
              _selectedPermissions.add(permission);
              // Auto-include view permission
              if (permission == 'control' || permission == 'manage') {
                _selectedPermissions.add('view');
              }
              // Auto-include control permission for manage
              if (permission == 'manage') {
                _selectedPermissions.add('control');
              }
            } else {
              _selectedPermissions.remove(permission);
              // Auto-remove dependent permissions
              if (permission == 'view') {
                _selectedPermissions.remove('control');
                _selectedPermissions.remove('manage');
              } else if (permission == 'control') {
                _selectedPermissions.remove('manage');
              }
            }
          });
        },
        title: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        subtitle: Text(description),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }

  Widget _buildInvitationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            '📬 Pending Invitations',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Home sharing invitations you\'ve received from others.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 32),

          if (_pendingInvitations.isEmpty) ...[
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    const Icon(Icons.inbox, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No Pending Invitations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You\'ll see invitations here when someone shares their home with you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pendingInvitations.length,
              itemBuilder: (context, index) {
                final invitation = _pendingInvitations[index];
                return _buildInvitationCard(invitation);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInvitationCard(HomeSharing invitation) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.home, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Home Invitation',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'PENDING',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              'From: ${invitation.sharedByUserId}', // Would show display name in real app
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),

            if (invitation.message != null &&
                invitation.message!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"${invitation.message}"',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 12),
            ],

            const Text(
              'Permissions:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: invitation.permissions.map((permission) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getPermissionDisplayName(permission),
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _removeHomeShare(
                      widget.homeId,
                      invitation.sharedWithUserId,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Remove'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => _removeHomeShare(
                      widget.homeId,
                      invitation.sharedWithUserId,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Revoke'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getPermissionDisplayName(String permission) {
    switch (permission) {
      case 'view':
        return 'View';
      case 'control':
        return 'Control';
      case 'manage':
        return 'Manage';
      default:
        return permission.toUpperCase();
    }
  }
}
