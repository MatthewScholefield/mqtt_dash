import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../models/dashboard_widget.dart';
import '../providers/mqtt_provider.dart';
import '../utils/local_state_tracker.dart';
import 'base/dashboard_widget_base.dart';

class ToggleSwitchWidget extends DashboardWidgetBase {
  const ToggleSwitchWidget({
    super.key,
    required super.widgetConfig,
    super.currentState,
    super.onTap,
    super.onLongPress,
    super.isEditing,
    super.wrapWithCard,
  });

  @override
  Widget buildWidget(BuildContext context, MqttWidgetState state) {
    final theme = Theme.of(context);

    Color switchColor;
    Color iconColor;
    String onIconName;
    String offIconName;

    switch (state) {
      case MqttWidgetState.on:
        switchColor = theme.colorScheme.primary;
        iconColor = theme.colorScheme.onPrimary;
        onIconName = widgetConfig.icon.onIcon;
        offIconName = widgetConfig.icon.offIcon;
        break;
      case MqttWidgetState.off:
        switchColor = theme.colorScheme.surfaceContainerHighest;
        iconColor = theme.colorScheme.onSurfaceVariant;
        onIconName = widgetConfig.icon.onIcon;
        offIconName = widgetConfig.icon.offIcon;
        break;
      case MqttWidgetState.unknown:
        switchColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
        iconColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
        onIconName = widgetConfig.icon.onIcon;
        offIconName = widgetConfig.icon.offIcon;
        break;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            color: switchColor,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Off side
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: state == MqttWidgetState.off
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    bottomLeft: Radius.circular(28),
                  ),
                ),
                child: Icon(
                  _getIconData(offIconName),
                  color: state == MqttWidgetState.off
                      ? theme.colorScheme.onPrimary
                      : iconColor.withValues(alpha: 0.6),
                  size: 20,
                ),
              ),
              // Handle
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: state == MqttWidgetState.on
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // On side
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: state == MqttWidgetState.on
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Icon(
                  _getIconData(onIconName),
                  color: state == MqttWidgetState.on
                      ? theme.colorScheme.onPrimary
                      : iconColor.withValues(alpha: 0.6),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
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
        'switch': MdiIcons.toggleSwitch,
        'electric_switch': MdiIcons.electricSwitch,
        'help_outline': MdiIcons.helpCircleOutline,
        'help': MdiIcons.helpCircle,
      };

      return iconMap[iconName.toLowerCase()] ?? MdiIcons.helpCircle;
    }
  }
}

class InteractiveToggleSwitchWidget extends StatefulWidget {
  final DashboardWidget widgetConfig;

  const InteractiveToggleSwitchWidget({
    super.key,
    required this.widgetConfig,
  });

  @override
  State<InteractiveToggleSwitchWidget> createState() => _InteractiveToggleSwitchWidgetState();
}

class _InteractiveToggleSwitchWidgetState extends State<InteractiveToggleSwitchWidget>
    with SingleTickerProviderStateMixin {
  late LocalStateTracker<MqttWidgetState> _stateTracker;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _stateTracker = LocalStateTracker<MqttWidgetState>(
      initialValue: MqttWidgetState.off,
      remoteValue: MqttWidgetState.off,
      equals: (a, b) => a == b,
      debugTag: 'ToggleSwitch-${widget.widgetConfig.name}',
    );

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _stateTracker.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MqttProvider>(
      builder: (context, mqttProvider, child) {
        final topicValue = mqttProvider.getTopicValue(widget.widgetConfig.topic);

        // Always track remote state
        if (topicValue != null) {
          final remoteState = widget.widgetConfig.getStateFromPayload(topicValue);
          _stateTracker.updateRemoteValue(remoteState);
        } else {
          _stateTracker.clearRemoteState();
        }

        return Card(
          elevation: 2,
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: () => _toggleSwitch(mqttProvider),
            onTapDown: (_) => _animationController.forward(),
            onTapUp: (_) => _animationController.reverse(),
            onTapCancel: () => _animationController.reverse(),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Stack(
                      children: [
                        Center(
                          child: ToggleSwitchWidget(
                            widgetConfig: widget.widgetConfig,
                            currentState: _stateTracker.localValue,
                            onTap: () => _toggleSwitch(mqttProvider),
                            wrapWithCard: false,
                          ),
                        ),
                        // Show orange indicator when local state differs from server state
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
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _toggleSwitch(MqttProvider mqttProvider) {
    final newState = _stateTracker.localValue == MqttWidgetState.on
        ? MqttWidgetState.off
        : MqttWidgetState.on;
    final payload = widget.widgetConfig.getPayloadForState(newState);

    mqttProvider.publishMessage(
      widget.widgetConfig.topic,
      payload,
      qos: widget.widgetConfig.qos,
      retain: widget.widgetConfig.retain,
    );

    _stateTracker.updateLocalValue(newState);
    setState(() {});
  }
}