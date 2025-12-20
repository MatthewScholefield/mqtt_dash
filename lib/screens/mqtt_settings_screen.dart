import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../models/mqtt_config.dart';
import '../providers/mqtt_provider.dart';
import '../core/config_service.dart';

class MqttSettingsScreen extends StatefulWidget {
  const MqttSettingsScreen({super.key});

  @override
  State<MqttSettingsScreen> createState() => _MqttSettingsScreenState();
}

class _MqttSettingsScreenState extends State<MqttSettingsScreen> {
  final ConfigService _configService = ConfigService();
  List<MqttConfig> _configs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final configs = await _configService.loadMqttConfigs();
      setState(() {
        _configs = configs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading configs: $e')),
      );
    }
  }

  Future<void> _deleteConfig(MqttConfig config) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Configuration'),
        content: Text('Are you sure you want to delete "${config.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _configService.deleteMqttConfig(config.id);
        await _loadConfigs();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration deleted')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting config: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MQTT Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _configs.isEmpty
              ? _buildEmptyState()
              : _buildConfigsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddConfigDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.settings_ethernet,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No MQTT configurations',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first MQTT broker configuration',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddConfigDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Configuration'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _configs.length,
      itemBuilder: (context, index) {
        final config = _configs[index];
        return _buildConfigCard(config);
      },
    );
  }

  Widget _buildConfigCard(MqttConfig config) {
    return Consumer<MqttProvider>(
      builder: (context, mqttProvider, child) => Card(
        margin: const EdgeInsets.only(bottom: 12.0),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: config.useTls ? Colors.green : Colors.blue,
            child: Icon(
              config.useTls ? Icons.lock : Icons.public,
              color: Colors.white,
            ),
          ),
          title: Text(config.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${config.host}:${config.port}'),
              if (config.username.isNotEmpty)
                Text('Username: ${config.username}'),
              Row(
                children: [
                  Icon(
                    mqttProvider.connectionState == MqttConnectionState.connected
                        ? Icons.circle
                        : Icons.circle_outlined,
                    size: 8,
                    color: mqttProvider.connectionState == MqttConnectionState.connected
                        ? Colors.green
                        : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    mqttProvider.connectionState == MqttConnectionState.connected
                        ? 'Connected'
                        : 'Disconnected',
                    style: TextStyle(
                      fontSize: 12,
                      color: mqttProvider.connectionState == MqttConnectionState.connected
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) => _handleConfigAction(value, config),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'connect',
                child: ListTile(
                  leading: Icon(mqttProvider.connectionState == MqttConnectionState.connected
                      ? Icons.link_off
                      : Icons.connect_without_contact),
                  title: Text(mqttProvider.connectionState == MqttConnectionState.connected
                      ? 'Disconnect'
                      : 'Connect'),
                ),
              ),
              PopupMenuItem(
                value: 'edit',
                child: const ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Edit'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: const ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete'),
                ),
              ),
            ],
          ),
          onTap: () => _connectToConfig(config),
        ),
      ),
    );
  }

  void _handleConfigAction(String action, MqttConfig config) {
    switch (action) {
      case 'connect':
        if (context.mounted) {
          final mqttProvider = Provider.of<MqttProvider>(context, listen: false);
          if (mqttProvider.connectionState == MqttConnectionState.connected) {
            mqttProvider.disconnect();
          } else {
            _connectToConfig(config);
          }
        }
        break;
      case 'edit':
        _showEditConfigDialog(config);
        break;
      case 'delete':
        _deleteConfig(config);
        break;
    }
  }

  Future<void> _connectToConfig(MqttConfig config) async {
    final mqttProvider = Provider.of<MqttProvider>(context, listen: false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connecting to MQTT broker...')),
    );

    final success = await mqttProvider.connect(config);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to ${config.name}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mqttProvider.errorMessage ?? 'Connection failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => MqttConfigDialog(
        onSave: (config) async {
          await _configService.saveMqttConfig(config);
          await _loadConfigs();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Configuration saved')),
          );
        },
      ),
    );
  }

  void _showEditConfigDialog(MqttConfig config) {
    showDialog(
      context: context,
      builder: (context) => MqttConfigDialog(
        config: config,
        onSave: (config) async {
          await _configService.saveMqttConfig(config);
          await _loadConfigs();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Configuration updated')),
          );
        },
      ),
    );
  }
}

class MqttConfigDialog extends StatefulWidget {
  final MqttConfig? config;
  final Function(MqttConfig) onSave;

  const MqttConfigDialog({
    super.key,
    this.config,
    required this.onSave,
  });

  @override
  State<MqttConfigDialog> createState() => _MqttConfigDialogState();
}

class _MqttConfigDialogState extends State<MqttConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _clientIdController;

  bool _useTls = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.config?.name ?? '');
    _hostController = TextEditingController(text: widget.config?.host ?? '');
    _portController = TextEditingController(text: widget.config?.port.toString() ?? '1883');
    _usernameController = TextEditingController(text: widget.config?.username ?? '');
    _passwordController = TextEditingController(text: widget.config?.password ?? '');
    _clientIdController = TextEditingController(text: widget.config?.clientId ?? '');

    _useTls = widget.config?.useTls ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _clientIdController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final config = MqttConfig(
      id: widget.config?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      host: _hostController.text,
      port: int.parse(_portController.text),
      username: _usernameController.text,
      password: _passwordController.text,
      useTls: _useTls,
      clientId: _clientIdController.text.isNotEmpty ? _clientIdController.text : null,
    );

    widget.onSave(config);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.config == null ? 'Add MQTT Configuration' : 'Edit Configuration'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: ListView(
            shrinkWrap: true,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Configuration Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'Host',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., broker.hivemq.com',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a host';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  border: OutlineInputBorder(),
                  hintText: '1883',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a port';
                  }
                  final port = int.tryParse(value);
                  if (port == null || port <= 0 || port > 65535) {
                    return 'Please enter a valid port';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password (optional)',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _clientIdController,
                decoration: const InputDecoration(
                  labelText: 'Client ID (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'Leave empty for auto-generated',
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Use TLS/SSL'),
                subtitle: const Text('Enable secure connection'),
                value: _useTls,
                onChanged: (value) {
                  setState(() {
                    _useTls = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}