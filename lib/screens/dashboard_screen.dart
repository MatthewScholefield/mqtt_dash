import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../models/dashboard_widget.dart';
import '../providers/dashboard_provider.dart';
import '../providers/mqtt_provider.dart';
import '../widgets/button_widget.dart';
import 'widget_settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDashboard();
    });
  }

  Future<void> _initializeDashboard() async {
    final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
    final mqttProvider = Provider.of<MqttProvider>(context, listen: false);

    await dashboardProvider.initializeDefaults();

    final currentDashboard = dashboardProvider.currentDashboard;
    if (currentDashboard != null && currentDashboard.widgets.isNotEmpty) {
      for (final widget in currentDashboard.widgets) {
        mqttProvider.subscribeToTopic(widget.topic, qos: widget.qos);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<DashboardProvider>(
          builder: (context, dashboardProvider, child) {
            final currentDashboard = dashboardProvider.currentDashboard;
            return Text(
              currentDashboard?.name ?? 'MQTT Dashboard',
              style: const TextStyle(fontWeight: FontWeight.w600),
            );
          },
        ),
        actions: [
          Consumer<MqttProvider>(
            builder: (context, mqttProvider, child) {
              return IconButton(
                icon: mqttProvider.connectionState == MqttConnectionState.connected
                    ? const Icon(Icons.wifi, color: Colors.green)
                    : const Icon(Icons.wifi_off, color: Colors.red),
                onPressed: () => _showConnectionStatus(context),
              );
            },
          ),
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'add_widget',
                child: ListTile(
                  leading: Icon(Icons.add),
                  title: Text('Add Widget'),
                ),
              ),
              const PopupMenuItem(
                value: 'mqtt_settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('MQTT Settings'),
                ),
              ),
              const PopupMenuItem(
                value: 'dashboards',
                child: ListTile(
                  leading: Icon(Icons.dashboard),
                  title: Text('Manage Dashboards'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<DashboardProvider>(
        builder: (context, dashboardProvider, child) {
          final currentDashboard = dashboardProvider.currentDashboard;

          if (currentDashboard == null) {
            return const Center(
              child: Text('No dashboard selected'),
            );
          }

          if (currentDashboard.widgets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.dashboard_customize,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No widgets yet',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first widget to get started',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddWidgetDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Widget'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              dashboardProvider.loadDashboards();
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: MasonryGridView.count(
                crossAxisCount: _getCrossAxisCount(context),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                itemCount: currentDashboard.widgets.length,
                itemBuilder: (context, index) {
                  final widget = currentDashboard.widgets[index];
                  return _buildWidgetCard(widget, index);
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: _isEditing
          ? FloatingActionButton.extended(
              onPressed: () => _showAddWidgetDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Widget'),
            )
          : null,
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return 6;
    if (screenWidth > 800) return 4;
    if (screenWidth > 600) return 3;
    return 2;
  }

  Widget _buildWidgetCard(DashboardWidget widgetConfig, int index) {
    switch (widgetConfig.type) {
      case WidgetType.button:
        return Consumer<MqttProvider>(
          builder: (context, mqttProvider, child) {
            final topicValue = mqttProvider.getTopicValue(widgetConfig.topic);
            final currentState = topicValue != null
                ? widgetConfig.getStateFromPayload(topicValue)
                : null;

            return ButtonWidget(
              widgetConfig: widgetConfig,
              currentState: currentState,
              onTap: () => _handleWidgetTap(widgetConfig, mqttProvider),
              onLongPress: _isEditing ? () => _showWidgetOptions(widgetConfig) : null,
              isEditing: _isEditing,
            );
          },
        );
      case WidgetType.textDisplay:
      case WidgetType.sensorDisplay:
      case WidgetType.toggleSwitch:
      default:
        return Card(
          child: Container(
            height: 100,
            child: Center(
              child: Text(
                'Widget type not implemented: ${widgetConfig.type}',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
    }
  }

  void _handleWidgetTap(DashboardWidget widgetConfig, MqttProvider mqttProvider) {
    if (_isEditing) {
      _showWidgetOptions(widgetConfig);
      return;
    }

    if (widgetConfig.type == WidgetType.button) {
      final currentStateValue = mqttProvider.getTopicValue(widgetConfig.topic);
      final currentState = currentStateValue != null
          ? widgetConfig.getStateFromPayload(currentStateValue)
          : MqttWidgetState.off;

      final newState = currentState == MqttWidgetState.on ? MqttWidgetState.off : MqttWidgetState.on;
      final payload = widgetConfig.getPayloadForState(newState);

      mqttProvider.publishMessage(
        widgetConfig.topic,
        payload,
        qos: widgetConfig.qos,
        retain: widgetConfig.retain,
      );
    }
  }

  void _showWidgetOptions(DashboardWidget widget) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Widget'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => WidgetSettingsScreen(widget: widget),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Widget', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(context).pop();
                _confirmDeleteWidget(widget);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteWidget(DashboardWidget widget) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Widget'),
        content: Text('Are you sure you want to delete "${widget.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
              dashboardProvider.removeWidget(widget.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddWidgetDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const WidgetSettingsScreen(),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'add_widget':
        _showAddWidgetDialog();
        break;
      case 'mqtt_settings':
        Navigator.of(context).pushNamed('/mqtt_settings');
        break;
      case 'dashboards':
        Navigator.of(context).pushNamed('/dashboards');
        break;
    }
  }

  void _showConnectionStatus(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Consumer<MqttProvider>(
        builder: (context, mqttProvider, child) => AlertDialog(
          title: const Text('Connection Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                mqttProvider.connectionState == MqttConnectionState.connected
                    ? Icons.check_circle
                    : Icons.error,
                color: mqttProvider.connectionState == MqttConnectionState.connected
                    ? Colors.green
                    : Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _getConnectionStatusText(mqttProvider.connectionState),
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (mqttProvider.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  mqttProvider.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/mqtt_settings');
              },
              child: const Text('Settings'),
            ),
          ],
        ),
      ),
    );
  }

  String _getConnectionStatusText(MqttConnectionState? state) {
    if (state == null) return 'Unknown connection state';

    switch (state) {
      case MqttConnectionState.connected:
        return 'Connected to MQTT broker';
      case MqttConnectionState.connecting:
        return 'Connecting to MQTT broker...';
      case MqttConnectionState.disconnected:
        return 'Disconnected from MQTT broker';
      case MqttConnectionState.faulted:
        return 'Connection faulted';
      default:
        return 'Unknown connection state';
    }
  }
}