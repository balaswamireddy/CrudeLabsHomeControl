import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/board.dart';

class BoardService {
  final SupabaseClient _supabaseClient = Supabase.instance.client;

  Future<Board> addBoard({
    required String boardId,
    required String homeId,
    required String name,
  }) async {
    final response = await _supabaseClient
        .from('boards')
        .insert({
          'id': boardId,
          'home_id': homeId,
          'name': name,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return Board.fromJson(response);
  }

  Future<List<Board>> getBoardsByHomeId(String homeId) async {
    final response = await _supabaseClient
        .from('boards')
        .select()
        .eq('home_id', homeId)
        .order('created_at');

    return (response as List).map((board) => Board.fromJson(board)).toList();
  }

  Future<void> deleteBoard(String boardId) async {
    await _supabaseClient.from('boards').delete().eq('id', boardId);
  }
}
