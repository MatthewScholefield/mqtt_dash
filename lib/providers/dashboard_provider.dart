import 'package:flutter/material.dart';
import '../models/dashboard.dart';
import '../models/dashboard_widget.dart';
import '../core/config_service.dart';
import '../core/logger.dart';

class DashboardProvider extends ChangeNotifier {
  final ConfigService _configService = ConfigService();

  List<Dashboard> _dashboards = [];
  Dashboard? _currentDashboard;
  bool _isLoading = false;

  List<Dashboard> get dashboards => List.from(_dashboards);
  Dashboard? get currentDashboard => _currentDashboard;
  bool get isLoading => _isLoading;

  Future<void> loadDashboards() async {
    _isLoading = true;
    notifyListeners();

    try {
      _dashboards = await _configService.loadDashboards();
      await _loadCurrentDashboard();
    } catch (e) {
      AppLogger.warning('Failed to load dashboards on initialization', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCurrentDashboard() async {
    final currentDashboardId = await _configService.getCurrentDashboardId();
    if (currentDashboardId != null) {
      _currentDashboard = _dashboards.where((d) => d.id == currentDashboardId).firstOrNull;
    } else if (_dashboards.isNotEmpty) {
      _currentDashboard = _dashboards.first;
    } else {
      _currentDashboard = null;
    }
  }

  Future<void> createDashboard({
    required String name,
    required String description,
    required String mqttConfigId,
  }) async {
    try {
      final dashboard = Dashboard(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        description: description,
        mqttConfigId: mqttConfigId,
        widgets: [],
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
      );

      await _configService.saveDashboard(dashboard);
      _dashboards.add(dashboard);
      await setCurrentDashboard(dashboard.id);
      notifyListeners();
    } catch (e) {
      AppLogger.warning('Failed to create dashboard', e);
    }
  }

  Future<void> updateDashboard(Dashboard dashboard) async {
    try {
      await _configService.saveDashboard(dashboard);

      final index = _dashboards.indexWhere((d) => d.id == dashboard.id);
      if (index >= 0) {
        _dashboards[index] = dashboard;
      }

      if (_currentDashboard?.id == dashboard.id) {
        _currentDashboard = dashboard;
      }

      notifyListeners();
    } catch (e) {
      AppLogger.warning('Failed to update dashboard', e);
    }
  }

  Future<void> deleteDashboard(String dashboardId) async {
    try {
      await _configService.deleteDashboard(dashboardId);
      _dashboards.removeWhere((d) => d.id == dashboardId);

      if (_currentDashboard?.id == dashboardId) {
        if (_dashboards.isNotEmpty) {
          await setCurrentDashboard(_dashboards.first.id);
        } else {
          _currentDashboard = null;
        }
      }

      notifyListeners();
    } catch (e) {
      AppLogger.warning('Failed to delete dashboard', e);
    }
  }

  Future<void> setCurrentDashboard(String dashboardId) async {
    try {
      await _configService.setCurrentDashboardId(dashboardId);
      await _loadCurrentDashboard();
      notifyListeners();
    } catch (e) {
      AppLogger.warning('Failed to set current dashboard', e);
    }
  }

  Future<void> addWidget(DashboardWidget widget) async {
    if (_currentDashboard == null) return;

    try {
      final updatedDashboard = _currentDashboard!.addWidget(widget);
      await updateDashboard(updatedDashboard);
    } catch (e) {
      AppLogger.warning('Failed to add widget', e);
    }
  }

  Future<void> updateWidget(DashboardWidget widget) async {
    if (_currentDashboard == null) return;

    try {
      final updatedDashboard = _currentDashboard!.addWidget(widget);
      await updateDashboard(updatedDashboard);
    } catch (e) {
      AppLogger.warning('Failed to update widget', e);
    }
  }

  Future<void> removeWidget(String widgetId) async {
    if (_currentDashboard == null) return;

    try {
      final updatedDashboard = _currentDashboard!.removeWidget(widgetId);
      await updateDashboard(updatedDashboard);
    } catch (e) {
      AppLogger.warning('Failed to remove widget', e);
    }
  }

  Future<void> initializeDefaults() async {
    try {
      await _configService.initializeDefaults();
      await loadDashboards();
    } catch (e) {
      AppLogger.warning('Failed to initialize defaults', e);
    }
  }
}