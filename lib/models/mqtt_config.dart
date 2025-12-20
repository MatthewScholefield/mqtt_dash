import 'package:json_annotation/json_annotation.dart';

part 'mqtt_config.g.dart';

@JsonSerializable()
class MqttConfig {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final bool useTls;
  final String clientId;

  MqttConfig({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    this.useTls = false,
    String? clientId,
  }) : clientId = clientId ?? 'mqtt_dash_${DateTime.now().millisecondsSinceEpoch}';

  factory MqttConfig.fromJson(Map<String, dynamic> json) =>
      _$MqttConfigFromJson(json);

  Map<String, dynamic> toJson() => _$MqttConfigToJson(this);

  MqttConfig copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
    bool? useTls,
    String? clientId,
  }) {
    return MqttConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      useTls: useTls ?? this.useTls,
      clientId: clientId ?? this.clientId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MqttConfig && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'MqttConfig{id: $id, name: $name, host: $host, port: $port}';
  }
}