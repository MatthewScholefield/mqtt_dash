import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/mqtt_config.dart';
import 'logger.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed
}

class MqttConnectionManager {
  MqttServerClient? _client;

  // Single source of truth for connection state
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String? _lastError;

  // Health monitoring
  Timer? _healthCheckTimer;
  DateTime? _lastActivity;
  static const Duration _healthCheckInterval = Duration(seconds: 30);

  // Auto-reconnect settings
  bool _autoReconnect = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 5);

  // Controllers
  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();
  final StreamController<MqttReceivedMessage<MqttMessage>> _messageController =
      StreamController<MqttReceivedMessage<MqttMessage>>.broadcast();

  // Public streams
  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  Stream<MqttReceivedMessage<MqttMessage>> get messageStream => _messageController.stream;

  // Public getters
  ConnectionStatus get status => _status;
  String? get lastError => _lastError;
  bool get isConnected => _status == ConnectionStatus.connected;
  bool get shouldAutoReconnect => _autoReconnect;

  MqttConnectionManager() {
    _startHealthMonitoring();
  }

  Future<bool> connect(MqttConfig config) async {
    if (_status == ConnectionStatus.connected) {
      await disconnect();
    }

    try {
      _setStatus(ConnectionStatus.connecting);
      _clearError();

      
      // Create client
      _client = MqttServerClient.withPort(config.host, config.clientId, config.port);

      // Configure based on platform
      if (kIsWeb) {
        _client!.useWebSocket = true;
        _client!.secure = false;
        _client!.port = config.port; // Ensure port is set for WebSocket
      } else {
        _client!.useWebSocket = false;
        _client!.secure = config.useTls;
      }

      // Set up connection parameters
      _client!.keepAlivePeriod = 60;
      _client!.autoReconnect = false; // We'll handle reconnect ourselves
      _client!.resubscribeOnAutoReconnect = false; // We'll handle resubscription
      _client!.logging(on: kDebugMode);

      // Set up event handlers
      _setupEventHandlers(config);

      // Configure authentication
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(config.clientId)
          .startClean() // Start clean session
          .withWillQos(MqttQos.atLeastOnce);

      if (config.username.isNotEmpty && config.password.isNotEmpty) {
        connMessage.authenticateAs(config.username, config.password);
      }

      _client!.connectionMessage = connMessage;

      // Attempt connection
      await _client!.connect();

      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        _setupMessageHandling();
        _onConnectionEstablished();
        return true;
      } else {
        throw Exception('Connection failed: ${_client!.connectionStatus!.returnCode}');
      }

    } catch (e) {
      _onConnectionFailed(e.toString());
      return false;
    }
  }

  void _setupEventHandlers(MqttConfig config) {
    _client!.onConnected = () {
      _onConnectionEstablished();
    };

    _client!.onDisconnected = () {
      _onDisconnected();
    };


    _client!.onAutoReconnect = () {
      // Auto-reconnect triggered by library
    };

    // Handle connection status changes
    _client!.updates?.listen((_) {
      _updateLastActivity();
    });

    // Handle errors
    _client!.onSubscribed = (topic) {
      // Successfully subscribed to topic
    };
  }

  void _setupMessageHandling() {
    _client!.updates?.listen(
      (List<MqttReceivedMessage<MqttMessage>> messages) {
        for (final message in messages) {
          _messageController.add(message);
          _updateLastActivity();
        }
      },
      onError: (error) {
        _onConnectionFailed('Stream error: $error');
      },
      onDone: () {
        _onDisconnected();
      },
    );
  }

  void _onConnectionEstablished() {
    _status = ConnectionStatus.connected;
    _reconnectAttempts = 0;
    _clearError();
    _updateLastActivity();
    _statusController.add(ConnectionStatus.connected);
    AppLogger.info('MQTT connection established successfully');
  }

  void _onDisconnected() {
    if (_status != ConnectionStatus.disconnected) {
      AppLogger.warning('MQTT connection lost unexpectedly');
      _handleUnexpectedDisconnect();
    }
  }

  void _handleUnexpectedDisconnect() {
    _setStatus(ConnectionStatus.reconnecting);

    if (_autoReconnect && _reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      AppLogger.warning('MQTT reconnection attempt $_reconnectAttempts/$_maxReconnectAttempts');

      Future.delayed(_reconnectDelay, () async {
        if (_status == ConnectionStatus.reconnecting) {
          // Try to reconnect with last known config
          // Note: We'll need to store the config for this to work
          _statusController.add(ConnectionStatus.reconnecting);
        }
      });
    } else {
      _setStatus(ConnectionStatus.failed);
      _setError('Connection lost and max reconnect attempts reached');
      AppLogger.error('MQTT connection failed - max reconnect attempts reached');
    }
  }

  void _onConnectionFailed(String error) {
    _setStatus(ConnectionStatus.failed);
    _setError(error);
    AppLogger.error('MQTT connection failed', error);
  }

  Future<void> disconnect() async {
    _autoReconnect = false;
    _healthCheckTimer?.cancel();

    if (_client != null) {
      try {
        if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
          _client!.disconnect();
        }
      } catch (e) {
        // Error during disconnect
      }
      _client = null;
    }

    _setStatus(ConnectionStatus.disconnected);
    _clearError();
  }

  void subscribeToTopic(String topic, {int qos = 1}) {
    if (_isConnectedAndReady()) {
      try {
        _client!.subscribe(topic, MqttQos.values[qos]);
      } catch (e) {
        // Failed to subscribe to topic
      }
    }
  }

  void unsubscribeFromTopic(String topic) {
    if (_isConnectedAndReady()) {
      try {
        _client!.unsubscribe(topic);
      } catch (e) {
        // Failed to unsubscribe from topic
      }
    }
  }

  void publishMessage(String topic, String message, {int qos = 1, bool retain = false}) {
    if (_isConnectedAndReady()) {
      try {
        final builder = MqttClientPayloadBuilder();
        builder.addString(message);

        _client!.publishMessage(
          topic,
          MqttQos.values[qos],
          builder.payload!,
          retain: retain,
        );

        _updateLastActivity();
      } catch (e) {
        _onPublishFailed();
      }
    } else {
      _onPublishFailed();
    }
  }

  void _onPublishFailed() {
    if (_status == ConnectionStatus.connected) {
      _handleUnexpectedDisconnect();
    }
  }

  bool _isConnectedAndReady() {
    return _client != null &&
           _status == ConnectionStatus.connected &&
           _client!.connectionStatus?.state == MqttConnectionState.connected;
  }

  void _startHealthMonitoring() {
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (_) {
      _performHealthCheck();
    });
  }

  void _performHealthCheck() {
    if (_status != ConnectionStatus.connected) return;

    final now = DateTime.now();

    // Check if we've had no activity for too long
    if (_lastActivity != null &&
        now.difference(_lastActivity!) > _healthCheckInterval * 2) {
      AppLogger.warning('MQTT connection health check failed - no recent activity');
      _handleUnexpectedDisconnect();
      return;
    }

    // Check client connection status
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      AppLogger.warning('MQTT connection health check failed - client not connected');
      _handleUnexpectedDisconnect();
    }
  }

  void _updateLastActivity() {
    _lastActivity = DateTime.now();
  }

  void _setStatus(ConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(_status);
    }
  }

  void _setError(String error) {
    _lastError = error;
  }

  void _clearError() {
    _lastError = null;
  }

  void enableAutoReconnect() {
    _autoReconnect = true;
    if (_status == ConnectionStatus.failed) {
      _handleUnexpectedDisconnect();
    }
  }

  void disableAutoReconnect() {
    _autoReconnect = false;
  }

  Future<void> dispose() async {
    _healthCheckTimer?.cancel();
    await disconnect();

    await _statusController.close();
    await _messageController.close();
  }
}