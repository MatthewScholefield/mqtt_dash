# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a cross-platform Flutter IoT dashboard application for MQTT device control and monitoring. It provides a widget-based interface to control smart devices through MQTT brokers.

## Development Commands

```bash
# Install dependencies
flutter pub get

# Run in development mode
flutter run

# Build for release
flutter build apk --release          # Android
flutter build appbundle --release    # Android Play Store
flutter build ios --release          # iOS
flutter build web --release          # Web
flutter build linux --release        # Linux
flutter build macos --release        # macOS
flutter build windows --release      # Windows

# Code analysis
flutter analyze

# Run tests
flutter test

# Generate JSON serialization code (required after model changes)
flutter pub run build_runner build --delete-conflicting-outputs
```

## Architecture

The application follows a clean architecture pattern with clear separation of concerns:

### Core Services (`lib/core/`)
- **mqtt_service.dart**: Main MQTT service with platform-specific implementations
- **web_mqtt_service.dart**: Web-specific MQTT implementation using WebSocket
- **config_service.dart**: Local storage and configuration persistence using SharedPreferences

### State Management (`lib/providers/`)
- Uses Provider pattern for state management
- **mqtt_provider.dart**: Manages MQTT connection state and message handling
- **dashboard_provider.dart**: Manages dashboard configuration and widget state

### Data Models (`lib/models/`)
- **dashboard.dart**: Dashboard configuration with JSON serialization
- **dashboard_widget.dart**: Widget definitions and properties
- **mqtt_config.dart**: MQTT connection settings
- All models use `json_annotation` for serialization

### Widget System (`lib/widgets/`)
- **base/dashboard_widget_base.dart**: Abstract base class for all widget types
- **button_widget.dart**: Button widget implementation
- Widget types: button, textDisplay, sensorDisplay, toggleSwitch
- Each widget maps to MQTT topics for on/off/unknown states

### UI Screens (`lib/screens/`)
- **dashboard_screen.dart**: Main dashboard with staggered grid layout
- **mqtt_settings_screen.dart**: MQTT broker connection configuration
- **widget_settings_screen.dart**: Individual widget configuration

## Key Technical Details

### MQTT Integration
- Supports both WebSocket (web) and TCP (native) connections
- Platform-specific implementations in `core/mqtt_service.dart`
- Automatic reconnection with resubscription to topics
- Authentication support (username/password)

### Data Persistence
- Uses SharedPreferences for local storage
- JSON serialization for complex objects
- Default configurations for first-time users
- Stores dashboard layouts and MQTT settings

### Cross-Platform Considerations
- Web platform uses WebSocket MQTT connection
- Native platforms use TCP MQTT connection
- Conditional imports based on platform
- Responsive design for different screen sizes

## Development Workflow

1. **After model changes**: Run `flutter pub run build_runner build` to regenerate serialization code
2. **Testing**: Use Flutter's built-in testing framework
3. **Platform testing**: Test on web and native platforms due to MQTT implementation differences
4. **State management**: All state updates go through Provider instances

## Code Generation

The project uses build_runner for JSON serialization. After modifying any model files in `lib/models/`, regenerate the serialization code:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## MQTT Widget Configuration

Each widget type requires:
- MQTT topic mapping for different states
- Icon configuration for visual feedback
- Position and size in the grid layout
- State-based behavior (on/off/unknown)

## Platform-Specific Notes

- **Web**: MQTT connections use WebSocket protocol
- **Native**: MQTT connections use TCP protocol
- **All platforms**: State management and UI are shared

The codebase is well-structured for adding new widget types, extending MQTT functionality, or enhancing the dashboard features.