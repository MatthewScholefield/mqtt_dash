import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../models/dashboard_widget.dart';
import '../providers/dashboard_provider.dart';
import '../providers/mqtt_provider.dart';
import '../widgets/button_widget.dart';
import '../widgets/sensor_display_widget.dart';
import '../widgets/slider_widget.dart';
import '../widgets/toggle_switch_widget.dart';
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

    // Step 1: Initialize configurations
    await dashboardProvider.initializeDefaults();

    // Step 2: Attempt auto-connection
    await mqttProvider.autoConnect();

    // Step 3: If connected, refresh subscriptions to get retained messages
    if (mqttProvider.connectionState == MqttConnectionState.connected) {
      await mqttProvider.refreshSubscriptions();
    }

    // Step 4: Force UI update to populate initial states
    if (mounted) {
      setState(() {});
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
        return InteractiveButtonWidget(
          widgetConfig: widgetConfig,
        );
      case WidgetType.slider:
        return InteractiveSliderWidget(widgetConfig: widgetConfig);
      case WidgetType.sensorDisplay:
        return InteractiveSensorDisplayWidget(widgetConfig: widgetConfig);
      case WidgetType.toggleSwitch:
        return InteractiveToggleSwitchWidget(widgetConfig: widgetConfig);
      case WidgetType.textDisplay:
        return Card(
          child: SizedBox(
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
                _getConnectionStatusIcon(mqttProvider),
                color: _getConnectionStatusColor(mqttProvider),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _getConnectionStatusText(mqttProvider.connectionState, mqttProvider),
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Auto-connect: ${mqttProvider.autoConnectEnabled ? "Enabled" : "Disabled"}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              if (mqttProvider.lastConnectedConfigId != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Last used config ID: ${mqttProvider.lastConnectedConfigId}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
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
            if (mqttProvider.connectionState != MqttConnectionState.connected)
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  // Attempt to reconnect to last used config
                  await mqttProvider.connectToLastUsedConfig();
                },
                child: const Text('Retry'),
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

  String _getConnectionStatusText(MqttConnectionState? state, MqttProvider mqttProvider) {
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

  IconData _getConnectionStatusIcon(MqttProvider mqttProvider) {
    final state = mqttProvider.connectionState;

    switch (state) {
      case MqttConnectionState.connected:
        return Icons.check_circle; // Success icon for healthy connection
      case MqttConnectionState.connecting:
        return Icons.sync; // Sync icon for connecting
      case MqttConnectionState.disconnected:
      case MqttConnectionState.faulted:
        return Icons.error; // Error icon
      default:
        return Icons.help_outline; // Unknown state
    }
  }

  Color _getConnectionStatusColor(MqttProvider mqttProvider) {
    final state = mqttProvider.connectionState;

    switch (state) {
      case MqttConnectionState.connected:
        return Colors.green; // Green for healthy connection
      case MqttConnectionState.connecting:
        return Colors.blue; // Blue for connecting
      case MqttConnectionState.disconnected:
      case MqttConnectionState.faulted:
        return Colors.red; // Red for disconnected/error state
      default:
        return Colors.grey; // Grey for unknown state
    }
  }
}