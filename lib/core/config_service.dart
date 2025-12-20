import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mqtt_config.dart';
import '../models/dashboard.dart';

class ConfigService {
  static const String _mqttConfigsKey = 'mqtt_configs';
  static const String _dashboardsKey = 'dashboards';
  static const String _currentDashboardKey = 'current_dashboard';

  Future<void> saveMqttConfigs(List<MqttConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    final configsJson = configs.map((config) => config.toJson()).toList();
    await prefs.setString(_mqttConfigsKey, jsonEncode(configsJson));
  }

  Future<List<MqttConfig>> loadMqttConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final configsJsonString = prefs.getString(_mqttConfigsKey);

    if (configsJsonString == null) {
      return [];
    }

    try {
      final configsJson = jsonDecode(configsJsonString) as List;
      return configsJson.map((json) => MqttConfig.fromJson(json)).toList();
    } catch (e) {
      print('Error loading MQTT configs: $e');
      return [];
    }
  }

  Future<void> saveMqttConfig(MqttConfig config) async {
    final configs = await loadMqttConfigs();
    final index = configs.indexWhere((c) => c.id == config.id);

    if (index >= 0) {
      configs[index] = config;
    } else {
      configs.add(config);
    }

    await saveMqttConfigs(configs);
  }

  Future<void> deleteMqttConfig(String configId) async {
    final configs = await loadMqttConfigs();
    configs.removeWhere((c) => c.id == configId);
    await saveMqttConfigs(configs);
  }

  Future<void> saveDashboards(List<Dashboard> dashboards) async {
    final prefs = await SharedPreferences.getInstance();
    final dashboardsJson = dashboards.map((dashboard) => dashboard.toJson()).toList();
    await prefs.setString(_dashboardsKey, jsonEncode(dashboardsJson));
  }

  Future<List<Dashboard>> loadDashboards() async {
    final prefs = await SharedPreferences.getInstance();
    final dashboardsJsonString = prefs.getString(_dashboardsKey);

    if (dashboardsJsonString == null) {
      return [];
    }

    try {
      final dashboardsJson = jsonDecode(dashboardsJsonString) as List;
      return dashboardsJson.map((json) => Dashboard.fromJson(json)).toList();
    } catch (e) {
      print('Error loading dashboards: $e');
      return [];
    }
  }

  Future<void> saveDashboard(Dashboard dashboard) async {
    final dashboards = await loadDashboards();
    final index = dashboards.indexWhere((d) => d.id == dashboard.id);

    if (index >= 0) {
      dashboards[index] = dashboard;
    } else {
      dashboards.add(dashboard);
    }

    await saveDashboards(dashboards);
  }

  Future<void> deleteDashboard(String dashboardId) async {
    final dashboards = await loadDashboards();
    dashboards.removeWhere((d) => d.id == dashboardId);
    await saveDashboards(dashboards);

    final currentDashboardId = await getCurrentDashboardId();
    if (currentDashboardId == dashboardId) {
      await setCurrentDashboardId(null);
    }
  }

  Future<void> setCurrentDashboardId(String? dashboardId) async {
    final prefs = await SharedPreferences.getInstance();
    if (dashboardId == null) {
      await prefs.remove(_currentDashboardKey);
    } else {
      await prefs.setString(_currentDashboardKey, dashboardId);
    }
  }

  Future<String?> getCurrentDashboardId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentDashboardKey);
  }

  Future<Dashboard?> getCurrentDashboard() async {
    final dashboardId = await getCurrentDashboardId();
    if (dashboardId == null) return null;

    final dashboards = await loadDashboards();
    try {
      return dashboards.firstWhere((d) => d.id == dashboardId);
    } catch (e) {
      return null;
    }
  }

  Future<Dashboard?> getDashboardById(String dashboardId) async {
    final dashboards = await loadDashboards();
    try {
      return dashboards.firstWhere((d) => d.id == dashboardId);
    } catch (e) {
      return null;
    }
  }

  Future<MqttConfig?> getMqttConfigById(String configId) async {
    final configs = await loadMqttConfigs();
    try {
      return configs.firstWhere((c) => c.id == configId);
    } catch (e) {
      return null;
    }
  }

  Future<void> createDefaultDashboardIfNeeded() async {
    final dashboards = await loadDashboards();
    if (dashboards.isEmpty) {
      final defaultDashboard = Dashboard(
        id: 'default',
        name: 'Default Dashboard',
        description: 'Your first MQTT dashboard',
        mqttConfigId: '',
        widgets: [],
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
      );
      await saveDashboard(defaultDashboard);
      await setCurrentDashboardId(defaultDashboard.id);
    }
  }

  Future<void> createDefaultMqttConfigIfNeeded() async {
    final configs = await loadMqttConfigs();
    if (configs.isEmpty) {
      final defaultConfig = MqttConfig(
        id: 'default',
        name: 'Default MQTT Broker',
        host: 'localhost',
        port: 1883,
        username: '',
        password: '',
      );
      await saveMqttConfig(defaultConfig);
    }
  }

  Future<void> initializeDefaults() async {
    await createDefaultMqttConfigIfNeeded();
    await createDefaultDashboardIfNeeded();
  }
}