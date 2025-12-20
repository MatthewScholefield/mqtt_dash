import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../core/mqtt_service.dart';
import '../models/mqtt_config.dart';

class MqttProvider extends ChangeNotifier {
  final MqttService _mqttService = MqttService();

  MqttConnectionState? _connectionState;
  String? _errorMessage;
  Map<String, String> _topicValues = {};

  MqttConnectionState? get connectionState => _connectionState;
  String? get errorMessage => _errorMessage;
  Map<String, String> get topicValues => Map.from(_topicValues);

  Stream<MqttConnectionState> get connectionStateStream =>
      _mqttService.connectionStateStream;
  Stream<MqttReceivedMessage<MqttMessage>> get messageStream =>
      _mqttService.messageStream;

  MqttProvider() {
    _setupListeners();
  }

  void _setupListeners() {
    _mqttService.connectionStateStream.listen((state) {
      _connectionState = state;
      _errorMessage = null;
      notifyListeners();
    });

    _mqttService.messageStream.listen((message) {
      final topic = message.topic;
      final payload = message.payload is String
        ? message.payload as String
        : String.fromCharCodes(message.payload as List<int>);

      _topicValues[topic] = payload;
      notifyListeners();
    });
  }

  Future<bool> connect(MqttConfig config) async {
    try {
      _errorMessage = null;
      notifyListeners();

      print('Attempting to connect to MQTT broker: ${config.host}:${config.port}');
      print('Client ID: ${config.clientId}');
      print('Username: ${config.username.isNotEmpty ? config.username : 'None'}');
      print('Use TLS: ${config.useTls}');

      if (kIsWeb) {
        print('Web platform detected - using WebSocket connection');
        print('WebSocket URL: ws://${config.host}:${config.port}');
        print('Note: TLS disabled for web to avoid SecurityContext issues');
      }

      final success = await _mqttService.connect(config);
      if (!success) {
        String additionalHelp = '';
        if (kIsWeb) {
          additionalHelp = ' Make sure your MQTT broker supports WebSocket connections on port 8080 (non-TLS).';
        }
        _errorMessage = 'Failed to connect to ${config.host}:${config.port}.$additionalHelp Check host, port, and credentials.';
        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = 'Connection error: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _mqttService.disconnect();
      _topicValues.clear();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Disconnect error: $e';
      notifyListeners();
    }
  }

  void subscribeToTopic(String topic, {int qos = 2}) {
    _mqttService.subscribeToTopic(topic, qos: qos);
  }

  void unsubscribeFromTopic(String topic) {
    _mqttService.unsubscribeFromTopic(topic);
    _topicValues.remove(topic);
    notifyListeners();
  }

  void publishMessage(String topic, String message, {int qos = 2, bool retain = false}) {
    _mqttService.publishMessage(topic, message, qos: qos, retain: retain);
  }

  String? getTopicValue(String topic) {
    return _topicValues[topic];
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _mqttService.dispose();
    super.dispose();
  }
}