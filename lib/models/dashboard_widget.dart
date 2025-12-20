import 'package:json_annotation/json_annotation.dart';

part 'dashboard_widget.g.dart';

enum WidgetType {
  button,
  textDisplay,
  sensorDisplay,
  toggleSwitch,
}

enum MqttWidgetState {
  on,
  off,
  unknown,
}

@JsonSerializable()
class DashboardWidget {
  final String id;
  final String name;
  final WidgetType type;
  final String topic;
  final String onValue;
  final String offValue;
  final String unknownValue;
  final int qos;
  final bool retain;
  final IconDataConfig icon;
  final int gridX;
  final int gridY;
  final int gridWidth;
  final int gridHeight;
  final Map<String, dynamic> customProperties;

  DashboardWidget({
    required this.id,
    required this.name,
    required this.type,
    required this.topic,
    this.onValue = 'ON',
    this.offValue = 'OFF',
    this.unknownValue = '',
    this.qos = 2,
    this.retain = false,
    required this.icon,
    required this.gridX,
    required this.gridY,
    this.gridWidth = 2,
    this.gridHeight = 2,
    this.customProperties = const {},
  });

  factory DashboardWidget.fromJson(Map<String, dynamic> json) =>
      _$DashboardWidgetFromJson(json);

  Map<String, dynamic> toJson() => _$DashboardWidgetToJson(this);

  DashboardWidget copyWith({
    String? id,
    String? name,
    WidgetType? type,
    String? topic,
    String? onValue,
    String? offValue,
    String? unknownValue,
    int? qos,
    bool? retain,
    IconDataConfig? icon,
    int? gridX,
    int? gridY,
    int? gridWidth,
    int? gridHeight,
    Map<String, dynamic>? customProperties,
  }) {
    return DashboardWidget(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      topic: topic ?? this.topic,
      onValue: onValue ?? this.onValue,
      offValue: offValue ?? this.offValue,
      unknownValue: unknownValue ?? this.unknownValue,
      qos: qos ?? this.qos,
      retain: retain ?? this.retain,
      icon: icon ?? this.icon,
      gridX: gridX ?? this.gridX,
      gridY: gridY ?? this.gridY,
      gridWidth: gridWidth ?? this.gridWidth,
      gridHeight: gridHeight ?? this.gridHeight,
      customProperties: customProperties ?? this.customProperties,
    );
  }

  MqttWidgetState getStateFromPayload(String payload) {
    if (payload.toUpperCase() == onValue.toUpperCase()) {
      return MqttWidgetState.on;
    } else if (payload.toUpperCase() == offValue.toUpperCase()) {
      return MqttWidgetState.off;
    } else {
      return MqttWidgetState.unknown;
    }
  }

  String getPayloadForState(MqttWidgetState state) {
    switch (state) {
      case MqttWidgetState.on:
        return onValue;
      case MqttWidgetState.off:
        return offValue;
      case MqttWidgetState.unknown:
        return unknownValue.isNotEmpty ? unknownValue : offValue;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DashboardWidget && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

@JsonSerializable()
class IconDataConfig {
  final String onIcon;
  final String offIcon;
  final String unknownIcon;

  IconDataConfig({
    required this.onIcon,
    required this.offIcon,
    this.unknownIcon = 'help_outline',
  });

  factory IconDataConfig.fromJson(Map<String, dynamic> json) =>
      _$IconDataConfigFromJson(json);

  Map<String, dynamic> toJson() => _$IconDataConfigToJson(this);

  IconDataConfig copyWith({
    String? onIcon,
    String? offIcon,
    String? unknownIcon,
  }) {
    return IconDataConfig(
      onIcon: onIcon ?? this.onIcon,
      offIcon: offIcon ?? this.offIcon,
      unknownIcon: unknownIcon ?? this.unknownIcon,
    );
  }
}