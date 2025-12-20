// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mqtt_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MqttConfig _$MqttConfigFromJson(Map<String, dynamic> json) => MqttConfig(
  id: json['id'] as String,
  name: json['name'] as String,
  host: json['host'] as String,
  port: (json['port'] as num).toInt(),
  username: json['username'] as String,
  password: json['password'] as String,
  useTls: json['useTls'] as bool? ?? false,
  clientId: json['clientId'] as String?,
);

Map<String, dynamic> _$MqttConfigToJson(MqttConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'host': instance.host,
      'port': instance.port,
      'username': instance.username,
      'password': instance.password,
      'useTls': instance.useTls,
      'clientId': instance.clientId,
    };
