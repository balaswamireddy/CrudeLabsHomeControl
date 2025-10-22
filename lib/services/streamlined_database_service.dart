import 'package:supabase_flutter/supabase_flutter.dart';

/// Streamlined database service for the production-ready schema
/// Home/Room/Timer IDs: UUID (auto-generated)
/// Board/Switch IDs: TEXT (hardcoded in ESP32: BOARD_001, BOARD_001_switch_1, etc.)
class StreamlinedDatabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============== USER PROFILE METHODS ==============

  /// Get current user's profile
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('user_profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return response;
  }

  /// Create user profile with custom ID generation
  Future<Map<String, dynamic>> createUserProfile({
    required String username,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final profile = {
      'id': user.id,
      'username': username.toLowerCase(),
      'email': user.email,
      'location': '',
    };

    final response = await _supabase
        .from('user_profiles')
        .insert(profile)
        .select()
        .single();

    return response;
  }

  // ============== HOME MANAGEMENT ==============

  /// Get all homes for current user (owned + shared)
  Future<List<Map<String, dynamic>>> getUserHomes() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      // Get owned homes
      final ownedHomes = await _supabase
          .from('homes')
          .select('*, rooms(*)')
          .eq('user_id', user.id)
          .order('created_at');

      // Get shared homes
      final sharedHomes = await _supabase
          .from('home_shares')
          .select('homes!inner(*, rooms(*)), can_control')
          .eq('shared_with_id', user.id);

      // Combine and format
      List<Map<String, dynamic>> allHomes = List.from(ownedHomes);
      for (var sharing in sharedHomes) {
        var home = sharing['homes'];
        home['is_shared'] = true;
        home['can_control'] = sharing['can_control'];
        allHomes.add(home);
      }

      return allHomes;
    } catch (e) {
      print('Error getting user homes: $e');
      return [];
    }
  }

  /// Create a new home (uses UUID auto-generation)
  Future<Map<String, dynamic>> createHome({
    required String name,
    String? description,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Create the home - database will auto-generate UUID
      final home = {
        'user_id': user.id,
        'name': name,
        'description': description,
        'is_active': true,
      };

      final createdHome = await _supabase
          .from('homes')
          .insert(home)
          .select()
          .single();

      return createdHome;
    } catch (e) {
      throw Exception('Failed to create home: $e');
    }
  }

  /// Delete a home
  Future<void> deleteHome(String homeId) async {
    await _supabase.from('homes').delete().eq('id', homeId);
  }

  // ============== ROOM MANAGEMENT ==============

  /// Get rooms for a home
  Future<List<Map<String, dynamic>>> getRoomsForHome(String homeId) async {
    try {
      final response = await _supabase
          .from('rooms')
          .select('*, boards(*)')
          .eq('home_id', homeId)
          .order('created_at');

      return response;
    } catch (e) {
      print('Error getting rooms for home: $e');
      return [];
    }
  }

  /// Create a new room (uses UUID auto-generation)
  Future<Map<String, dynamic>> createRoom({
    required String homeId,
    required String name,
    String? description,
  }) async {
    try {
      final room = {
        'home_id': homeId,
        'name': name,
        'description': description,
        'is_active': true,
      };

      final response = await _supabase
          .from('rooms')
          .insert(room)
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to create room: $e');
    }
  }

  /// Delete a room
  Future<void> deleteRoom(String roomId) async {
    await _supabase.from('rooms').delete().eq('id', roomId);
  }

  // ============== BOARD MANAGEMENT ==============

  /// Get boards for a room
  Future<List<Map<String, dynamic>>> getBoardsForRoom(String roomId) async {
    try {
      final response = await _supabase
          .from('boards')
          .select('*, switches(*)')
          .eq('room_id', roomId)
          .order('created_at');

      return response;
    } catch (e) {
      print('Error getting boards for room: $e');
      return [];
    }
  }

  /// Assign a discovered board to a room
  Future<Map<String, dynamic>> assignBoardToRoom({
    required String boardId, // Like "BOARD_001"
    required String roomId,
    required String name,
    String? description,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Get room info to find home_id
    final roomResponse = await _supabase
        .from('rooms')
        .select('home_id')
        .eq('id', roomId)
        .single();

    final homeId = roomResponse['home_id'] as String;

    // Create board record
    final board = {
      'id': boardId,
      'home_id': homeId,
      'room_id': roomId,
      'owner_id': user.id,
      'name': name,
      'status': 'online',
    };

    final createdBoard = await _supabase
        .from('boards')
        .insert(board)
        .select()
        .single();

    // Create 4 switches for this board
    final switches = <Map<String, dynamic>>[];
    for (int i = 1; i <= 4; i++) {
      switches.add({
        'id': '${boardId}_switch_$i',
        'board_id': boardId,
        'name': 'Switch $i',
        'position': i - 1, // 0-based position
        'state': false,
      });
    }

    await _supabase.from('switches').insert(switches);

    return createdBoard;
  }

  /// Update board status
  Future<void> updateBoardStatus(String boardId, String status) async {
    await _supabase
        .from('boards')
        .update({
          'status': status,
          'last_online': DateTime.now().toIso8601String(),
        })
        .eq('id', boardId);
  }

  /// Delete a board
  Future<void> deleteBoard(String boardId) async {
    await _supabase.from('boards').delete().eq('id', boardId);
  }

  // ============== SWITCH MANAGEMENT ==============

  /// Get switches for a board
  Future<List<Map<String, dynamic>>> getSwitchesForBoard(String boardId) async {
    final response = await _supabase
        .from('switches')
        .select('*')
        .eq('board_id', boardId)
        .order('position');

    return response;
  }

  /// Update switch state
  Future<void> updateSwitchState(String switchId, bool state) async {
    await _supabase
        .from('switches')
        .update({
          'state': state,
          'last_state_change': DateTime.now().toIso8601String(),
        })
        .eq('id', switchId);

    // Log the activity
    await logSwitchActivity(switchId, state ? 'turned_on' : 'turned_off');
  }

  /// Update switch details
  Future<void> updateSwitch({
    required String switchId,
    String? name,
    String? type,
    String? description,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (type != null) updates['type'] = type;
    if (description != null) updates['description'] = description;

    if (updates.isNotEmpty) {
      await _supabase.from('switches').update(updates).eq('id', switchId);
    }
  }

  // ============== TIMER MANAGEMENT ==============

  /// Get timers for a switch
  Future<List<Map<String, dynamic>>> getTimersForSwitch(String switchId) async {
    final response = await _supabase
        .from('timers')
        .select('*')
        .eq('switch_id', switchId)
        .eq('is_enabled', true)
        .order('created_at');

    return response;
  }

  /// Create a timer (uses UUID auto-generation)
  Future<Map<String, dynamic>> createTimer({
    required String switchId,
    required String time, // HH:MM format
    required bool action, // true = turn ON, false = turn OFF
    String? name,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final timer = {
      'switch_id': switchId,
      'user_id': user.id,
      'name': name ?? '${action ? 'Turn ON' : 'Turn OFF'} Timer',
      'time': time,
      'action': action,
      'is_enabled': true,
    };

    final response = await _supabase
        .from('timers')
        .insert(timer)
        .select()
        .single();

    return response;
  }

  /// Delete a timer
  Future<void> deleteTimer(String timerId) async {
    await _supabase.from('timers').delete().eq('id', timerId);
  }

  /// Toggle timer active status
  Future<void> toggleTimer(String timerId, bool isEnabled) async {
    await _supabase
        .from('timers')
        .update({'is_enabled': isEnabled})
        .eq('id', timerId);
  }

  // ============== ACTIVITY LOGGING ==============

  /// Log switch activity
  Future<void> logSwitchActivity(String switchId, String action) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final activity = {
      'switch_id': switchId,
      'user_id': user.id,
      'action': action,
      'triggered_by': 'manual',
      'user_name': user.email?.split('@')[0] ?? 'user',
    };

    await _supabase.from('device_logs').insert(activity);
  }

  /// Get activity logs for a switch
  Future<List<Map<String, dynamic>>> getSwitchActivity({
    required String switchId,
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('device_logs')
          .select('*, user_profiles(username)')
          .eq('switch_id', switchId)
          .order('created_at', ascending: false)
          .limit(limit);

      return response;
    } catch (e) {
      print('Error getting switch activity: $e');
      return [];
    }
  }

  /// Get activity logs for all switches in a home
  Future<List<Map<String, dynamic>>> getHomeActivity({
    required String homeId,
    int limit = 100,
  }) async {
    try {
      final response = await _supabase
          .from('device_logs')
          .select('''
            *, 
            switches(
              name,
              boards(
                name,
                rooms(
                  name,
                  home_id
                )
              )
            ),
            user_profiles(username)
          ''')
          .eq('switches.boards.rooms.home_id', homeId)
          .order('created_at', ascending: false)
          .limit(limit);

      return response;
    } catch (e) {
      print('Error getting home activity: $e');
      return [];
    }
  }

  // ============== HOME SHARING ==============

  /// Share a home with another user
  Future<Map<String, dynamic>> shareHome({
    required String homeId,
    required String shareWithUsername,
    required bool canControl,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Find the user to share with
    final targetUser = await _supabase
        .from('user_profiles')
        .select('id')
        .eq('username', shareWithUsername.toLowerCase())
        .maybeSingle();

    if (targetUser == null) {
      throw Exception('User with username "$shareWithUsername" not found');
    }

    final sharing = {
      'home_id': homeId,
      'owner_id': user.id,
      'shared_with_id': targetUser['id'],
      'can_control': canControl,
    };

    final response = await _supabase
        .from('home_shares')
        .insert(sharing)
        .select()
        .single();

    return response;
  }

  /// Get home sharing information for current user
  Future<List<Map<String, dynamic>>> getHomeShares() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _supabase
          .from('home_shares')
          .select('''
            *,
            homes(name),
            user_profiles!owner_id(username)
          ''')
          .eq('shared_with_id', user.id)
          .order('shared_at', ascending: false);

      return response;
    } catch (e) {
      print('Error getting home shares: $e');
      return [];
    }
  }

  /// Remove home sharing
  Future<void> removeHomeShare({
    required String homeId,
    required String sharedWithUserId,
  }) async {
    await _supabase
        .from('home_shares')
        .delete()
        .eq('home_id', homeId)
        .eq('shared_with_id', sharedWithUserId);
  }

  /// Get home access level for current user
  Future<String> getHomeAccessLevel(String homeId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 'none';

    // Check if user owns the home
    final ownedHome = await _supabase
        .from('homes')
        .select('id')
        .eq('id', homeId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (ownedHome != null) {
      return 'owner'; // Full permissions for owner
    }

    // Check shared permissions
    final sharing = await _supabase
        .from('home_shares')
        .select('can_control')
        .eq('home_id', homeId)
        .eq('shared_with_id', user.id)
        .maybeSingle();

    if (sharing != null) {
      return sharing['can_control'] ? 'control' : 'view';
    }

    return 'none'; // No access
  }

  // ============== BOARD DISCOVERY ==============

  /// Check if a board ID is available for assignment
  Future<bool> isBoardAvailable(String boardId) async {
    final response = await _supabase
        .from('boards')
        .select('id')
        .eq('id', boardId)
        .maybeSingle();

    return response == null; // Available if not found
  }

  /// Get board configuration info for ESP32
  Future<Map<String, dynamic>> getBoardConfigInfo() async {
    return {
      'supabase_url': 'https://nchshzvzjwlhquvjzhsi.supabase.co',
      'supabase_anon_key':
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5jaHNoenZ6andsaHF1dmp6aHNpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAwNzU4NDIsImV4cCI6MjA3NTY1MTg0Mn0.ASwxbx9m6a09MT8x31qvkSwy2yBLHAVhOMZ3jutLNS8',
      'api_version': 'v1',
      'realtime_enabled': true,
      'switch_table': 'switches',
      'board_table': 'boards',
      'log_table': 'device_logs',
    };
  }

  // ============== REAL-TIME SUBSCRIPTIONS ==============

  /// Subscribe to switch state changes for a board
  RealtimeChannel subscribeBoardSwitches(
    String boardId,
    Function(Map<String, dynamic>) onUpdate,
  ) {
    return _supabase
        .channel('board_$boardId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'switches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'board_id',
            value: boardId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }

  /// Subscribe to board status changes
  RealtimeChannel subscribeBoardStatus(
    String boardId,
    Function(Map<String, dynamic>) onUpdate,
  ) {
    return _supabase
        .channel('board_status_$boardId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'boards',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: boardId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }

  /// Subscribe to home sharing invitations
  RealtimeChannel subscribeHomeInvitations(
    Function(Map<String, dynamic>) onInvitation,
  ) {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    return _supabase
        .channel('home_invitations_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'home_shares',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shared_with_id',
            value: user.id,
          ),
          callback: (payload) => onInvitation(payload.newRecord),
        )
        .subscribe();
  }

  // ============== BOARD MANAGEMENT (ESP32 MANUAL ASSIGNMENT) ==============

  /// Validate and claim a board using hardcoded Board ID from ESP32
  /// Returns the board data if successful, throws exception if board is invalid/unavailable
  Future<Map<String, dynamic>> validateAndClaimBoard({
    required String boardId, // e.g., "BOARD_001"
    required String homeId,
    String? roomId,
    String? customName,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Step 1: Check if board exists in database (by TEXT id)
    final boardResponse = await _supabase
        .from('boards')
        .select('id, owner_id, status, name')
        .eq('id', boardId)
        .maybeSingle();

    // If board doesn't exist, create it (first time setup)
    if (boardResponse == null) {
      // Create new board entry with TEXT id
      await _supabase.from('boards').insert({
        'id': boardId, // Use TEXT id directly: BOARD_001
        'home_id': homeId, // FIXED: Set home_id
        'room_id': roomId, // FIXED: Set room_id (can be null for unassigned)
        'owner_id': user.id,
        'name': customName ?? 'Smart Switch $boardId',
        'status': 'online',
        'is_active': true,
      });

      print('Board created with id: $boardId');

      // Create 4 switches for the board
      for (var i = 0; i < 4; i++) {
        await _supabase.from('switches').insert({
          'id': '${boardId}_switch_${i + 1}', // TEXT id
          'board_id': boardId, // TEXT foreign key
          'name': 'Switch ${i + 1}',
          'position': i,
          'state': false,
          'is_enabled': true,
        });
      }

      // Reload with switches
      return await _supabase
          .from('boards')
          .select('*, switches(*)')
          .eq('id', boardId)
          .single();
    }

    // Step 2: Check if board is already assigned to someone else
    if (boardResponse['owner_id'] != null &&
        boardResponse['owner_id'] != user.id) {
      throw Exception(
        'This board is already assigned to another user. Board ID must be unique.',
      );
    }

    // Step 3: Claim/update the board (assign ownership and location)
    final updateData = {
      'home_id': homeId, // FIXED: Set home_id for existing boards
      'room_id': roomId, // FIXED: Set room_id for existing boards (can be null)
      'owner_id': user.id,
      'status': 'online',
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (customName != null) {
      updateData['name'] = customName;
    }

    await _supabase.from('boards').update(updateData).eq('id', boardId);

    // Return board with switches
    return await _supabase
        .from('boards')
        .select('*, switches(*)')
        .eq('id', boardId)
        .single();
  }

  /// Check if a board ID exists and is available for claiming
  Future<Map<String, dynamic>> checkBoardAvailability(String boardId) async {
    // Check by TEXT id directly
    final boardResponse = await _supabase
        .from('boards')
        .select('id, owner_id, status, name, last_online')
        .eq('id', boardId)
        .maybeSingle();

    if (boardResponse == null) {
      // Board doesn't exist yet - this is OK, user can claim it
      return {
        'exists': false,
        'available': true,
        'message': 'Board ready to be claimed!',
        'board_name': 'Smart Switch $boardId',
      };
    }

    final hasOwner = boardResponse['owner_id'] != null;

    String message;
    if (hasOwner) {
      message = 'Board already assigned to another user';
    } else {
      message = 'Board is available!';
    }

    return {
      'exists': true,
      'available': !hasOwner,
      'has_owner': hasOwner,
      'board_name': boardResponse['name'],
      'board_id': boardResponse['id'], // TEXT id like BOARD_001
      'last_online': boardResponse['last_online'],
      'message': message,
    };
  }

  /// Get all boards for a specific home
  Future<List<Map<String, dynamic>>> getBoardsForHome(String homeId) async {
    final response = await _supabase
        .from('boards')
        .select('*, switches(*)')
        .eq('home_id', homeId)
        .eq('is_active', true)
        .order('created_at');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Unassign a board (release ownership)
  Future<void> releaseBoard(String boardId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Verify user owns this board
    final board = await _supabase
        .from('boards')
        .select('owner_id')
        .eq('id', boardId)
        .single();

    if (board['owner_id'] != user.id) {
      throw Exception('You do not own this board');
    }

    // Release the board
    await _supabase
        .from('boards')
        .update({
          'owner_id': null,
          'home_id': null,
          'room_id': null,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', boardId);
  }
}
