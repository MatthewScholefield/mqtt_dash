import 'package:flutter/material.dart';
import '../../models/dashboard_widget.dart';
import '../../providers/mqtt_provider.dart';

abstract class DashboardWidgetBase extends StatelessWidget {
  final DashboardWidget widgetConfig;
  final MqttWidgetState? currentState;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isEditing;

  const DashboardWidgetBase({
    super.key,
    required this.widgetConfig,
    this.currentState,
    this.onTap,
    this.onLongPress,
    this.isEditing = false,
  });

  Widget buildWidget(BuildContext context, MqttWidgetState state);

  Widget buildEditingOverlay(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          buildWidget(context, currentState ?? MqttWidgetState.unknown),
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = isEditing
        ? buildEditingOverlay(context)
        : buildWidget(context, currentState ?? MqttWidgetState.unknown);

    return Card(
      elevation: isEditing ? 8 : 2,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: content,
        ),
      ),
    );
  }
}