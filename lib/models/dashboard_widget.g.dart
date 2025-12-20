// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_widget.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DashboardWidget _$DashboardWidgetFromJson(Map<String, dynamic> json) =>
    DashboardWidget(
      id: json['id'] as String,
      name: json['name'] as String,
      type: $enumDecode(_$WidgetTypeEnumMap, json['type']),
      topic: json['topic'] as String,
      onValue: json['onValue'] as String? ?? 'ON',
      offValue: json['offValue'] as String? ?? 'OFF',
      unknownValue: json['unknownValue'] as String? ?? '',
      qos: (json['qos'] as num?)?.toInt() ?? 2,
      retain: json['retain'] as bool? ?? false,
      icon: IconDataConfig.fromJson(json['icon'] as Map<String, dynamic>),
      gridX: (json['gridX'] as num).toInt(),
      gridY: (json['gridY'] as num).toInt(),
      gridWidth: (json['gridWidth'] as num?)?.toInt() ?? 2,
      gridHeight: (json['gridHeight'] as num?)?.toInt() ?? 2,
      customProperties:
          json['customProperties'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$DashboardWidgetToJson(DashboardWidget instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': _$WidgetTypeEnumMap[instance.type]!,
      'topic': instance.topic,
      'onValue': instance.onValue,
      'offValue': instance.offValue,
      'unknownValue': instance.unknownValue,
      'qos': instance.qos,
      'retain': instance.retain,
      'icon': instance.icon,
      'gridX': instance.gridX,
      'gridY': instance.gridY,
      'gridWidth': instance.gridWidth,
      'gridHeight': instance.gridHeight,
      'customProperties': instance.customProperties,
    };

const _$WidgetTypeEnumMap = {
  WidgetType.button: 'button',
  WidgetType.textDisplay: 'textDisplay',
  WidgetType.sensorDisplay: 'sensorDisplay',
  WidgetType.toggleSwitch: 'toggleSwitch',
};

IconDataConfig _$IconDataConfigFromJson(Map<String, dynamic> json) =>
    IconDataConfig(
      onIcon: json['onIcon'] as String,
      offIcon: json['offIcon'] as String,
      unknownIcon: json['unknownIcon'] as String? ?? 'help_outline',
    );

Map<String, dynamic> _$IconDataConfigToJson(IconDataConfig instance) =>
    <String, dynamic>{
      'onIcon': instance.onIcon,
      'offIcon': instance.offIcon,
      'unknownIcon': instance.unknownIcon,
    };
