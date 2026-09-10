import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pc_control_center/core/network/api_client.dart';
import 'package:pc_control_center/core/network/websocket_client.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';

class SettingsState {
  final String host;
  final int port;
  final String apiKey;
  final AppThemeMode themeMode;
  final bool autoConnect;
  final bool hapticsEnabled;

  SettingsState({
    required this.host,
    required this.port,
    required this.apiKey,
    required this.themeMode,
    required this.autoConnect,
    required this.hapticsEnabled,
  });

  SettingsState copyWith({
    String? host,
    int? port,
    String? apiKey,
    AppThemeMode? themeMode,
    bool? autoConnect,
    bool? hapticsEnabled,
  }) {
    return SettingsState(
      host: host ?? this.host,
      port: port ?? this.port,
      apiKey: apiKey ?? this.apiKey,
      themeMode: themeMode ?? this.themeMode,
      autoConnect: autoConnect ?? this.autoConnect,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier()
      : super(SettingsState(
          host: "192.168.29.249",
          port: 8765,
          apiKey: "6836b828f758dfa0",
          themeMode: AppThemeMode.cyberDark,
          autoConnect: true,
          hapticsEnabled: true,
        )) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final host = prefs.getString('pcc_host') ?? "192.168.29.249";
      final port = prefs.getInt('pcc_port') ?? 8765;
      final apiKey = prefs.getString('pcc_api_key') ?? "6836b828f758dfa0";
      final themeIndex = prefs.getInt('pcc_theme') ?? 0;
      final autoConnect = prefs.getBool('pcc_autoconnect') ?? true;
      final haptics = prefs.getBool('pcc_haptics') ?? true;

      final themeMode = AppThemeMode.values[themeIndex % AppThemeMode.values.length];

      state = SettingsState(
        host: host,
        port: port,
        apiKey: apiKey,
        themeMode: themeMode,
        autoConnect: autoConnect,
        hapticsEnabled: haptics,
      );

      _syncNetworkClients();
    } catch (_) {}
  }

  void _syncNetworkClients() {
    apiClient.updateConfig(host: state.host, port: state.port, apiKey: state.apiKey);
    telemetryWsClient.configure(host: state.host, port: state.port, apiKey: state.apiKey);
    if (state.autoConnect) {
      telemetryWsClient.connect();
    }
  }

  Future<void> updateHost(String newHost) async {
    state = state.copyWith(host: newHost.trim());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pcc_host', state.host);
    _syncNetworkClients();
  }

  Future<void> updatePort(int newPort) async {
    state = state.copyWith(port: newPort);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pcc_port', state.port);
    _syncNetworkClients();
  }

  Future<void> updateApiKey(String newKey) async {
    state = state.copyWith(apiKey: newKey.trim());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pcc_api_key', state.apiKey);
    _syncNetworkClients();
  }

  Future<void> updateTheme(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pcc_theme', mode.index);
  }

  Future<void> toggleHaptics(bool enabled) async {
    state = state.copyWith(hapticsEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pcc_haptics', enabled);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
