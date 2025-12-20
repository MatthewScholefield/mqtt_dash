import 'package:json_annotation/json_annotation.dart';
import 'dashboard_widget.dart';

part 'dashboard.g.dart';

@JsonSerializable()
class Dashboard {
  final String id;
  final String name;
  final String description;
  final String mqttConfigId;
  final List<DashboardWidget> widgets;
  final DateTime createdAt;
  final DateTime lastModified;

  Dashboard({
    required this.id,
    required this.name,
    required this.description,
    required this.mqttConfigId,
    required this.widgets,
    required this.createdAt,
    required this.lastModified,
  });

  factory Dashboard.fromJson(Map<String, dynamic> json) =>
      _$DashboardFromJson(json);

  Map<String, dynamic> toJson() => _$DashboardToJson(this);

  Dashboard copyWith({
    String? id,
    String? name,
    String? description,
    String? mqttConfigId,
    List<DashboardWidget>? widgets,
    DateTime? createdAt,
    DateTime? lastModified,
  }) {
    return Dashboard(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      mqttConfigId: mqttConfigId ?? this.mqttConfigId,
      widgets: widgets ?? this.widgets,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? DateTime.now(),
    );
  }

  Dashboard addWidget(DashboardWidget widget) {
    final newWidgets = List<DashboardWidget>.from(widgets);
    final index = newWidgets.indexWhere((w) => w.id == widget.id);
    if (index >= 0) {
      newWidgets[index] = widget;
    } else {
      newWidgets.add(widget);
    }
    return copyWith(widgets: newWidgets);
  }

  Dashboard removeWidget(String widgetId) {
    final newWidgets = widgets.where((w) => w.id != widgetId).toList();
    return copyWith(widgets: newWidgets);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Dashboard && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Dashboard{id: $id, name: $name, widgets: ${widgets.length}}';
  }
}