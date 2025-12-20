import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/mqtt_config.dart';

class SimpleWebMqttService {
  MqttServerClient? _client;
  MqttConnectionState? _connectionState;

  final StreamController<MqttReceivedMessage<MqttMessage>> _messageController =
      StreamController<MqttReceivedMessage<MqttMessage>>.broadcast();

  final StreamController<MqttConnectionState> _connectionStateController =
      StreamController<MqttConnectionState>.broadcast();

  Stream<MqttReceivedMessage<MqttMessage>> get messageStream =>
      _messageController.stream;

  Stream<MqttConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  MqttConnectionState? get connectionState => _connectionState;

  Future<bool> connect(MqttConfig config) async {
    try {
      await disconnect();

      if (!kIsWeb) {
        print('This service is for web only');
        return false;
      }

      print('Creating simple web MQTT connection to ${config.host}:${config.port}');

      // Create the simplest possible client
      _client = MqttServerClient(config.host, config.clientId);
      _client!.useWebSocket = true;
      _client!.secure = false;
      // Set port manually for WebSocket
      _client!.port = config.port;

      // Set up basic callbacks
      _client!.onConnected = () {
        print('✅ MQTT Connected via WebSocket');
        _connectionState = MqttConnectionState.connected;
        _connectionStateController.add(MqttConnectionState.connected);
      };

      _client!.onDisconnected = () {
        print('❌ MQTT Disconnected');
        _connectionState = MqttConnectionState.disconnected;
        _connectionStateController.add(MqttConnectionState.disconnected);
      };

      _connectionState = MqttConnectionState.connecting;
      _connectionStateController.add(MqttConnectionState.connecting);

      // Simple connection message
      _client!.connectionMessage = MqttConnectMessage()
          .withClientIdentifier(config.clientId);

      if (config.username.isNotEmpty && config.password.isNotEmpty) {
        _client!.connectionMessage!.authenticateAs(config.username, config.password);
      }

      // Try to connect
      await _client!.connect();

      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        _setupMessageForwarding();
        return true;
      } else {
        print('Connection failed: ${_client!.connectionStatus!.returnCode}');
        return false;
      }

    } catch (e) {
      print('Web MQTT connection error: ${e.toString()}');
      _connectionState = MqttConnectionState.disconnected;
      _connectionStateController.add(MqttConnectionState.disconnected);
      return false;
    }
  }

  void _setupMessageForwarding() {
    _client!.updates?.listen((messages) {
      for (final message in messages) {
        _messageController.add(message);
      }
    });
  }

  void subscribeToTopic(String topic, {int qos = 1}) {
    if (_client != null && _client!.connectionStatus!.state == MqttConnectionState.connected) {
      print('Subscribing to: $topic');
      _client!.subscribe(topic, MqttQos.atLeastOnce);
    }
  }

  void unsubscribeFromTopic(String topic) {
    if (_client != null && _client!.connectionStatus!.state == MqttConnectionState.connected) {
      _client!.unsubscribe(topic);
    }
  }

  void publishMessage(String topic, String message, {int qos = 1}) {
    if (_client != null && _client!.connectionStatus!.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    }
  }

  Future<void> disconnect() async {
    if (_client != null) {
      try {
        if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
          _client!.disconnect();
        }
      } catch (e) {
        print('Error during disconnect: $e');
      }
      _client = null;
      _connectionState = MqttConnectionState.disconnected;
      _connectionStateController.add(MqttConnectionState.disconnected);
    }
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionStateController.close();
  }
}