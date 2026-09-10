class DiskInfoModel {
  final String mount;
  final double totalGb;
  final double usedGb;
  final double freeGb;
  final double percent;

  DiskInfoModel({
    required this.mount,
    required this.totalGb,
    required this.usedGb,
    required this.freeGb,
    required this.percent,
  });

  factory DiskInfoModel.fromJson(Map<String, dynamic> json) {
    return DiskInfoModel(
      mount: json['mount'] ?? '',
      totalGb: (json['total_gb'] as num?)?.toDouble() ?? 0.0,
      usedGb: (json['used_gb'] as num?)?.toDouble() ?? 0.0,
      freeGb: (json['free_gb'] as num?)?.toDouble() ?? 0.0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class NetworkRateModel {
  final double downloadKbps;
  final double uploadKbps;
  final double totalDownloadMb;
  final double totalUploadMb;

  NetworkRateModel({
    required this.downloadKbps,
    required this.uploadKbps,
    required this.totalDownloadMb,
    required this.totalUploadMb,
  });

  factory NetworkRateModel.fromJson(Map<String, dynamic> json) {
    return NetworkRateModel(
      downloadKbps: (json['download_kbps'] as num?)?.toDouble() ?? 0.0,
      uploadKbps: (json['upload_kbps'] as num?)?.toDouble() ?? 0.0,
      totalDownloadMb: (json['total_download_mb'] as num?)?.toDouble() ?? 0.0,
      totalUploadMb: (json['total_upload_mb'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class GpuInfoModel {
  final bool available;
  final String? name;
  final double? loadPercent;
  final double? temperatureC;
  final double? vramUsedMb;
  final double? vramTotalMb;

  GpuInfoModel({
    this.available = false,
    this.name,
    this.loadPercent,
    this.temperatureC,
    this.vramUsedMb,
    this.vramTotalMb,
  });

  factory GpuInfoModel.fromJson(Map<String, dynamic> json) {
    return GpuInfoModel(
      available: json['available'] ?? false,
      name: json['name'],
      loadPercent: (json['load_percent'] as num?)?.toDouble(),
      temperatureC: (json['temperature_c'] as num?)?.toDouble(),
      vramUsedMb: (json['vram_used_mb'] as num?)?.toDouble(),
      vramTotalMb: (json['vram_total_mb'] as num?)?.toDouble(),
    );
  }
}

class BatteryInfoModel {
  final bool present;
  final double? percent;
  final bool? powerPlugged;
  final int? secondsLeft;

  BatteryInfoModel({
    this.present = false,
    this.percent,
    this.powerPlugged,
    this.secondsLeft,
  });

  factory BatteryInfoModel.fromJson(Map<String, dynamic> json) {
    return BatteryInfoModel(
      present: json['present'] ?? false,
      percent: (json['percent'] as num?)?.toDouble(),
      powerPlugged: json['power_plugged'],
      secondsLeft: json['seconds_left'],
    );
  }
}

class SystemTelemetryModel {
  final double cpuPercent;
  final List<double> cpuCoresPercent;
  final double? cpuFreqMhz;
  final double ramPercent;
  final double ramUsedGb;
  final double ramTotalGb;
  final GpuInfoModel gpu;
  final List<DiskInfoModel> disks;
  final NetworkRateModel network;
  final BatteryInfoModel battery;
  final String hostname;
  final int uptimeSeconds;

  SystemTelemetryModel({
    required this.cpuPercent,
    required this.cpuCoresPercent,
    this.cpuFreqMhz,
    required this.ramPercent,
    required this.ramUsedGb,
    required this.ramTotalGb,
    required this.gpu,
    required this.disks,
    required this.network,
    required this.battery,
    required this.hostname,
    required this.uptimeSeconds,
  });

  factory SystemTelemetryModel.fromJson(Map<String, dynamic> json) {
    return SystemTelemetryModel(
      cpuPercent: (json['cpu_percent'] as num?)?.toDouble() ?? 0.0,
      cpuCoresPercent: ((json['cpu_cores_percent'] as List?) ?? [])
          .map((e) => (e as num).toDouble())
          .toList(),
      cpuFreqMhz: (json['cpu_freq_mhz'] as num?)?.toDouble(),
      ramPercent: (json['ram_percent'] as num?)?.toDouble() ?? 0.0,
      ramUsedGb: (json['ram_used_gb'] as num?)?.toDouble() ?? 0.0,
      ramTotalGb: (json['ram_total_gb'] as num?)?.toDouble() ?? 0.0,
      gpu: json['gpu'] != null
          ? GpuInfoModel.fromJson(json['gpu'])
          : GpuInfoModel(),
      disks: ((json['disks'] as List?) ?? [])
          .map((e) => DiskInfoModel.fromJson(e))
          .toList(),
      network: json['network'] != null
          ? NetworkRateModel.fromJson(json['network'])
          : NetworkRateModel(downloadKbps: 0, uploadKbps: 0, totalDownloadMb: 0, totalUploadMb: 0),
      battery: json['battery'] != null
          ? BatteryInfoModel.fromJson(json['battery'])
          : BatteryInfoModel(),
      hostname: json['hostname'] ?? '',
      uptimeSeconds: json['uptime_seconds'] ?? 0,
    );
  }
}

class AudioDeviceModel {
  final String id;
  final String name;
  final bool isDefault;
  final String state;

  AudioDeviceModel({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.state,
  });

  factory AudioDeviceModel.fromJson(Map<String, dynamic> json) {
    return AudioDeviceModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      isDefault: json['is_default'] ?? false,
      state: json['state'] ?? 'Active',
    );
  }
}

class AudioStatusModel {
  final int masterVolume;
  final bool isMuted;
  final List<AudioDeviceModel> devices;
  final String? activeDeviceName;

  AudioStatusModel({
    required this.masterVolume,
    required this.isMuted,
    required this.devices,
    this.activeDeviceName,
  });

  factory AudioStatusModel.fromJson(Map<String, dynamic> json) {
    return AudioStatusModel(
      masterVolume: json['master_volume'] ?? 0,
      isMuted: json['is_muted'] ?? false,
      devices: ((json['devices'] as List?) ?? [])
          .map((e) => AudioDeviceModel.fromJson(e))
          .toList(),
      activeDeviceName: json['active_device_name'],
    );
  }
}

class MediaStatusModel {
  final bool hasMedia;
  final bool isPlaying;
  final String title;
  final String artist;
  final String album;
  final String sourceApp;
  final int positionMs;
  final int durationMs;
  final bool hasThumbnail;
  final bool canPlayPause;
  final bool canNext;
  final bool canPrevious;
  final bool canSeek;

  MediaStatusModel({
    required this.hasMedia,
    required this.isPlaying,
    required this.title,
    required this.artist,
    required this.album,
    required this.sourceApp,
    required this.positionMs,
    required this.durationMs,
    required this.hasThumbnail,
    required this.canPlayPause,
    required this.canNext,
    required this.canPrevious,
    required this.canSeek,
  });

  factory MediaStatusModel.fromJson(Map<String, dynamic> json) {
    return MediaStatusModel(
      hasMedia: json['has_media'] ?? false,
      isPlaying: json['is_playing'] ?? false,
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      album: json['album'] ?? '',
      sourceApp: json['source_app'] ?? '',
      positionMs: json['position_ms'] ?? 0,
      durationMs: json['duration_ms'] ?? 0,
      hasThumbnail: json['has_thumbnail'] ?? false,
      canPlayPause: json['can_play_pause'] ?? false,
      canNext: json['can_next'] ?? false,
      canPrevious: json['can_previous'] ?? false,
      canSeek: json['can_seek'] ?? false,
    );
  }
}

class DisplayStatusModel {
  final int brightness;
  final int displayCount;

  DisplayStatusModel({
    required this.brightness,
    required this.displayCount,
  });

  factory DisplayStatusModel.fromJson(Map<String, dynamic> json) {
    return DisplayStatusModel(
      brightness: json['brightness'] ?? 100,
      displayCount: json['display_count'] ?? 1,
    );
  }
}

class UnifiedTelemetryFrameModel {
  final int timestampMs;
  final String pcName;
  final SystemTelemetryModel system;
  final AudioStatusModel audio;
  final MediaStatusModel media;
  final DisplayStatusModel display;

  UnifiedTelemetryFrameModel({
    required this.timestampMs,
    required this.pcName,
    required this.system,
    required this.audio,
    required this.media,
    required this.display,
  });

  factory UnifiedTelemetryFrameModel.fromJson(Map<String, dynamic> json) {
    return UnifiedTelemetryFrameModel(
      timestampMs: json['timestamp_ms'] ?? 0,
      pcName: json['pc_name'] ?? 'My PC',
      system: SystemTelemetryModel.fromJson(json['system'] ?? {}),
      audio: AudioStatusModel.fromJson(json['audio'] ?? {}),
      media: MediaStatusModel.fromJson(json['media'] ?? {}),
      display: DisplayStatusModel.fromJson(json['display'] ?? {}),
    );
  }
}

class AppItemModel {
  final String id;
  final String name;
  final String command;
  final String icon;
  final String description;
  final bool isRunning;

  AppItemModel({
    required this.id,
    required this.name,
    required this.command,
    required this.icon,
    required this.description,
    required this.isRunning,
  });

  factory AppItemModel.fromJson(Map<String, dynamic> json) {
    return AppItemModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      command: json['command'] ?? '',
      icon: json['icon'] ?? '',
      description: json['description'] ?? '',
      isRunning: json['is_running'] ?? false,
    );
  }
}

class RunningTaskModel {
  final int pid;
  final String name;
  final double cpuPercent;
  final double memoryMb;

  RunningTaskModel({
    required this.pid,
    required this.name,
    required this.cpuPercent,
    required this.memoryMb,
  });

  factory RunningTaskModel.fromJson(Map<String, dynamic> json) {
    return RunningTaskModel(
      pid: json['pid'] ?? 0,
      name: json['name'] ?? '',
      cpuPercent: (json['cpu_percent'] as num?)?.toDouble() ?? 0.0,
      memoryMb: (json['memory_mb'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
