import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../core/mqtt_service.dart';
import '../core/config_service.dart';
import '../models/mqtt_config.dart';

class MqttProvider extends ChangeNotifier {
  final MqttService _mqttService = MqttService();
  final ConfigService _configService = ConfigService();

  // Simple state management
  MqttConnectionState? _connectionState;
  String? _errorMessage;
  final Map<String, String> _topicValues = {};
  bool _autoConnectEnabled = true;
  String? _lastConnectedConfigId;

  // Stream subscription management
  StreamSubscription<MqttConnectionState>? _connectionStateSubscription;
  StreamSubscription<MqttReceivedMessage<MqttMessage>>? _messageSubscription;

  // Getters
  MqttConnectionState? get connectionState => _connectionState;
  String? get errorMessage => _errorMessage;
  Map<String, String> get topicValues => Map.from(_topicValues);
  bool get autoConnectEnabled => _autoConnectEnabled;
  String? get lastConnectedConfigId => _lastConnectedConfigId;
  bool get isConnected => _connectionState == MqttConnectionState.connected;

  // Streams for backward compatibility
  Stream<MqttConnectionState> get connectionStateStream =>
      _mqttService.connectionStateStream;
  Stream<MqttReceivedMessage<MqttMessage>> get messageStream =>
      _mqttService.messageStream;

  MqttProvider() {
    _setupListeners();
  }

  void _setupListeners() {
    // Setup listeners for MQTT service events

    // Listen to connection state changes
    _connectionStateSubscription = _mqttService.connectionStateStream.listen(
      (state) {
        // Connection state changed
        final previousState = _connectionState;
        _connectionState = state;

        // Clear error when connection succeeds
        if (state == MqttConnectionState.connected) {
          _errorMessage = null;
          _resubscribeToAllTopics();
        } else if (state == MqttConnectionState.disconnected) {
          // Clear all topic values when disconnected to mark remote state as undefined
          _topicValues.clear();

          // Set error message for failed connections
          if (previousState == MqttConnectionState.connecting) {
            _errorMessage = 'Failed to connect to MQTT broker';
          }
        }

        notifyListeners();
      },
      onError: (error) {
        // Connection state stream error occurred
        _errorMessage = 'Connection error: $error';
        notifyListeners();
      },
    );

    // Listen to incoming messages
    _messageSubscription = _mqttService.messageStream.listen(
      (message) {
        _handleIncomingMessage(message);
      },
      onError: (error) {
        // Message stream error occurred
      },
    );
  }

  void _handleIncomingMessage(MqttReceivedMessage<MqttMessage> message) {
    final topic = message.topic;
    String payload;

    try {
      if (message.payload is String) {
        payload = message.payload as String;
      } else if (message.payload is MqttPublishMessage) {
        final publishMessage = message.payload as MqttPublishMessage;
        final data = publishMessage.payload.message;
        payload = String.fromCharCodes(data);
      } else if (message.payload is List<int>) {
        payload = String.fromCharCodes(message.payload as List<int>);
      } else {
        payload = message.payload.toString();
      }

      _topicValues[topic] = payload;
      notifyListeners();
    } catch (e) {
      // Error processing incoming message
    }
  }

  Future<bool> connect(MqttConfig config) async {
    try {
      _errorMessage = null;
      notifyListeners();

      final success = await _mqttService.connect(config);

      if (success) {
        _lastConnectedConfigId = config.id;
        await _configService.setLastMqttConfigId(config.id);
      } else {
        _errorMessage = _getErrorMessage(config);
      }

      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Connection error: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  String _getErrorMessage(MqttConfig config) {
    String baseError = 'Failed to connect to ${config.host}:${config.port}';

    if (kIsWeb) {
      return '$baseError. Make sure your broker supports WebSocket connections on the specified port.';
    }

    return '$baseError. Check host, port, TLS settings, and credentials.';
  }

  Future<void> disconnect() async {
    try {
      await _mqttService.disconnect();
      _topicValues.clear();
      _lastConnectedConfigId = null;
      await _configService.setLastMqttConfigId(null);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Disconnect error: $e';
      notifyListeners();
    }
  }

  void subscribeToTopic(String topic, {int qos = 1}) {
    _mqttService.subscribeToTopic(topic, qos: qos);
  }

  void unsubscribeFromTopic(String topic) {
    _mqttService.unsubscribeFromTopic(topic);
    _topicValues.remove(topic);
    notifyListeners();
  }

  void publishMessage(String topic, String message, {int qos = 1, bool retain = false}) {
    _mqttService.publishMessage(topic, message, qos: qos, retain: retain);
  }

  String? getTopicValue(String topic) {
    return _topicValues[topic];
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Auto-connection methods
  Future<void> initializeAutoConnect() async {
    _autoConnectEnabled = await _configService.getAutoConnectEnabled();
    _lastConnectedConfigId = await _configService.getLastMqttConfigId();
  }

  Future<bool> autoConnect() async {
    await initializeAutoConnect();

    if (!_autoConnectEnabled || _lastConnectedConfigId == null) {
      return false;
    }

    return await connectToLastUsedConfig();
  }

  Future<bool> connectToLastUsedConfig() async {
    if (_lastConnectedConfigId == null) {
      return false;
    }

    final config = await _configService.getMqttConfigById(_lastConnectedConfigId!);
    if (config == null) {
      return false;
    }

    return await connect(config);
  }

  Future<void> setAutoConnectEnabled(bool enabled) async {
    _autoConnectEnabled = enabled;
    await _configService.setAutoConnectEnabled(enabled);

    // Enable/disable auto-reconnect in the service
    if (enabled) {
      _mqttService.enableAutoReconnect();
    } else {
      _mqttService.disableAutoReconnect();
    }

    notifyListeners();
  }

  Future<void> _resubscribeToAllTopics() async {
    try {
      // Clear cached values to get fresh data
      _topicValues.clear();

      // Get current dashboard to find all widget topics
      final dashboard = await _configService.getCurrentDashboard();

      if (dashboard != null) {
        for (final widget in dashboard.widgets) {
          if (widget.topic.isNotEmpty) {
            subscribeToTopic(widget.topic, qos: 1);
          }
        }

        // Brief delay to allow retained messages to arrive
        await Future.delayed(const Duration(milliseconds: 500));
        notifyListeners();
      }
    } catch (e) {
      // Error resubscribing to topics
    }
  }

  // Public method to refresh subscriptions (can be called when dashboard changes)
  Future<void> refreshSubscriptions() async {
    if (isConnected) {
      await _resubscribeToAllTopics();
    }
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _messageSubscription?.cancel();
    _mqttService.dispose();
    super.dispose();
  }
}