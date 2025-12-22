import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../models/dashboard_widget.dart';
import '../providers/mqtt_provider.dart';
import '../utils/local_state_tracker.dart';
import 'base/dashboard_widget_base.dart';

class SensorDisplayWidget extends DashboardWidgetBase {
  final LocalStateTracker<String>? stateTracker;

  const SensorDisplayWidget({
    super.key,
    required super.widgetConfig,
    super.currentState,
    super.onTap,
    super.onLongPress,
    super.isEditing,
    super.wrapWithCard,
    this.stateTracker,
  });

  @override
  Widget buildWidget(BuildContext context, MqttWidgetState state) {
    final theme = Theme.of(context);

    // Use state tracker if available (shows last known value), otherwise use direct MQTT read
    String displayValue;
    if (stateTracker != null) {
      displayValue = stateTracker!.localValue.isNotEmpty ? stateTracker!.localValue : '--';
    } else {
      // Fallback to original behavior for non-interactive instances
      final mqttProvider = Provider.of<MqttProvider>(context, listen: false);
      final topicValue = mqttProvider.getTopicValue(widgetConfig.topic);
      displayValue = (topicValue != null && topicValue.isNotEmpty) ? topicValue : '--';
    }

    Color iconColor;
    String iconName;
    String unit = '';

    // For sensor display, we show the last known value
    if (displayValue != '--') {
      iconColor = theme.colorScheme.primary;
      iconName = widgetConfig.icon.onIcon;
    } else {
      iconColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);
      iconName = widgetConfig.icon.unknownIcon;
    }

    // Extract unit from custom properties if available
    if (widgetConfig.customProperties.containsKey('unit')) {
      unit = widgetConfig.customProperties['unit'] ?? '';
    }

    // Try to parse as number for better formatting
    String formattedValue = displayValue;
    try {
      final doubleValue = double.parse(displayValue);
      // Show with appropriate decimal places
      if (doubleValue == doubleValue.round()) {
        formattedValue = doubleValue.round().toString();
      } else {
        // Show with 1-2 decimal places for sensor values
        formattedValue = doubleValue.toStringAsFixed(1).replaceAll(RegExp(r'\.?0+$'), '');
      }
    } catch (e) {
      // Keep as-is if not a number
      formattedValue = displayValue;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            _getIconData(iconName),
            color: iconColor,
            size: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widgetConfig.name,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              formattedValue,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                unit,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  IconData _getIconData(String iconName) {
    try {
      return MdiIcons.fromString(iconName) ?? MdiIcons.helpCircle;
    } catch (e) {
      final iconMap = {
        'temperature': MdiIcons.thermometer,
        'thermometer': MdiIcons.thermometer,
        'temp': MdiIcons.thermometer,
        'humidity': MdiIcons.waterPercent,
        'humidity_sensor': MdiIcons.waterPercent,
        'light': MdiIcons.lightbulb,
        'light_sensor': MdiIcons.lightbulbOn,
        'brightness': MdiIcons.brightness6,
        'motion': MdiIcons.motionSensor,
        'motion_sensor': MdiIcons.motionSensor,
        'pressure': MdiIcons.gauge,
        'pressure_sensor': MdiIcons.gauge,
        'air': MdiIcons.weatherWindy,
        'air_quality': MdiIcons.airFilter,
        'co2': MdiIcons.moleculeCo2,
        'vibration': MdiIcons.vibrate,
        'distance': MdiIcons.ruler,
        'weight': MdiIcons.scale,
        'speed': MdiIcons.speedometer,
        'power': MdiIcons.flash,
        'voltage': MdiIcons.currentAc,
        'current': MdiIcons.currentDc,
        'energy': MdiIcons.lightningBolt,
        'flow': MdiIcons.water,
        'level': MdiIcons.thermometerLines,
        'ph': MdiIcons.testTube,
        'sound': MdiIcons.volumeHigh,
        'noise': MdiIcons.volumeHigh,
        'sensor': MdiIcons.gauge,
        'sensors': MdiIcons.gauge,
        'help_outline': MdiIcons.helpCircleOutline,
        'help': MdiIcons.helpCircle,
      };

      return iconMap[iconName.toLowerCase()] ?? MdiIcons.gauge;
    }
  }
}

class InteractiveSensorDisplayWidget extends StatefulWidget {
  final DashboardWidget widgetConfig;

  const InteractiveSensorDisplayWidget({
    super.key,
    required this.widgetConfig,
  });

  @override
  State<InteractiveSensorDisplayWidget> createState() => _InteractiveSensorDisplayWidgetState();
}

class _InteractiveSensorDisplayWidgetState extends State<InteractiveSensorDisplayWidget> {
  late LocalStateTracker<String> _stateTracker;

  @override
  void initState() {
    super.initState();
    _stateTracker = LocalStateTracker<String>(
      initialValue: '',
      remoteValue: null,
      equals: (a, b) => a == b,
      debugTag: 'Sensor-${widget.widgetConfig.name}',
    );
  }

  @override
  void dispose() {
    _stateTracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MqttProvider>(
      builder: (context, mqttProvider, child) {
        final topicValue = mqttProvider.getTopicValue(widget.widgetConfig.topic);

        // Always track remote state
        if (topicValue != null && topicValue.isNotEmpty) {
          _stateTracker.updateRemoteValue(topicValue);
        } else {
          _stateTracker.clearRemoteState();
        }

        final currentState = _stateTracker.remoteValue != null
            ? MqttWidgetState.on
            : MqttWidgetState.unknown;

        return Card(
          elevation: 2,
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: () => _handleRefresh(mqttProvider),
            onLongPress: () => _showWidgetSettings(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  Center(
                    child: SensorDisplayWidget(
                      widgetConfig: widget.widgetConfig,
                      currentState: currentState,
                      // Pass the state tracker to use the last known value
                      stateTracker: _stateTracker,
                      onTap: () => _handleRefresh(mqttProvider),
                      onLongPress: () => _showWidgetSettings(context),
                      wrapWithCard: false,
                    ),
                  ),
                  // Show orange indicator when we don't have current remote data
                  if (_stateTracker.isDirty)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: 0.3),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleRefresh(MqttProvider mqttProvider) {
    // Sensor widgets don't publish, they only display
    // We could potentially trigger a manual refresh here if needed
    // For now, just provide haptic feedback
    if (widget.widgetConfig.customProperties.containsKey('refreshEnabled') &&
        widget.widgetConfig.customProperties['refreshEnabled'] == true) {
      // Could implement a refresh mechanism if the sensor supports it
    }
  }

  void _showWidgetSettings(BuildContext context) {
    Navigator.of(context).pushNamed('/widget_settings', arguments: widget.widgetConfig);
  }
}