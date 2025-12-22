import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dashboard.dart';
import '../providers/dashboard_provider.dart';
import '../providers/mqtt_provider.dart';

class DashboardsScreen extends StatefulWidget {
  const DashboardsScreen({super.key});

  @override
  State<DashboardsScreen> createState() => _DashboardsScreenState();
}

class _DashboardsScreenState extends State<DashboardsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Dashboards'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<DashboardProvider>(
        builder: (context, dashboardProvider, child) {
          if (dashboardProvider.dashboards.isEmpty) {
            return const _EmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: dashboardProvider.dashboards.length,
            itemBuilder: (context, index) {
              final dashboard = dashboardProvider.dashboards[index];
              final isCurrent = dashboardProvider.currentDashboard?.id == dashboard.id;

              return _DashboardListItem(
                dashboard: dashboard,
                isCurrent: isCurrent,
                onSelect: () => _selectDashboard(dashboard),
                onEdit: () => _editDashboardName(dashboard),
                onDelete: () => _deleteDashboard(dashboard),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createDashboard,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _selectDashboard(Dashboard dashboard) async {
    final dashboardProvider = context.read<DashboardProvider>();
    await dashboardProvider.setCurrentDashboard(dashboard.id);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Switched to ${dashboard.name}')),
      );
    }
  }

  void _editDashboardName(Dashboard dashboard) {
    showDialog(
      context: context,
      builder: (context) => _EditDashboardDialog(dashboard: dashboard),
    );
  }

  void _deleteDashboard(Dashboard dashboard) {
    if (context.read<DashboardProvider>().dashboards.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the last dashboard')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _DeleteDashboardDialog(dashboard: dashboard),
    );
  }

  void _createDashboard() {
    showDialog(
      context: context,
      builder: (context) => const _CreateDashboardDialog(),
    );
  }
}

class _DashboardListItem extends StatelessWidget {
  final Dashboard dashboard;
  final bool isCurrent;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DashboardListItem({
    required this.dashboard,
    required this.isCurrent,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isCurrent ? 4 : 2,
      color: isCurrent ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            Icons.dashboard,
            color: isCurrent
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          dashboard.name,
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dashboard.description.isNotEmpty)
              Text(dashboard.description),
            const SizedBox(height: 4),
            Text(
              '${dashboard.widgets.length} widget${dashboard.widgets.length != 1 ? 's' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEdit();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit Name'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: onSelect,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dashboard_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No dashboards yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first dashboard to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Use the + button to create a dashboard')),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Dashboard'),
          ),
        ],
      ),
    );
  }
}

class _EditDashboardDialog extends StatefulWidget {
  final Dashboard dashboard;

  const _EditDashboardDialog({required this.dashboard});

  @override
  State<_EditDashboardDialog> createState() => _EditDashboardDialogState();
}

class _EditDashboardDialogState extends State<_EditDashboardDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.dashboard.name);
    _descriptionController = TextEditingController(text: widget.dashboard.description);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Dashboard'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Dashboard Name',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveDashboard,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _saveDashboard() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dashboard name cannot be empty')),
      );
      return;
    }

    final dashboardProvider = context.read<DashboardProvider>();

    // Check for duplicate names (excluding current dashboard)
    if (dashboardProvider.dashboards.any((d) =>
        d.name.toLowerCase() == name.toLowerCase() && d.id != widget.dashboard.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A dashboard with this name already exists')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedDashboard = widget.dashboard.copyWith(
        name: name,
        description: _descriptionController.text.trim(),
      );

      await dashboardProvider.updateDashboard(updatedDashboard);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dashboard updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update dashboard: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

class _CreateDashboardDialog extends StatefulWidget {
  const _CreateDashboardDialog();

  @override
  State<_CreateDashboardDialog> createState() => _CreateDashboardDialogState();
}

class _CreateDashboardDialogState extends State<_CreateDashboardDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Dashboard'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Dashboard Name',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createDashboard,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _createDashboard() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dashboard name cannot be empty')),
      );
      return;
    }

    final dashboardProvider = context.read<DashboardProvider>();

    // Check for duplicate names
    if (dashboardProvider.dashboards.any((d) =>
        d.name.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A dashboard with this name already exists')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get current MQTT config to use for new dashboard
      final mqttProvider = context.read<MqttProvider>();
      final mqttConfigId = mqttProvider.lastConnectedConfigId ?? 'default';

      final newDashboard = await dashboardProvider.createDashboard(
        name: name,
        description: _descriptionController.text.trim(),
        mqttConfigId: mqttConfigId,
      );

      // Switch to the new dashboard
      await dashboardProvider.setCurrentDashboard(newDashboard.id);

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        Navigator.of(context).pop(); // Go back to dashboard screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dashboard "$name" created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create dashboard: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

class _DeleteDashboardDialog extends StatelessWidget {
  final Dashboard dashboard;

  const _DeleteDashboardDialog({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Dashboard'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Are you sure you want to delete "${dashboard.name}"?'),
          const SizedBox(height: 8),
          if (dashboard.widgets.isNotEmpty)
            Text(
              'This will also remove ${dashboard.widgets.length} widget${dashboard.widgets.length != 1 ? 's' : ''} from this dashboard.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => _confirmDelete(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final dashboardProvider = context.read<DashboardProvider>();
    final wasCurrent = dashboardProvider.currentDashboard?.id == dashboard.id;

    try {
      await dashboardProvider.deleteDashboard(dashboard.id);

      if (wasCurrent && dashboardProvider.dashboards.isNotEmpty) {
        // Switch to another dashboard if we deleted the current one
        await dashboardProvider.setCurrentDashboard(dashboardProvider.dashboards.first.id);
      }

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dashboard "${dashboard.name}" deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete dashboard: $e')),
        );
      }
    }
  }
}