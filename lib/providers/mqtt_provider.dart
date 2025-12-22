import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../core/mqtt_service.dart';
import '../core/config_service.dart';
import '../models/mqtt_config.dart';
import '../models/dashboard.dart';

/// Manages multiple MQTT connections keyed by config ID.
/// Each dashboard can have its own MQTT broker configuration.
class MqttProvider extends ChangeNotifier {
  final ConfigService _configService = ConfigService();

  /// Connection pool: configId -> MqttService
  final Map<String, MqttService> _connections = {};

  /// Connection states: configId -> ConnectionState
  final Map<String, MqttConnectionState> _connectionStates = {};

  /// Error messages: configId -> error message
  final Map<String, String> _errorMessages = {};

  /// Topic values: topic -> payload (aggregated from all connections)
  final Map<String, String> _topicValues = {};

  /// Stream subscriptions: configId -> (stateSubscription, messageSubscription)
  final Map<String, _ConnectionSubscriptions> _subscriptions = {};

  /// Dashboard reference for determining current config
  Dashboard? _currentDashboard;

  bool _autoConnectEnabled = true;

  // Getters
  Map<String, MqttConnectionState> get connectionStates => Map.unmodifiable(_connectionStates);
  Map<String, String> get errorMessages => Map.unmodifiable(_errorMessages);
  Map<String, String> get topicValues => Map.from(_topicValues);
  bool get autoConnectEnabled => _autoConnectEnabled;

  /// Get connection state for specific config
  MqttConnectionState? getConnectionState(String configId) {
    return _connectionStates[configId];
  }

  /// Get connection state for current dashboard's broker
  MqttConnectionState? get currentConnectionState {
    if (_currentDashboard == null || _currentDashboard!.mqttConfigId.isEmpty) {
      return null;
    }
    return _connectionStates[_currentDashboard!.mqttConfigId];
  }

  /// Get error message for specific config
  String? getErrorMessage(String configId) {
    return _errorMessages[configId];
  }

  /// Get error message for current dashboard's broker
  String? get currentErrorMessage {
    if (_currentDashboard == null || _currentDashboard!.mqttConfigId.isEmpty) {
      return null;
    }
    return _errorMessages[_currentDashboard!.mqttConfigId];
  }

  /// Check if specific config is connected
  bool isConfigConnected(String configId) {
    return _connectionStates[configId] == MqttConnectionState.connected;
  }

  /// Check if current dashboard's broker is connected
  bool get isCurrentConnected {
    final state = currentConnectionState;
    return state == MqttConnectionState.connected;
  }

  /// Get all connected config IDs
  Set<String> get connectedConfigIds {
    return _connectionStates.entries
        .where((e) => e.value == MqttConnectionState.connected)
        .map((e) => e.key)
        .toSet();
  }

  MqttProvider();

  /// Set the current dashboard (called by DashboardScreen)
  void setCurrentDashboard(Dashboard? dashboard) {
    _currentDashboard = dashboard;
    notifyListeners();
  }

  /// Connect to a specific MQTT broker configuration
  Future<bool> connect(MqttConfig config) async {
    final configId = config.id;

    try {
      _errorMessages.remove(configId);
      notifyListeners();

      // If already connected to this config, disconnect first
      if (_connections.containsKey(configId)) {
        await disconnectConfig(configId);
      }

      final service = MqttService();
      _connections[configId] = service;
      _connectionStates[configId] = MqttConnectionState.connecting;
      notifyListeners();

      final success = await service.connect(config);

      if (success) {
        _connectionStates[configId] = MqttConnectionState.connected;
        _setupConnectionListeners(configId, service);
        await _resubscribeToTopicsForConfig(configId);
        await _configService.setLastMqttConfigId(configId);
      } else {
        _errorMessages[configId] = _getErrorMessage(config);
        _connectionStates[configId] = MqttConnectionState.disconnected;
        // Clean up service but keep error state for UI
        await _cleanupServiceOnly(configId);
      }

      notifyListeners();
      return success;
    } catch (e) {
      _errorMessages[configId] = 'Connection error: ${e.toString()}';
      _connectionStates[configId] = MqttConnectionState.disconnected;
      // Clean up service but keep error state for UI
      await _cleanupServiceOnly(configId);
      notifyListeners();
      return false;
    }
  }

  /// Disconnect a specific config
  Future<void> disconnectConfig(String configId) async {
    await _cleanupConnection(configId);
    notifyListeners();
  }

  /// Disconnect all connections
  Future<void> disconnectAll() async {
    final configIds = _connections.keys.toList();
    for (final configId in configIds) {
      await _cleanupConnection(configId);
    }
    _topicValues.clear();
    notifyListeners();
  }

  String _getErrorMessage(MqttConfig config) {
    String baseError = 'Failed to connect to ${config.host}:${config.port}';

    if (kIsWeb) {
      return '$baseError. Make sure your broker supports WebSocket connections on the specified port.';
    }

    return '$baseError. Check host, port, TLS settings, and credentials.';
  }

  void _setupConnectionListeners(String configId, MqttService service) {
    final stateSubscription = service.connectionStateStream.listen(
      (state) {
        final previousState = _connectionStates[configId];
        _connectionStates[configId] = state;

        if (state == MqttConnectionState.connected) {
          _errorMessages.remove(configId);
          _resubscribeToTopicsForConfig(configId);
        } else if (state == MqttConnectionState.disconnected) {
          if (previousState == MqttConnectionState.connecting) {
            _errorMessages[configId] = 'Failed to connect to MQTT broker';
          }
        }

        notifyListeners();
      },
      onError: (error) {
        _errorMessages[configId] = 'Connection error: $error';
        _connectionStates[configId] = MqttConnectionState.disconnected;
        notifyListeners();
      },
    );

    final messageSubscription = service.messageStream.listen(
      (message) {
        _handleIncomingMessage(message);
      },
      onError: (error) {
        // Message stream error occurred
      },
    );

    _subscriptions[configId] = _ConnectionSubscriptions(
      stateSubscription: stateSubscription,
      messageSubscription: messageSubscription,
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

  /// Subscribe to topic on current dashboard's broker
  void subscribeToTopic(String topic, {int qos = 1}) {
    final service = _getCurrentMqttService();
    if (service != null) {
      service.subscribeToTopic(topic, qos: qos);
    }
  }

  /// Unsubscribe from topic on current dashboard's broker
  void unsubscribeFromTopic(String topic) {
    final service = _getCurrentMqttService();
    if (service != null) {
      service.unsubscribeFromTopic(topic);
    }
    _topicValues.remove(topic);
    notifyListeners();
  }

  /// Publish message to current dashboard's broker
  void publishMessage(String topic, String message, {int qos = 1, bool retain = false}) {
    final service = _getCurrentMqttService();
    if (service != null) {
      service.publishMessage(topic, message, qos: qos, retain: retain);
    }
  }

  String? getTopicValue(String topic) {
    return _topicValues[topic];
  }

  void clearError(String configId) {
    _errorMessages.remove(configId);
    notifyListeners();
  }

  MqttService? _getCurrentMqttService() {
    if (_currentDashboard == null || _currentDashboard!.mqttConfigId.isEmpty) {
      return null;
    }
    return _connections[_currentDashboard!.mqttConfigId];
  }

  Future<void> _resubscribeToTopicsForConfig(String configId) async {
    try {
      _topicValues.clear();

      final service = _connections[configId];
      if (service == null) return;

      // Find all dashboards that use this config
      final dashboards = await _configService.loadDashboards();

      for (final dashboard in dashboards) {
        if (dashboard.mqttConfigId == configId) {
          for (final widget in dashboard.widgets) {
            if (widget.topic.isNotEmpty) {
              service.subscribeToTopic(widget.topic, qos: 1);
            }
          }
        }
      }

      await Future.delayed(const Duration(milliseconds: 500));
      notifyListeners();
    } catch (e) {
      // Error resubscribing to topics
    }
  }

  /// Auto-connection methods
  Future<void> initializeAutoConnect() async {
    _autoConnectEnabled = await _configService.getAutoConnectEnabled();
  }

  /// Auto-connect to all brokers used by existing dashboards
  Future<bool> autoConnect() async {
    await initializeAutoConnect();

    if (!_autoConnectEnabled) {
      return false;
    }

    final dashboards = await _configService.loadDashboards();
    if (dashboards.isEmpty) {
      return false;
    }

    // Collect unique config IDs from all dashboards
    final configIds = dashboards
        .map((d) => d.mqttConfigId)
        .where((id) => id.isNotEmpty)
        .toSet();

    if (configIds.isEmpty) {
      return false;
    }

    // Attempt to connect to all configs
    bool anyConnected = false;
    for (final configId in configIds) {
      final config = await _configService.getMqttConfigById(configId);
      if (config != null) {
        final connected = await connect(config);
        if (connected) anyConnected = true;
      }
    }

    return anyConnected;
  }

  /// Connect to the current dashboard's broker
  Future<bool> connectToCurrentDashboardBroker() async {
    if (_currentDashboard == null || _currentDashboard!.mqttConfigId.isEmpty) {
      return false;
    }

    final configId = _currentDashboard!.mqttConfigId;
    final config = await _configService.getMqttConfigById(configId);
    if (config == null) {
      return false;
    }

    return await connect(config);
  }

  Future<void> setAutoConnectEnabled(bool enabled) async {
    _autoConnectEnabled = enabled;
    await _configService.setAutoConnectEnabled(enabled);

    // Enable/disable auto-reconnect for all active connections
    for (final service in _connections.values) {
      if (enabled) {
        service.enableAutoReconnect();
      } else {
        service.disableAutoReconnect();
      }
    }

    notifyListeners();
  }

  /// Public method to refresh subscriptions for current dashboard
  Future<void> refreshSubscriptions() async {
    if (_currentDashboard == null || _currentDashboard!.mqttConfigId.isEmpty) {
      return;
    }

    final configId = _currentDashboard!.mqttConfigId;
    if (_connectionStates[configId] == MqttConnectionState.connected) {
      await _resubscribeToTopicsForConfig(configId);
    }
  }

  Future<void> _cleanupConnection(String configId) async {
    final subscriptions = _subscriptions.remove(configId);
    if (subscriptions != null) {
      await subscriptions.stateSubscription.cancel();
      await subscriptions.messageSubscription.cancel();
    }

    final service = _connections.remove(configId);
    if (service != null) {
      service.dispose();
    }

    _connectionStates.remove(configId);
    _errorMessages.remove(configId);
  }

  /// Clean up service and subscriptions only, keep error state for UI display
  Future<void> _cleanupServiceOnly(String configId) async {
    final subscriptions = _subscriptions.remove(configId);
    if (subscriptions != null) {
      await subscriptions.stateSubscription.cancel();
      await subscriptions.messageSubscription.cancel();
    }

    final service = _connections.remove(configId);
    if (service != null) {
      service.dispose();
    }
    // Note: We DON'T remove _connectionStates or _errorMessages
    // This allows the UI to show the disconnected/error state
  }

  @override
  void dispose() {
    // Clean up all connections
    for (final configId in _connections.keys.toList()) {
      _cleanupConnection(configId);
    }
    super.dispose();
  }
}

class _ConnectionSubscriptions {
  final StreamSubscription<MqttConnectionState> stateSubscription;
  final StreamSubscription<MqttReceivedMessage<MqttMessage>> messageSubscription;

  _ConnectionSubscriptions({
    required this.stateSubscription,
    required this.messageSubscription,
  });
}