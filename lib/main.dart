import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/mqtt_provider.dart';
import 'providers/dashboard_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/dashboards_screen.dart';
import 'screens/mqtt_settings_screen.dart';
import 'screens/widget_settings_screen.dart';
import 'models/dashboard_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MqttProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: MaterialApp(
        title: 'MQTT Dashboard',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          cardTheme: const CardThemeData(
            elevation: 2,
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 2,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            elevation: 4,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          cardTheme: const CardThemeData(
            elevation: 4,
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 2,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            elevation: 6,
          ),
        ),
        themeMode: ThemeMode.system,
        home: const DashboardScreen(),
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/dashboards':
              return MaterialPageRoute(
                builder: (context) => const DashboardsScreen(),
              );
            case '/mqtt_settings':
              return MaterialPageRoute(
                builder: (context) => const MqttSettingsScreen(),
              );
            case '/widget_settings':
              final args = settings.arguments;
              return MaterialPageRoute(
                builder: (context) => WidgetSettingsScreen(widget: args as DashboardWidget?),
              );
            default:
              return MaterialPageRoute(
                builder: (context) => const DashboardScreen(),
              );
          }
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
