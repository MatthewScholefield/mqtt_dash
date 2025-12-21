import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dashboard_widget.dart';
import '../providers/mqtt_provider.dart';
import 'base/dashboard_widget_base.dart';

class SliderWidget extends DashboardWidgetBase {
  const SliderWidget({
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

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.tune,
          size: 32,
          color: theme.colorScheme.primary,
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
      ],
    );
  }
}

class InteractiveSliderWidget extends StatefulWidget {
  final DashboardWidget widgetConfig;

  const InteractiveSliderWidget({
    super.key,
    required this.widgetConfig,
  });

  @override
  State<InteractiveSliderWidget> createState() => _InteractiveSliderWidgetState();
}

class _InteractiveSliderWidgetState extends State<InteractiveSliderWidget> {
  double _currentValue = 0.0;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.widgetConfig.sliderValue;
  }

  void _onSliderChangeStart(double value) {
    // Optional: Handle slider start if needed
  }

  void _onSliderChangeEnd(double value) {
    if (widget.widgetConfig.publishOnRelease) {
      _publishSliderValue(
        Provider.of<MqttProvider>(context, listen: false),
        value,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<MqttProvider>(
      builder: (context, mqttProvider, child) {
        final topicValue = mqttProvider.getTopicValue(widget.widgetConfig.topic);

        if (topicValue != null) {
          _currentValue = widget.widgetConfig.getSliderValueFromPayload(topicValue);
        }

        Widget sliderWidget;

        if (widget.widgetConfig.sliderVertical) {
          sliderWidget = SizedBox(
            width: double.infinity,
            height: 200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.widgetConfig.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 8,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                      ),
                      child: Slider(
                        value: _currentValue.clamp(
                          widget.widgetConfig.sliderMin,
                          widget.widgetConfig.sliderMax,
                        ),
                        min: widget.widgetConfig.sliderMin,
                        max: widget.widgetConfig.sliderMax,
                        divisions: widget.widgetConfig.sliderDivisions > 0
                            ? widget.widgetConfig.sliderDivisions
                            : null,
                        label: '${_currentValue.toStringAsFixed(1)}${widget.widgetConfig.sliderUnit}',
                        onChangeStart: _onSliderChangeStart,
                        onChangeEnd: _onSliderChangeEnd,
                        onChanged: (value) {
                          setState(() {
                            _currentValue = value;
                          });
                          if (!widget.widgetConfig.publishOnRelease) {
                            _publishSliderValue(mqttProvider, value);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_currentValue.toStringAsFixed(1)}${widget.widgetConfig.sliderUnit}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          );
        } else {
          sliderWidget = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.widgetConfig.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Icon(
                Icons.tune,
                size: 32,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: _currentValue.clamp(
                    widget.widgetConfig.sliderMin,
                    widget.widgetConfig.sliderMax,
                  ),
                  min: widget.widgetConfig.sliderMin,
                  max: widget.widgetConfig.sliderMax,
                  divisions: widget.widgetConfig.sliderDivisions > 0
                      ? widget.widgetConfig.sliderDivisions
                      : null,
                  label: '${_currentValue.toStringAsFixed(1)}${widget.widgetConfig.sliderUnit}',
                  onChangeStart: _onSliderChangeStart,
                  onChangeEnd: _onSliderChangeEnd,
                  onChanged: (value) {
                    setState(() {
                      _currentValue = value;
                    });
                    if (!widget.widgetConfig.publishOnRelease) {
                      _publishSliderValue(mqttProvider, value);
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_currentValue.toStringAsFixed(1)}${widget.widgetConfig.sliderUnit}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          );
        }

        return Card(
          elevation: 2,
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: () => _showWidgetSettings(context),
            onLongPress: () => _showWidgetSettings(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: sliderWidget,
            ),
          ),
        );
      },
    );
  }

  void _publishSliderValue(MqttProvider mqttProvider, double value) {
    final payload = widget.widgetConfig.getPayloadForSliderValue(value);

    mqttProvider.publishMessage(
      widget.widgetConfig.topic,
      payload,
      qos: widget.widgetConfig.qos,
      retain: widget.widgetConfig.retain,
    );
  }

  void _showWidgetSettings(BuildContext context) {
    Navigator.of(context).pushNamed('/widget_settings', arguments: widget.widgetConfig);
  }
}