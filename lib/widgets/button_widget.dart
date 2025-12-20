import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../models/dashboard_widget.dart';
import '../providers/mqtt_provider.dart';
import 'base/dashboard_widget_base.dart';

class ButtonWidget extends DashboardWidgetBase {
  const ButtonWidget({
    super.key,
    required super.widgetConfig,
    super.currentState,
    super.onTap,
    super.onLongPress,
    super.isEditing,
  });

  @override
  Widget buildWidget(BuildContext context, MqttWidgetState state) {
    final theme = Theme.of(context);
    final mqttProvider = Provider.of<MqttProvider>(context, listen: false);

    Color backgroundColor;
    Color iconColor;
    String iconName;

    switch (state) {
      case MqttWidgetState.on:
        backgroundColor = theme.colorScheme.primary;
        iconColor = theme.colorScheme.onPrimary;
        iconName = widgetConfig.icon.onIcon;
        break;
      case MqttWidgetState.off:
        backgroundColor = theme.colorScheme.surface;
        iconColor = theme.colorScheme.onSurface;
        iconName = widgetConfig.icon.offIcon;
        break;
      case MqttWidgetState.unknown:
      default:
        backgroundColor = theme.colorScheme.surface;
        iconColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);
        iconName = widgetConfig.icon.unknownIcon;
        break;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            _getIconData(iconName),
            color: iconColor,
            size: 32,
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
        if (state != MqttWidgetState.unknown)
          Text(
            state == MqttWidgetState.on ? 'ON' : 'OFF',
            style: theme.textTheme.bodySmall?.copyWith(
              color: state == MqttWidgetState.on
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  IconData _getIconData(String iconName) {
    try {
      return MdiIcons.fromString(iconName) ?? MdiIcons.helpCircle;
    } catch (e) {
      final iconMap = {
        'power': MdiIcons.power,
        'power_settings_new': MdiIcons.power,
        'lightbulb': MdiIcons.lightbulb,
        'lightbulb_outline': MdiIcons.lightbulbOutline,
        'toggle_on': MdiIcons.toggleSwitch,
        'toggle_off': MdiIcons.toggleSwitchOff,
        'button': MdiIcons.radioboxMarked,
        'radio_button_checked': MdiIcons.radioboxMarked,
        'radio_button_unchecked': MdiIcons.radioboxBlank,
        'lock': MdiIcons.lock,
        'lock_open': MdiIcons.lockOpen,
        'fan': MdiIcons.fan,
        'toys': MdiIcons.fan,
        'tv': MdiIcons.television,
        'television': MdiIcons.television,
        'speaker': MdiIcons.speaker,
        'volume_up': MdiIcons.volumeHigh,
        'thermostat': MdiIcons.thermostat,
        'sensors': MdiIcons.gauge,
        'sensor': MdiIcons.gauge,
        'help_outline': MdiIcons.helpCircleOutline,
        'help': MdiIcons.helpCircle,
      };

      return iconMap[iconName.toLowerCase()] ?? MdiIcons.helpCircle;
    }
  }
}

class InteractiveButtonWidget extends StatefulWidget {
  final DashboardWidget widgetConfig;

  const InteractiveButtonWidget({
    super.key,
    required this.widgetConfig,
  });

  @override
  State<InteractiveButtonWidget> createState() => _InteractiveButtonWidgetState();
}

class _InteractiveButtonWidgetState extends State<InteractiveButtonWidget> {
  MqttWidgetState _currentState = MqttWidgetState.off;

  @override
  Widget build(BuildContext context) {
    return Consumer<MqttProvider>(
      builder: (context, mqttProvider, child) {
        final topicValue = mqttProvider.getTopicValue(widget.widgetConfig.topic);

        if (topicValue != null) {
          _currentState = widget.widgetConfig.getStateFromPayload(topicValue);
        }

        return ButtonWidget(
          widgetConfig: widget.widgetConfig,
          currentState: _currentState,
          onTap: () => _toggleButton(mqttProvider),
          onLongPress: () => _showWidgetSettings(context),
        );
      },
    );
  }

  void _toggleButton(MqttProvider mqttProvider) {
    final newState = _currentState == MqttWidgetState.on ? MqttWidgetState.off : MqttWidgetState.on;
    final payload = widget.widgetConfig.getPayloadForState(newState);

    mqttProvider.publishMessage(
      widget.widgetConfig.topic,
      payload,
      qos: widget.widgetConfig.qos,
      retain: widget.widgetConfig.retain,
    );

    setState(() {
      _currentState = newState;
    });
  }

  void _showWidgetSettings(BuildContext context) {
    Navigator.of(context).pushNamed('/widget_settings', arguments: widget.widgetConfig);
  }
}