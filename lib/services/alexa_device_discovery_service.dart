import 'package:supabase_flutter/supabase_flutter.dart';
import 'alexa_oauth_service.dart';

class AlexaDeviceDiscoveryService {
  // Get user's switches formatted as Alexa devices
  static Future<Map<String, dynamic>> getDevicesForUser(String userId) async {
    try {
      // Get user's switches from Supabase
      final response = await Supabase.instance.client
          .from('switches')
          .select('*')
          .eq('user_id', userId);

      final switches = response as List<dynamic>;

      // Convert switches to Alexa device format
      final endpoints = switches
          .map((switchData) => _switchToAlexaDevice(switchData))
          .toList();

      return {
        'event': {
          'header': {
            'namespace': 'Alexa.Discovery',
            'name': 'Discover.Response',
            'payloadVersion': '3',
            'messageId': _generateMessageId(),
          },
          'payload': {'endpoints': endpoints},
        },
      };
    } catch (e) {
      print('Error getting devices for user: $e');
      return _buildErrorResponse(
        'INTERNAL_ERROR',
        'Failed to discover devices',
      );
    }
  }

  // Convert a switch record to Alexa device format
  static Map<String, dynamic> _switchToAlexaDevice(
    Map<String, dynamic> switchData,
  ) {
    final switchId = switchData['id'].toString();
    final switchName = switchData['name'] ?? 'Unnamed Switch';
    final location = switchData['location'] ?? '';

    // Create friendly name (combine location + name if available)
    String friendlyName = switchName;
    if (location.isNotEmpty &&
        !switchName.toLowerCase().contains(location.toLowerCase())) {
      friendlyName = '$location $switchName';
    }

    return {
      'endpointId': 'switch_$switchId',
      'manufacturerName': 'Smart Switch App',
      'friendlyName': friendlyName,
      'description': 'Smart switch controlled via mobile app',
      'displayCategories': ['SWITCH'],
      'cookie': {'switch_id': switchId, 'user_id': switchData['user_id']},
      'capabilities': [
        {'type': 'AlexaInterface', 'interface': 'Alexa', 'version': '3'},
        {
          'type': 'AlexaInterface',
          'interface': 'Alexa.PowerController',
          'version': '3',
          'properties': {
            'supported': [
              {'name': 'powerState'},
            ],
            'proactivelyReported': true,
            'retrievable': true,
          },
        },
        {
          'type': 'AlexaInterface',
          'interface': 'Alexa.EndpointHealth',
          'version': '3',
          'properties': {
            'supported': [
              {'name': 'connectivity'},
            ],
            'proactivelyReported': true,
            'retrievable': true,
          },
        },
      ],
      'connections': [
        {'type': 'TCP_IP', 'macAddress': _generateMacAddress(switchId)},
      ],
    };
  }

  // Handle power control commands (TurnOn, TurnOff)
  static Future<Map<String, dynamic>> handlePowerControl({
    required String directive,
    required String endpointId,
    required String userId,
  }) async {
    try {
      // Extract switch ID from endpoint ID
      final switchId = endpointId.replaceFirst('switch_', '');

      // Determine the new power state
      bool newPowerState;
      switch (directive) {
        case 'TurnOn':
          newPowerState = true;
          break;
        case 'TurnOff':
          newPowerState = false;
          break;
        default:
          return _buildErrorResponse(
            'INVALID_DIRECTIVE',
            'Unsupported directive: $directive',
          );
      }

      // Update switch state in Supabase
      final updateResponse = await Supabase.instance.client
          .from('switches')
          .update({
            'is_on': newPowerState,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', switchId)
          .eq('user_id', userId)
          .select()
          .maybeSingle();

      if (updateResponse == null) {
        return _buildErrorResponse(
          'NO_SUCH_ENDPOINT',
          'Switch not found or access denied',
        );
      }

      // Return success response
      return {
        'event': {
          'header': {
            'namespace': 'Alexa',
            'name': 'Response',
            'payloadVersion': '3',
            'messageId': _generateMessageId(),
            'correlationToken': _generateCorrelationToken(),
          },
          'endpoint': {'endpointId': endpointId},
          'payload': {},
        },
        'context': {
          'properties': [
            {
              'namespace': 'Alexa.PowerController',
              'name': 'powerState',
              'value': newPowerState ? 'ON' : 'OFF',
              'timeOfSample': DateTime.now().toIso8601String(),
              'uncertaintyInMilliseconds': 500,
            },
          ],
        },
      };
    } catch (e) {
      print('Error handling power control: $e');
      return _buildErrorResponse(
        'INTERNAL_ERROR',
        'Failed to control switch: ${e.toString()}',
      );
    }
  }

  // Handle state reporting (when Alexa asks "Is the light on?")
  static Future<Map<String, dynamic>> handleStateReport({
    required String endpointId,
    required String userId,
  }) async {
    try {
      // Extract switch ID from endpoint ID
      final switchId = endpointId.replaceFirst('switch_', '');

      // Get current switch state from Supabase
      final response = await Supabase.instance.client
          .from('switches')
          .select('is_on, updated_at')
          .eq('id', switchId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return _buildErrorResponse(
          'NO_SUCH_ENDPOINT',
          'Switch not found or access denied',
        );
      }

      final isOn = response['is_on'] ?? false;
      final updatedAt =
          response['updated_at'] ?? DateTime.now().toIso8601String();

      return {
        'event': {
          'header': {
            'namespace': 'Alexa',
            'name': 'StateReport',
            'payloadVersion': '3',
            'messageId': _generateMessageId(),
            'correlationToken': _generateCorrelationToken(),
          },
          'endpoint': {'endpointId': endpointId},
          'payload': {},
        },
        'context': {
          'properties': [
            {
              'namespace': 'Alexa.PowerController',
              'name': 'powerState',
              'value': isOn ? 'ON' : 'OFF',
              'timeOfSample': updatedAt,
              'uncertaintyInMilliseconds': 500,
            },
            {
              'namespace': 'Alexa.EndpointHealth',
              'name': 'connectivity',
              'value': {'value': 'OK'},
              'timeOfSample': DateTime.now().toIso8601String(),
              'uncertaintyInMilliseconds': 0,
            },
          ],
        },
      };
    } catch (e) {
      print('Error handling state report: $e');
      return _buildErrorResponse(
        'INTERNAL_ERROR',
        'Failed to get switch state: ${e.toString()}',
      );
    }
  }

  // Helper methods
  static String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (999 * (DateTime.now().microsecond / 1000000))).round()}';
  }

  static String _generateCorrelationToken() {
    return 'corr_${DateTime.now().millisecondsSinceEpoch}';
  }

  static String _generateMacAddress(String switchId) {
    // Generate a consistent MAC address based on switch ID
    final bytes = switchId.codeUnits;
    final mac = List.generate(
      6,
      (i) => (bytes[i % bytes.length] + i * 17) % 256,
    );
    return mac
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(':')
        .toUpperCase();
  }

  static Map<String, dynamic> _buildErrorResponse(
    String errorType,
    String errorMessage,
  ) {
    return {
      'event': {
        'header': {
          'namespace': 'Alexa',
          'name': 'ErrorResponse',
          'payloadVersion': '3',
          'messageId': _generateMessageId(),
        },
        'payload': {'type': errorType, 'message': errorMessage},
      },
    };
  }
}

// Service for managing Alexa integration
class AlexaIntegrationService {
  // Main handler for all Alexa requests
  static Future<Map<String, dynamic>> handleAlexaRequest({
    required Map<String, dynamic> event,
    required String accessToken,
  }) async {
    try {
      // Get user from access token
      final user = await AlexaOAuthService.getUserFromToken(accessToken);
      if (user == null) {
        return AlexaDeviceDiscoveryService._buildErrorResponse(
          'INVALID_AUTHORIZATION_CREDENTIAL',
          'Invalid access token',
        );
      }

      final userId = user['user_id'];
      final directive = event['directive'];
      final header = directive['header'];
      final namespace = header['namespace'];
      final name = header['name'];

      // Route request based on namespace and name
      switch (namespace) {
        case 'Alexa.Discovery':
          if (name == 'Discover') {
            return await AlexaDeviceDiscoveryService.getDevicesForUser(userId);
          }
          break;

        case 'Alexa.PowerController':
          if (name == 'TurnOn' || name == 'TurnOff') {
            final endpointId = directive['endpoint']['endpointId'];
            return await AlexaDeviceDiscoveryService.handlePowerControl(
              directive: name,
              endpointId: endpointId,
              userId: userId,
            );
          }
          break;

        case 'Alexa':
          if (name == 'ReportState') {
            final endpointId = directive['endpoint']['endpointId'];
            return await AlexaDeviceDiscoveryService.handleStateReport(
              endpointId: endpointId,
              userId: userId,
            );
          }
          break;
      }

      return AlexaDeviceDiscoveryService._buildErrorResponse(
        'INVALID_DIRECTIVE',
        'Unsupported directive: $namespace.$name',
      );
    } catch (e) {
      print('Error handling Alexa request: $e');
      return AlexaDeviceDiscoveryService._buildErrorResponse(
        'INTERNAL_ERROR',
        'Internal server error: ${e.toString()}',
      );
    }
  }
}
