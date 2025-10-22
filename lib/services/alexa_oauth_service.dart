import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class AlexaOAuthService {
  static const String _clientId = 'smart_switch_alexa_skill';
  static const String _clientSecret = 'sk_smart_switch_2024_alexa_integration';

  // OAuth endpoint: /oauth/authorize
  static Map<String, dynamic> handleAuthorizeRequest({
    required String responseType,
    required String clientId,
    required String redirectUri,
    required String state,
    String? scope,
  }) {
    // Validate client ID
    if (clientId != _clientId) {
      return {
        'error': 'invalid_client',
        'error_description': 'Invalid client ID',
      };
    }

    // Validate response type
    if (responseType != 'code') {
      return {
        'error': 'unsupported_response_type',
        'error_description': 'Only authorization code flow is supported',
      };
    }

    // Generate authorization code
    final authCode = _generateAuthCode();

    // Store auth code temporarily (you'll implement this in Supabase)
    _storeAuthCode(authCode, clientId, redirectUri, scope);

    return {
      'success': true,
      'redirect_url': '$redirectUri?code=$authCode&state=$state',
    };
  }

  // OAuth endpoint: /oauth/token
  static Future<Map<String, dynamic>> handleTokenRequest({
    required String grantType,
    required String code,
    required String clientId,
    required String clientSecret,
    required String redirectUri,
  }) async {
    try {
      // Validate client credentials
      if (clientId != _clientId || clientSecret != _clientSecret) {
        return {
          'error': 'invalid_client',
          'error_description': 'Invalid client credentials',
        };
      }

      // Validate grant type
      if (grantType != 'authorization_code') {
        return {
          'error': 'unsupported_grant_type',
          'error_description': 'Only authorization code grant is supported',
        };
      }

      // Validate and retrieve auth code
      final authData = await _validateAuthCode(code);
      if (authData == null) {
        return {
          'error': 'invalid_grant',
          'error_description': 'Invalid or expired authorization code',
        };
      }

      // Generate access token
      final accessToken = _generateAccessToken();
      final refreshToken = _generateRefreshToken();

      // Store tokens in Supabase
      await _storeTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: authData['user_id'],
        clientId: clientId,
        scope: authData['scope'],
      );

      return {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_type': 'Bearer',
        'expires_in': 3600, // 1 hour
        'scope': authData['scope'] ?? 'read write',
      };
    } catch (e) {
      return {
        'error': 'server_error',
        'error_description': 'Internal server error: ${e.toString()}',
      };
    }
  }

  // Get user info from access token
  static Future<Map<String, dynamic>?> getUserFromToken(
    String accessToken,
  ) async {
    try {
      final response = await Supabase.instance.client
          .from('alexa_tokens')
          .select('user_id, users(id, email, full_name)')
          .eq('access_token', accessToken)
          .maybeSingle();

      if (response == null) return null;

      final userData = response['users'];
      return {
        'user_id': userData['id'],
        'email': userData['email'],
        'name': userData['full_name'],
      };
    } catch (e) {
      print('Error getting user from token: $e');
      return null;
    }
  }

  // Validate access token
  static Future<bool> validateToken(String accessToken) async {
    try {
      final response = await Supabase.instance.client
          .from('alexa_tokens')
          .select('expires_at')
          .eq('access_token', accessToken)
          .maybeSingle();

      if (response == null) return false;

      final expiresAt = DateTime.parse(response['expires_at']);
      return DateTime.now().isBefore(expiresAt);
    } catch (e) {
      print('Error validating token: $e');
      return false;
    }
  }

  // Helper methods
  static String _generateAuthCode() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(
      32,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  static String _generateAccessToken() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return 'ast_${List.generate(48, (index) => chars[random.nextInt(chars.length)]).join()}';
  }

  static String _generateRefreshToken() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return 'rst_${List.generate(48, (index) => chars[random.nextInt(chars.length)]).join()}';
  }

  static void _storeAuthCode(
    String code,
    String clientId,
    String redirectUri,
    String? scope,
  ) {
    // Implement temporary storage of auth codes
    // In production, store in Supabase with short expiration
    Supabase.instance.client.from('alexa_auth_codes').insert({
      'code': code,
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': scope ?? 'read write',
      'expires_at': DateTime.now().add(Duration(minutes: 10)).toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<Map<String, dynamic>?> _validateAuthCode(String code) async {
    try {
      final response = await Supabase.instance.client
          .from('alexa_auth_codes')
          .select('*')
          .eq('code', code)
          .maybeSingle();

      if (response == null) return null;

      final expiresAt = DateTime.parse(response['expires_at']);
      if (DateTime.now().isAfter(expiresAt)) {
        // Delete expired code
        await Supabase.instance.client
            .from('alexa_auth_codes')
            .delete()
            .eq('code', code);
        return null;
      }

      // Delete used code
      await Supabase.instance.client
          .from('alexa_auth_codes')
          .delete()
          .eq('code', code);

      return response;
    } catch (e) {
      print('Error validating auth code: $e');
      return null;
    }
  }

  static Future<void> _storeTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String clientId,
    required String scope,
  }) async {
    await Supabase.instance.client.from('alexa_tokens').insert({
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'user_id': userId,
      'client_id': clientId,
      'scope': scope,
      'expires_at': DateTime.now().add(Duration(hours: 1)).toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}

// OAuth endpoints for your app
class AlexaOAuthEndpoints {
  // GET /oauth/authorize
  static Map<String, dynamic> authorize({
    required Map<String, String> queryParams,
    required String userId, // From your app's authentication
  }) {
    final responseType = queryParams['response_type'];
    final clientId = queryParams['client_id'];
    final redirectUri = queryParams['redirect_uri'];
    final state = queryParams['state'];
    final scope = queryParams['scope'];

    if (responseType == null ||
        clientId == null ||
        redirectUri == null ||
        state == null) {
      return {
        'error': 'invalid_request',
        'error_description': 'Missing required parameters',
      };
    }

    // Add user ID to the auth code data
    final result = AlexaOAuthService.handleAuthorizeRequest(
      responseType: responseType,
      clientId: clientId,
      redirectUri: redirectUri,
      state: state,
      scope: scope,
    );

    // If successful, store the user ID with the auth code
    if (result['success'] == true) {
      final authCode = result['redirect_url'].split('code=')[1].split('&')[0];
      _associateAuthCodeWithUser(authCode, userId);
    }

    return result;
  }

  // POST /oauth/token
  static Future<Map<String, dynamic>> token(Map<String, dynamic> body) async {
    return await AlexaOAuthService.handleTokenRequest(
      grantType: body['grant_type'] ?? '',
      code: body['code'] ?? '',
      clientId: body['client_id'] ?? '',
      clientSecret: body['client_secret'] ?? '',
      redirectUri: body['redirect_uri'] ?? '',
    );
  }

  // GET /oauth/userinfo
  static Future<Map<String, dynamic>?> userInfo(String accessToken) async {
    return await AlexaOAuthService.getUserFromToken(accessToken);
  }

  static void _associateAuthCodeWithUser(String authCode, String userId) {
    // Update the auth code record with user ID
    Supabase.instance.client
        .from('alexa_auth_codes')
        .update({'user_id': userId})
        .eq('code', authCode);
  }
}
