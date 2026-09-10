import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pc_control_center/core/network/input_websocket_client.dart';
import 'package:pc_control_center/core/network/websocket_client.dart' show ConnectionStatus;
import 'package:pc_control_center/core/providers/settings_provider.dart';

class TrackpadPreferences {
  final double sensitivity;
  final bool isNaturalScroll;
  final bool showHotkeys;

  const TrackpadPreferences({
    this.sensitivity = 1.2,
    this.isNaturalScroll = true,
    this.showHotkeys = true,
  });

  TrackpadPreferences copyWith({
    double? sensitivity,
    bool? isNaturalScroll,
    bool? showHotkeys,
  }) {
    return TrackpadPreferences(
      sensitivity: sensitivity ?? this.sensitivity,
      isNaturalScroll: isNaturalScroll ?? this.isNaturalScroll,
      showHotkeys: showHotkeys ?? this.showHotkeys,
    );
  }
}

class TrackpadPreferencesNotifier extends StateNotifier<TrackpadPreferences> {
  TrackpadPreferencesNotifier() : super(const TrackpadPreferences()) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sensitivity = prefs.getDouble('pcc_trackpad_sensitivity') ?? 1.2;
      final isNaturalScroll = prefs.getBool('pcc_trackpad_natural_scroll') ?? true;
      final showHotkeys = prefs.getBool('pcc_trackpad_show_hotkeys') ?? true;

      state = TrackpadPreferences(
        sensitivity: sensitivity,
        isNaturalScroll: isNaturalScroll,
        showHotkeys: showHotkeys,
      );
    } catch (_) {}
  }

  Future<void> setSensitivity(double value) async {
    state = state.copyWith(sensitivity: value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('pcc_trackpad_sensitivity', value);
    } catch (_) {}
  }

  Future<void> setNaturalScroll(bool value) async {
    state = state.copyWith(isNaturalScroll: value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pcc_trackpad_natural_scroll', value);
    } catch (_) {}
  }

  Future<void> setShowHotkeys(bool value) async {
    state = state.copyWith(showHotkeys: value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pcc_trackpad_show_hotkeys', value);
    } catch (_) {}
  }
}

final trackpadPreferencesProvider =
    StateNotifierProvider<TrackpadPreferencesNotifier, TrackpadPreferences>((ref) {
  return TrackpadPreferencesNotifier();
});

final inputConnectionStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  final settings = ref.watch(settingsProvider);
  inputWsClient.configure(
    host: settings.host,
    port: settings.port,
    apiKey: settings.apiKey,
  );
  return inputWsClient.statusStream;
});
