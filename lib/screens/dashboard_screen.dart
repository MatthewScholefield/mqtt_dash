import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../models/dashboard.dart';
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

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeDashboard() async {
    final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
    final mqttProvider = Provider.of<MqttProvider>(context, listen: false);

    // Step 1: Initialize configurations
    await dashboardProvider.initializeDefaults();

    // Step 2: Set current dashboard on mqttProvider
    final currentDashboard = dashboardProvider.currentDashboard;
    if (currentDashboard != null) {
      mqttProvider.setCurrentDashboard(currentDashboard);
    }

    // Step 3: Attempt auto-connection to all configured brokers
    await mqttProvider.autoConnect();

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

            if (dashboardProvider.dashboards.length <= 1) {
              // Show simple title when there's only one dashboard
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  currentDashboard?.name ?? 'MQTT Dashboard',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              );
            }

            // Show dropdown when there are multiple dashboards
            return Align(
              alignment: Alignment.centerLeft,
              child: _AnimatedDashboardSelector(
                currentDashboard: currentDashboard,
                dashboards: dashboardProvider.dashboards,
                onDashboardSelected: (dashboardId) async {
                  final selectedDashboard = dashboardProvider.dashboards.firstWhere((d) => d.id == dashboardId);
                  final messenger = ScaffoldMessenger.of(context);
                  final mqttProvider = Provider.of<MqttProvider>(context, listen: false);
                  await dashboardProvider.setCurrentDashboard(dashboardId);
                  if (mounted) {
                    mqttProvider.setCurrentDashboard(selectedDashboard);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Switched to ${selectedDashboard.name}'),
                      ),
                    );
                  }
                },
              ),
            );
          },
        ),
        actions: [
          Consumer2<MqttProvider, DashboardProvider>(
            builder: (context, mqttProvider, dashboardProvider, child) {
              final isConnected = mqttProvider.isCurrentConnected;
              return IconButton(
                icon: isConnected
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
    // Account for padding (16 total) and minimum spacing between columns
    const padding = 16.0;
    const minSpacing = 8.0;

    // Calculate max columns that won't cause negative width
    int calculateMaxColumns() {
      for (int cols in [6, 4, 3, 2]) {
        final totalSpacing = (cols - 1) * minSpacing;
        final availableWidth = screenWidth - padding - totalSpacing;
        if (availableWidth / cols > 0) {
          return cols;
        }
      }
      return 1; // Fallback to single column
    }

    final maxColumns = calculateMaxColumns();

    // Use responsive breakpoints but respect maxColumns
    if (screenWidth > 1200) return maxColumns < 6 ? maxColumns : 6;
    if (screenWidth > 800) return maxColumns < 4 ? maxColumns : 4;
    if (screenWidth > 600) return maxColumns < 3 ? maxColumns : 3;
    return maxColumns < 2 ? maxColumns : 2;
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
      builder: (context) => Consumer2<MqttProvider, DashboardProvider>(
        builder: (context, mqttProvider, dashboardProvider, child) {
          final currentDashboard = dashboardProvider.currentDashboard;
          final currentConfigId = currentDashboard?.mqttConfigId ?? '';
          final currentState = mqttProvider.currentConnectionState;
          final currentError = mqttProvider.currentErrorMessage;

          return AlertDialog(
            title: const Text('Connection Status'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current dashboard status
                  if (currentDashboard != null && currentConfigId.isNotEmpty) ...[
                    _buildConnectionStatusCard(
                      context: context,
                      title: 'Current Dashboard: ${currentDashboard.name}',
                      configId: currentConfigId,
                      state: currentState,
                      errorMessage: currentError,
                      isCurrent: true,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // All connections status
                  const Text(
                    'All MQTT Connections',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (mqttProvider.connectionStates.isEmpty)
                    const Text(
                      'No connections configured',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    ...mqttProvider.connectionStates.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _buildConnectionStatusCard(
                          context: context,
                          title: 'Config: ${entry.key}',
                          configId: entry.key,
                          state: entry.value,
                          errorMessage: mqttProvider.errorMessages[entry.key],
                          isCurrent: entry.key == currentConfigId,
                        ),
                      );
                    }),

                  const SizedBox(height: 16),

                  // Auto-connect status
                  Text(
                    'Auto-connect: ${mqttProvider.autoConnectEnabled ? "Enabled" : "Disabled"}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              if (currentState != MqttConnectionState.connected && currentConfigId.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await mqttProvider.connectToCurrentDashboardBroker();
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
          );
        },
      ),
    );
  }

  Widget _buildConnectionStatusCard({
    required BuildContext context,
    required String title,
    required String configId,
    required MqttConnectionState? state,
    required String? errorMessage,
    required bool isCurrent,
  }) {
    final color = _getConnectionStatusColor(state);
    final icon = _getConnectionStatusIcon(state);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isCurrent ? color : Colors.grey.shade300,
          width: isCurrent ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Current',
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.bolt, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                _getConnectionStatusText(state),
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                ),
              ),
            ],
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              errorMessage,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getConnectionStatusText(MqttConnectionState? state) {
    switch (state) {
      case MqttConnectionState.connected:
        return 'Connected';
      case MqttConnectionState.connecting:
        return 'Connecting...';
      case MqttConnectionState.disconnected:
        return 'Disconnected';
      case MqttConnectionState.faulted:
        return 'Connection faulted';
      default:
        return 'Unknown state';
    }
  }

  IconData _getConnectionStatusIcon(MqttConnectionState? state) {
    switch (state) {
      case MqttConnectionState.connected:
        return Icons.check_circle;
      case MqttConnectionState.connecting:
        return Icons.sync;
      case MqttConnectionState.disconnected:
      case MqttConnectionState.faulted:
        return Icons.error;
      default:
        return Icons.help_outline;
    }
  }

  Color _getConnectionStatusColor(MqttConnectionState? state) {
    switch (state) {
      case MqttConnectionState.connected:
        return Colors.green;
      case MqttConnectionState.connecting:
        return Colors.blue;
      case MqttConnectionState.disconnected:
      case MqttConnectionState.faulted:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _AnimatedDashboardSelector extends StatefulWidget {
  final Dashboard? currentDashboard;
  final List<Dashboard> dashboards;
  final Function(String) onDashboardSelected;

  const _AnimatedDashboardSelector({
    required this.currentDashboard,
    required this.dashboards,
    required this.onDashboardSelected,
  });

  @override
  State<_AnimatedDashboardSelector> createState() => _AnimatedDashboardSelectorState();
}

class _AnimatedDashboardSelectorState extends State<_AnimatedDashboardSelector> {
  void _showDashboardMenu() async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset position =
        button.localToGlobal(Offset.zero, ancestor: overlay);
    final Size size = button.size;

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(0, position.dy + size.height, position.dx, size.height),
        Offset.zero & overlay.size,
      ),
      items: widget.dashboards.map((dashboard) {
        final isSelected = dashboard.id == widget.currentDashboard?.id;
        return PopupMenuItem<String>(
          value: dashboard.id,
          child: Row(
            children: [
              if (isSelected)
                Icon(
                  Icons.check,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                )
              else
                const SizedBox(width: 18),
              if (isSelected) const SizedBox(width: 12),
              Expanded(
                child: Text(
                  dashboard.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );

    if (result != null) {
      widget.onDashboardSelected(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _showDashboardMenu,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.currentDashboard?.name ?? 'Select Dashboard',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

