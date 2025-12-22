import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dashboard_widget.dart';
import '../providers/mqtt_provider.dart';
import '../utils/local_state_tracker.dart';
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
  late LocalStateTracker<double> _stateTracker;

  @override
  void initState() {
    super.initState();
    _stateTracker = LocalStateTracker<double>(
      initialValue: widget.widgetConfig.sliderValue,
      remoteValue: widget.widgetConfig.sliderValue,
      equals: (a, b) => (a - b).abs() < 0.001,
      debugTag: 'Slider-${widget.widgetConfig.name}',
      onStateUpdated: () {
        if (mounted) {
          debugPrint('[Slider-${widget.widgetConfig.name}] State tracker callback - calling setState');
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _stateTracker.dispose();
    super.dispose();
  }

  void _onSliderChangeStart(double value) {
    _setLocalValue(value);
  }

  void _onSliderChangeEnd(double value) {
    debugPrint('[Slider-${widget.widgetConfig.name}] Change ended with value: $value (publishOnRelease: ${widget.widgetConfig.publishOnRelease})');

    // Publish final value
    if (widget.widgetConfig.publishOnRelease) {
      _publishSliderValue(
        Provider.of<MqttProvider>(context, listen: false),
        value,
      );
    }

    // Start timer to sync local state with remote state
    _stateTracker.startSyncToRemote();
  }

  void _setLocalValue(double value) {
    debugPrint('[Slider-${widget.widgetConfig.name}] Setting local value to: $value');
    _stateTracker.updateLocalValue(value);
    if (mounted) {
      debugPrint('[Slider-${widget.widgetConfig.name}] Calling setState');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDirty = _stateTracker.isDirty;
    debugPrint('[Slider-${widget.widgetConfig.name}] Building widget. Local value: ${_stateTracker.localValue}, Remote value: ${_stateTracker.remoteValue}, Is dirty: $isDirty (${isDirty ? '🟠 ORANGE DOT' : '✅ CLEAN'})');

    return Consumer<MqttProvider>(
      builder: (context, mqttProvider, child) {
        final topicValue = mqttProvider.getTopicValue(widget.widgetConfig.topic);

        // Track remote state only when it actually changes to avoid interference with local changes
        double? newRemoteValue;
        if (topicValue != null) {
          newRemoteValue = widget.widgetConfig.getSliderValueFromPayload(topicValue);
          debugPrint('[Slider-${widget.widgetConfig.name}] Raw MQTT topic value: "$topicValue" → parsed: $newRemoteValue');
        } else {
          debugPrint('[Slider-${widget.widgetConfig.name}] No MQTT topic value available');
        }

        // Only update remote state if it's different from current remote state
        if (newRemoteValue != _stateTracker.remoteValue) {
          debugPrint('[Slider-${widget.widgetConfig.name}] Remote value changed from ${_stateTracker.remoteValue} to $newRemoteValue');
          _stateTracker.updateRemoteValue(newRemoteValue);
        } else if (newRemoteValue == null && _stateTracker.remoteValue != null) {
          debugPrint('[Slider-${widget.widgetConfig.name}] Remote value cleared (was ${_stateTracker.remoteValue})');
          _stateTracker.clearRemoteState();
        } else {
          debugPrint('[Slider-${widget.widgetConfig.name}] Remote value unchanged: $newRemoteValue');
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
                        value: _stateTracker.localValue.clamp(
                          widget.widgetConfig.sliderMin,
                          widget.widgetConfig.sliderMax,
                        ),
                        min: widget.widgetConfig.sliderMin,
                        max: widget.widgetConfig.sliderMax,
                        divisions: widget.widgetConfig.sliderDivisions > 0
                            ? widget.widgetConfig.sliderDivisions
                            : null,
                        label: '${_stateTracker.localValue.toStringAsFixed(1)}${widget.widgetConfig.sliderUnit}',
                        onChangeStart: _onSliderChangeStart,
                        onChangeEnd: _onSliderChangeEnd,
                        onChanged: (value) {
                          _setLocalValue(value);
                          if (!widget.widgetConfig.publishOnRelease) {
                            debugPrint('[Slider-${widget.widgetConfig.name}] Publishing during drag (publishOnRelease: false): $value');
                            _publishSliderValue(mqttProvider, value);
                          } else {
                            debugPrint('[Slider-${widget.widgetConfig.name}] Not publishing during drag (publishOnRelease: true)');
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_stateTracker.localValue.toStringAsFixed(1)}${widget.widgetConfig.sliderUnit}',
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
                  value: _stateTracker.localValue.clamp(
                    widget.widgetConfig.sliderMin,
                    widget.widgetConfig.sliderMax,
                  ),
                  min: widget.widgetConfig.sliderMin,
                  max: widget.widgetConfig.sliderMax,
                  divisions: widget.widgetConfig.sliderDivisions > 0
                      ? widget.widgetConfig.sliderDivisions
                      : null,
                  label: '${_stateTracker.localValue.toStringAsFixed(1)}${widget.widgetConfig.sliderUnit}',
                  onChangeStart: _onSliderChangeStart,
                  onChangeEnd: _onSliderChangeEnd,
                  onChanged: (value) {
                    _setLocalValue(value);
                    if (!widget.widgetConfig.publishOnRelease) {
                      debugPrint('[Slider-${widget.widgetConfig.name}] Publishing during drag (publishOnRelease: false): $value');
                      _publishSliderValue(mqttProvider, value);
                    } else {
                      debugPrint('[Slider-${widget.widgetConfig.name}] Not publishing during drag (publishOnRelease: true)');
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_stateTracker.localValue.toStringAsFixed(1)}${widget.widgetConfig.sliderUnit}',
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
              child: Stack(
                children: [
                  sliderWidget,
                  // Show orange indicator if remote state is undefined or doesn't match local state
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

  void _publishSliderValue(MqttProvider mqttProvider, double value) {
    final payload = widget.widgetConfig.getPayloadForSliderValue(value);
    debugPrint('[Slider-${widget.widgetConfig.name}] Publishing to topic "${widget.widgetConfig.topic}" with payload: "$payload" (qos: ${widget.widgetConfig.qos}, retain: ${widget.widgetConfig.retain})');

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