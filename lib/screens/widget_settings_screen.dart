import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../models/dashboard_widget.dart';
import '../providers/dashboard_provider.dart';

class WidgetSettingsScreen extends StatefulWidget {
  final DashboardWidget? widget;

  const WidgetSettingsScreen({super.key, this.widget});

  @override
  State<WidgetSettingsScreen> createState() => _WidgetSettingsScreenState();
}

class _WidgetSettingsScreenState extends State<WidgetSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _topicController;
  late TextEditingController _onValueController;
  late TextEditingController _offValueController;
  late TextEditingController _unknownValueController;

  WidgetType _selectedType = WidgetType.button;
  int _qos = 2;
  bool _retain = false;

  String _selectedOnIcon = 'power';
  String _selectedOffIcon = 'power_off';

  final List<String> _availableIcons = [
    'power',
    'power_off',
    'lightbulb',
    'toggle_on',
    'button',
    'lock',
    'fan',
    'tv',
    'speaker',
    'thermostat',
    'sensor',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.widget?.name ?? '');
    _topicController = TextEditingController(text: widget.widget?.topic ?? '');
    _onValueController = TextEditingController(text: widget.widget?.onValue ?? 'ON');
    _offValueController = TextEditingController(text: widget.widget?.offValue ?? 'OFF');
    _unknownValueController = TextEditingController(text: widget.widget?.unknownValue ?? '');

    if (widget.widget != null) {
      _selectedType = widget.widget!.type;
      _qos = widget.widget!.qos;
      _retain = widget.widget!.retain;
      _selectedOnIcon = widget.widget!.icon.onIcon;
      _selectedOffIcon = widget.widget!.icon.offIcon;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _topicController.dispose();
    _onValueController.dispose();
    _offValueController.dispose();
    _unknownValueController.dispose();
    super.dispose();
  }

  void _saveWidget() {
    if (!_formKey.currentState!.validate()) return;

    final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);

    final updatedWidget = DashboardWidget(
      id: widget.widget?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      type: _selectedType,
      topic: _topicController.text,
      onValue: _onValueController.text,
      offValue: _offValueController.text,
      unknownValue: _unknownValueController.text,
      qos: _qos,
      retain: _retain,
      icon: IconDataConfig(
        onIcon: _selectedOnIcon,
        offIcon: _selectedOffIcon,
        unknownIcon: 'help_outline',
      ),
      gridX: widget.widget?.gridX ?? 0,
      gridY: widget.widget?.gridY ?? 0,
      gridWidth: widget.widget?.gridWidth ?? 2,
      gridHeight: widget.widget?.gridHeight ?? 2,
    );

    if (widget.widget == null) {
      dashboardProvider.addWidget(updatedWidget);
    } else {
      dashboardProvider.updateWidget(updatedWidget);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.widget == null ? 'Add Widget' : 'Edit Widget'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveWidget,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Widget Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a widget name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'MQTT Topic',
                border: OutlineInputBorder(),
                hintText: 'e.g., home/livingroom/light1',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an MQTT topic';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<WidgetType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Widget Type',
                border: OutlineInputBorder(),
              ),
              items: WidgetType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getWidgetTypeDisplayName(type)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Values',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _onValueController,
              decoration: const InputDecoration(
                labelText: 'ON Value',
                border: OutlineInputBorder(),
                hintText: 'Value when device is ON',
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _offValueController,
              decoration: const InputDecoration(
                labelText: 'OFF Value',
                border: OutlineInputBorder(),
                hintText: 'Value when device is OFF',
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _unknownValueController,
              decoration: const InputDecoration(
                labelText: 'Unknown Value',
                border: OutlineInputBorder(),
                hintText: 'Default value for unknown states',
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Icons',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedOnIcon,
              decoration: const InputDecoration(
                labelText: 'ON Icon',
                border: OutlineInputBorder(),
              ),
              items: _availableIcons.map((icon) {
                return DropdownMenuItem(
                  value: icon,
                  child: Row(
                    children: [
                      Icon(_getIconData(icon)),
                      const SizedBox(width: 8),
                      Text(icon),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedOnIcon = value!;
                });
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedOffIcon,
              decoration: const InputDecoration(
                labelText: 'OFF Icon',
                border: OutlineInputBorder(),
              ),
              items: _availableIcons.map((icon) {
                return DropdownMenuItem(
                  value: icon,
                  child: Row(
                    children: [
                      Icon(_getIconData(icon)),
                      const SizedBox(width: 8),
                      Text(icon),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedOffIcon = value!;
                });
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'MQTT Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _qos,
              decoration: const InputDecoration(
                labelText: 'QoS Level',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 0, child: Text('0 - At most once')),
                DropdownMenuItem(value: 1, child: Text('1 - At least once')),
                DropdownMenuItem(value: 2, child: Text('2 - Exactly once')),
              ],
              onChanged: (value) {
                setState(() {
                  _qos = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Retain Message'),
              subtitle: const Text('Keep the last message on the broker'),
              value: _retain,
              onChanged: (value) {
                setState(() {
                  _retain = value;
                });
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveWidget,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                widget.widget == null ? 'Add Widget' : 'Save Changes',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getWidgetTypeDisplayName(WidgetType type) {
    switch (type) {
      case WidgetType.button:
        return 'Button';
      case WidgetType.textDisplay:
        return 'Text Display';
      case WidgetType.sensorDisplay:
        return 'Sensor Display';
      case WidgetType.toggleSwitch:
        return 'Toggle Switch';
    }
  }

  IconData _getIconData(String iconName) {
    try {
      return MdiIcons.fromString(iconName) ?? MdiIcons.helpCircle;
    } catch (e) {
      final iconMap = {
        'power': MdiIcons.power,
        'lightbulb': MdiIcons.lightbulb,
        'toggle_on': MdiIcons.toggleSwitch,
        'button': MdiIcons.radioboxMarked,
        'lock': MdiIcons.lock,
        'fan': MdiIcons.fan,
        'tv': MdiIcons.television,
        'speaker': MdiIcons.speaker,
        'thermostat': MdiIcons.thermostat,
        'sensor': MdiIcons.gauge,
        'power_off': MdiIcons.powerOff,
      };
      return iconMap[iconName.toLowerCase()] ?? MdiIcons.helpCircle;
    }
  }
}