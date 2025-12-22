import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_connection_manager.dart';
import '../models/mqtt_config.dart';

class MqttService {
  late final MqttConnectionManager _connectionManager;

  Stream<MqttConnectionState> get connectionStateStream => _connectionManager.statusStream
      .map((status) => _mapConnectionStatus(status));

  Stream<MqttReceivedMessage<MqttMessage>> get messageStream =>
      _connectionManager.messageStream;

  MqttConnectionState? get connectionState => _mapConnectionStatus(_connectionManager.status);

  MqttService() {
    _connectionManager = MqttConnectionManager();
  }

  MqttConnectionState _mapConnectionStatus(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return MqttConnectionState.connected;
      case ConnectionStatus.connecting:
      case ConnectionStatus.reconnecting:
        return MqttConnectionState.connecting;
      case ConnectionStatus.disconnected:
      case ConnectionStatus.failed:
        return MqttConnectionState.disconnected;
    }
  }

  Future<bool> connect(MqttConfig config) async {
    return await _connectionManager.connect(config);
  }

  Future<void> disconnect() async {
    await _connectionManager.disconnect();
  }

  void subscribeToTopic(String topic, {int qos = 1}) {
    _connectionManager.subscribeToTopic(topic, qos: qos);
  }

  void unsubscribeFromTopic(String topic) {
    _connectionManager.unsubscribeFromTopic(topic);
  }

  void publishMessage(String topic, String message, {int qos = 1, bool retain = false}) {
    _connectionManager.publishMessage(topic, message, qos: qos, retain: retain);
  }

  void enableAutoReconnect() {
    _connectionManager.enableAutoReconnect();
  }

  void disableAutoReconnect() {
    _connectionManager.disableAutoReconnect();
  }

  void dispose() {
    _connectionManager.dispose();
  }
}