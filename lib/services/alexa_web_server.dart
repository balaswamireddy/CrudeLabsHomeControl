import 'dart:convert';
import 'dart:io';
import 'alexa_oauth_service.dart';
import 'alexa_device_discovery_service.dart';

// Simple HTTP server for Alexa OAuth and API endpoints
// Note: In production, you'd typically use a proper web framework
// This is a basic implementation for demonstration

class AlexaWebEndpoints {
  // OAuth authorization endpoint handler
  // GET /oauth/authorize?response_type=code&client_id=...&redirect_uri=...&state=...
  static Map<String, dynamic> handleOAuthAuthorize(
    Map<String, String> queryParams,
  ) {
    try {
      final responseType = queryParams['response_type'];
      final clientId = queryParams['client_id'];
      final redirectUri = queryParams['redirect_uri'];
      final state = queryParams['state'];

      if (responseType == null ||
          clientId == null ||
          redirectUri == null ||
          state == null) {
        return {
          'status': 400,
          'body': {
            'error': 'invalid_request',
            'error_description': 'Missing required parameters',
          },
        };
      }

      // Generate authorization code (you'll need to associate this with a user)
      final result = AlexaOAuthService.handleAuthorizeRequest(
        responseType: responseType,
        clientId: clientId,
        redirectUri: redirectUri,
        state: state,
        scope: queryParams['scope'],
      );

      if (result['error'] != null) {
        return {'status': 400, 'body': result};
      }

      // Return redirect URL
      return {'status': 302, 'redirect': result['redirect_url']};
    } catch (e) {
      return {
        'status': 500,
        'body': {
          'error': 'server_error',
          'error_description': 'Internal server error: ${e.toString()}',
        },
      };
    }
  }

  // OAuth token exchange endpoint handler
  // POST /oauth/token
  static Future<Map<String, dynamic>> handleOAuthToken(
    Map<String, String> formData,
  ) async {
    try {
      final result = await AlexaOAuthService.handleTokenRequest(
        grantType: formData['grant_type'] ?? '',
        code: formData['code'] ?? '',
        clientId: formData['client_id'] ?? '',
        clientSecret: formData['client_secret'] ?? '',
        redirectUri: formData['redirect_uri'] ?? '',
      );

      if (result['error'] != null) {
        return {'status': 400, 'body': result};
      }

      return {'status': 200, 'body': result};
    } catch (e) {
      return {
        'status': 500,
        'body': {
          'error': 'server_error',
          'error_description': 'Internal server error: ${e.toString()}',
        },
      };
    }
  }

  // User info endpoint handler
  // GET /oauth/userinfo
  static Future<Map<String, dynamic>> handleUserInfo(
    String? accessToken,
  ) async {
    try {
      if (accessToken == null || !accessToken.startsWith('ast_')) {
        return {
          'status': 401,
          'body': {
            'error': 'invalid_token',
            'error_description': 'Missing or invalid access token',
          },
        };
      }

      final user = await AlexaOAuthService.getUserFromToken(accessToken);

      if (user == null) {
        return {
          'status': 401,
          'body': {
            'error': 'invalid_token',
            'error_description': 'Invalid or expired access token',
          },
        };
      }

      return {'status': 200, 'body': user};
    } catch (e) {
      return {
        'status': 500,
        'body': {
          'error': 'server_error',
          'error_description': 'Internal server error: ${e.toString()}',
        },
      };
    }
  }

  // Handle Alexa Smart Home requests
  // POST /alexa/handle
  static Future<Map<String, dynamic>> handleAlexaRequest({
    required Map<String, dynamic> event,
    required String? accessToken,
  }) async {
    try {
      if (accessToken == null || !accessToken.startsWith('ast_')) {
        return {
          'status': 401,
          'body': {
            'event': {
              'header': {
                'namespace': 'Alexa',
                'name': 'ErrorResponse',
                'payloadVersion': '3',
                'messageId': DateTime.now().millisecondsSinceEpoch.toString(),
              },
              'payload': {
                'type': 'INVALID_AUTHORIZATION_CREDENTIAL',
                'message': 'Missing or invalid access token',
              },
            },
          },
        };
      }

      final result = await AlexaIntegrationService.handleAlexaRequest(
        event: event,
        accessToken: accessToken,
      );

      return {'status': 200, 'body': result};
    } catch (e) {
      return {
        'status': 500,
        'body': {
          'event': {
            'header': {
              'namespace': 'Alexa',
              'name': 'ErrorResponse',
              'payloadVersion': '3',
              'messageId': DateTime.now().millisecondsSinceEpoch.toString(),
            },
            'payload': {
              'type': 'INTERNAL_ERROR',
              'message': 'Internal server error: ${e.toString()}',
            },
          },
        },
      };
    }
  }

  // Health check endpoint handler
  static Map<String, dynamic> handleHealthCheck() {
    return {
      'status': 200,
      'body': {
        'status': 'healthy',
        'timestamp': DateTime.now().toIso8601String(),
        'service': 'Smart Switch Alexa Integration',
      },
    };
  }
}

// Simple HTTP server implementation
class SimpleAlexaServer {
  HttpServer? _server;

  Future<void> start({int port = 8080}) async {
    _server = await HttpServer.bind('0.0.0.0', port);
    print('🚀 Alexa Integration Server running on http://localhost:$port');

    await for (HttpRequest request in _server!) {
      _handleRequest(request);
    }
  }

  Future<void> stop() async {
    await _server?.close();
    print('🛑 Alexa Integration Server stopped');
  }

  void _handleRequest(HttpRequest request) async {
    // Add CORS headers
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add(
      'Access-Control-Allow-Methods',
      'GET, POST, OPTIONS',
    );
    request.response.headers.add(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization',
    );

    if (request.method == 'OPTIONS') {
      request.response.statusCode = 200;
      await request.response.close();
      return;
    }

    try {
      Map<String, dynamic> result;

      switch (request.uri.path) {
        case '/oauth/authorize':
          result = AlexaWebEndpoints.handleOAuthAuthorize(
            request.uri.queryParameters,
          );
          break;

        case '/oauth/token':
          final body = await utf8.decoder.bind(request).join();
          final formData = Uri.splitQueryString(body);
          result = await AlexaWebEndpoints.handleOAuthToken(formData);
          break;

        case '/oauth/userinfo':
          final authHeader = request.headers.value('authorization');
          final accessToken = authHeader?.startsWith('Bearer ') == true
              ? authHeader!.substring(7)
              : null;
          result = await AlexaWebEndpoints.handleUserInfo(accessToken);
          break;

        case '/alexa/handle':
          final authHeader = request.headers.value('authorization');
          final accessToken = authHeader?.startsWith('Bearer ') == true
              ? authHeader!.substring(7)
              : null;
          final bodyString = await utf8.decoder.bind(request).join();
          final event = json.decode(bodyString);
          result = await AlexaWebEndpoints.handleAlexaRequest(
            event: event,
            accessToken: accessToken,
          );
          break;

        case '/health':
          result = AlexaWebEndpoints.handleHealthCheck();
          break;

        default:
          result = {
            'status': 404,
            'body': {'error': 'Not found'},
          };
      }

      // Handle redirect
      if (result['redirect'] != null) {
        request.response.statusCode = result['status'];
        request.response.headers.add('Location', result['redirect']);
        await request.response.close();
        return;
      }

      // Send JSON response
      request.response.statusCode = result['status'];
      request.response.headers.contentType = ContentType.json;
      request.response.write(json.encode(result['body']));
      await request.response.close();
    } catch (e) {
      request.response.statusCode = 500;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        json.encode({'error': 'server_error', 'message': e.toString()}),
      );
      await request.response.close();
    }
  }
}

// Example usage:
// void main() async {
//   final server = SimpleAlexaServer();
//   await server.start(port: 8080);
// }
