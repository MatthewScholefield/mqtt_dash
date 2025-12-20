// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Dashboard _$DashboardFromJson(Map<String, dynamic> json) => Dashboard(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String,
  mqttConfigId: json['mqttConfigId'] as String,
  widgets: (json['widgets'] as List<dynamic>)
      .map((e) => DashboardWidget.fromJson(e as Map<String, dynamic>))
      .toList(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  lastModified: DateTime.parse(json['lastModified'] as String),
);

Map<String, dynamic> _$DashboardToJson(Dashboard instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'mqttConfigId': instance.mqttConfigId,
  'widgets': instance.widgets,
  'createdAt': instance.createdAt.toIso8601String(),
  'lastModified': instance.lastModified.toIso8601String(),
};
