import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pc_control_center/core/models/telemetry_model.dart';
import 'package:pc_control_center/core/network/api_client.dart';
import 'package:pc_control_center/core/network/websocket_client.dart';

// Stream of unified telemetry from WebSocket
final telemetryStreamProvider = StreamProvider.autoDispose<UnifiedTelemetryFrameModel>((ref) {
  return telemetryWsClient.telemetryStream;
});

// Stream of connection status
final connectionStatusProvider = StreamProvider.autoDispose<ConnectionStatus>((ref) {
  return telemetryWsClient.statusStream;
});

// Stream of network latency in milliseconds
final latencyStreamProvider = StreamProvider.autoDispose<int>((ref) {
  return telemetryWsClient.latencyStream;
});

// Stream of stale state (true if no frames received in >2.5s)
final isStaleStreamProvider = StreamProvider.autoDispose<bool>((ref) {
  return telemetryWsClient.staleStream;
});

// Audio actions provider
class AudioController {
  Future<bool> setVolume(int volume) => apiClient.setVolume(volume);
  Future<bool> stepVolume(int delta) => apiClient.stepVolume(delta);
  Future<bool> setMute(bool mute) => apiClient.setMute(mute);
  Future<bool> toggleMute() => apiClient.toggleMute();
  Future<bool> switchDevice(String deviceId) => apiClient.switchAudioDevice(deviceId);
}

final audioControllerProvider = Provider<AudioController>((ref) {
  return AudioController();
});

// Media actions provider
class MediaController {
  Future<bool> play() => apiClient.controlMedia("play");
  Future<bool> pause() => apiClient.controlMedia("pause");
  Future<bool> toggle() => apiClient.controlMedia("toggle");
  Future<bool> next() => apiClient.controlMedia("next");
  Future<bool> previous() => apiClient.controlMedia("previous");
  Future<bool> seek(int positionMs) => apiClient.controlMedia("seek", positionMs: positionMs);
}

final mediaControllerProvider = Provider<MediaController>((ref) {
  return MediaController();
});

// Display actions provider
class DisplayController {
  Future<bool> setBrightness(int brightness) => apiClient.setBrightness(brightness);
}

final displayControllerProvider = Provider<DisplayController>((ref) {
  return DisplayController();
});

// Power actions provider
class PowerController {
  Future<bool> lock() => apiClient.executePowerAction("lock");
  Future<bool> sleep() => apiClient.executePowerAction("sleep");
  Future<bool> displayOff() => apiClient.executePowerAction("display_off");
  Future<bool> displayOn() => apiClient.executePowerAction("display_on");
  Future<bool> screenOff() => apiClient.executePowerAction("screen_off");
  Future<bool> screenOn() => apiClient.executePowerAction("screen_on");
  Future<bool> restart({int delaySeconds = 0, bool force = false}) =>
      apiClient.executePowerAction("restart", delaySeconds: delaySeconds, force: force);
  Future<bool> shutdown({int delaySeconds = 0, bool force = false}) =>
      apiClient.executePowerAction("shutdown", delaySeconds: delaySeconds, force: force);
  Future<bool> cancel() => apiClient.cancelPowerAction();
}

final powerControllerProvider = Provider<PowerController>((ref) {
  return PowerController();
});

// Extras actions provider
class ExtrasController {
  Future<bool> setClipboard(String text) => apiClient.setClipboard(text);
  Future<bool> openUrl(String url) => apiClient.openUrl(url);
  Future<bool> showToast(String title, String message) => apiClient.showToast(title, message);
}

final extrasControllerProvider = Provider<ExtrasController>((ref) {
  return ExtrasController();
});
