import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/mqtt_config.dart';
import 'web_mqtt_service.dart';

class MqttService {
  MqttServerClient? _client;
  SimpleWebMqttService? _webClient;
  MqttConnectionState? _connectionState;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _subscription;

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

      // Use the simplified web service for web platform
      if (kIsWeb) {
        print('Using Web MQTT Service');
        _webClient = SimpleWebMqttService();

        // Set up web service streams
        _webClient!.messageStream.listen((message) {
          _messageController.add(message);
        });

        _webClient!.connectionStateStream.listen((state) {
          _connectionState = state;
          _connectionStateController.add(state);
        });

        return await _webClient!.connect(config);
      }

      // Native/desktop configuration
      print('Using Native MQTT Service');
      _client = MqttServerClient.withPort(config.host, config.clientId, config.port);
      _client!.useWebSocket = false;
      _client!.secure = config.useTls;

      _client!.logging(on: true);
      _client!.autoReconnect = true;
      _client!.resubscribeOnAutoReconnect = true;
      _client!.keepAlivePeriod = 60;

      _client!.onConnected = () {
        _connectionState = MqttConnectionState.connected;
        _connectionStateController.add(MqttConnectionState.connected);
        print('MQTT Connected to ${config.host}:${config.port}');
      };

      _client!.onDisconnected = () {
        _connectionState = MqttConnectionState.disconnected;
        _connectionStateController.add(MqttConnectionState.disconnected);
        print('MQTT Disconnected');
      };

      if (config.username.isNotEmpty && config.password.isNotEmpty) {
        _client!.connectionMessage = MqttConnectMessage()
            .withClientIdentifier(config.clientId)
            .authenticateAs(config.username, config.password);
      } else {
        _client!.connectionMessage = MqttConnectMessage()
            .withClientIdentifier(config.clientId);
      }

      _connectionState = MqttConnectionState.connecting;
      _connectionStateController.add(MqttConnectionState.connecting);

      await _client!.connect();
      _setupMessageForwarding();
      return true;
    } catch (e) {
      _connectionState = MqttConnectionState.disconnected;
      _connectionStateController.add(MqttConnectionState.disconnected);
      print('MQTT Error: ${e.toString()}');
      return false;
    }
  }

  void _setupMessageForwarding() {
    _subscription = _client!.updates!.listen(
      (List<MqttReceivedMessage<MqttMessage>> messages) {
        for (final message in messages) {
          _messageController.add(message);
        }
      },
      onError: (error) {
        print('MQTT Stream error: $error');
      },
    );
  }

  void subscribeToTopic(String topic, {int qos = 2}) {
    if (kIsWeb && _webClient != null) {
      _webClient!.subscribeToTopic(topic, qos: qos);
    } else if (_client != null && _client!.connectionStatus!.state == MqttConnectionState.connected) {
      _client!.subscribe(topic, MqttQos.values[qos]);
    }
  }

  void unsubscribeFromTopic(String topic) {
    if (kIsWeb && _webClient != null) {
      _webClient!.unsubscribeFromTopic(topic);
    } else if (_client != null && _client!.connectionStatus!.state == MqttConnectionState.connected) {
      _client!.unsubscribe(topic);
    }
  }

  void publishMessage(String topic, String message, {int qos = 2, bool retain = false}) {
    if (kIsWeb && _webClient != null) {
      _webClient!.publishMessage(topic, message, qos: qos);
    } else if (_client != null && _client!.connectionStatus!.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);

      _client!.publishMessage(
        topic,
        MqttQos.values[qos],
        builder.payload!,
        retain: retain,
      );
    } else {
      print('MQTT: Cannot publish - not connected');
    }
  }

  Future<void> disconnect() async {
    if (kIsWeb && _webClient != null) {
      await _webClient!.disconnect();
      _webClient = null;
    } else if (_client != null) {
      try {
        await _subscription?.cancel();
        _subscription = null;

        if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
          _client!.disconnect();
        }

        _client = null;
      } catch (e) {
        print('Error during MQTT disconnect: $e');
      }
    }

    _connectionState = MqttConnectionState.disconnected;
    _connectionStateController.add(MqttConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionStateController.close();
  }
}