import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pc_control_center/core/models/telemetry_model.dart';
import 'package:pc_control_center/core/network/api_client.dart';
import 'package:pc_control_center/core/providers/telemetry_provider.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';
import 'package:pc_control_center/shared/widgets/custom_slider.dart';

class MediaScreen extends ConsumerWidget {
  const MediaScreen({super.key});

  String _formatDuration(int ms) {
    if (ms <= 0) return '0:00';
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetryAsync = ref.watch(telemetryStreamProvider);
    final mediaCtrl = ref.read(mediaControllerProvider);
    final audioCtrl = ref.read(audioControllerProvider);

    final frame = telemetryAsync.value;
    final media = frame?.media;
    final audio = frame?.audio;

    final hasActiveTrack = media != null && media.hasMedia && media.title.isNotEmpty;

    final double progressPct = (media != null && media.durationMs > 0)
        ? (media.positionMs / media.durationMs).clamp(0.0, 1.0)
        : 0.0;

    return ListView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 88),
      children: [
        // 1. Album Artwork / Standby Disc Frame
        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: const Color(0xFF11151D),
              border: Border.all(
                color: hasActiveTrack
                    ? AppColors.accentLive.withOpacity(0.4)
                    : AppColors.panelBorder,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: hasActiveTrack
                      ? AppColors.accentLive.withOpacity(0.2)
                      : Colors.black.withOpacity(0.4),
                  blurRadius: 24,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: (hasActiveTrack && media.hasThumbnail)
                  ? Image.network(
                      apiClient.getMediaThumbnailUrl(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildArtworkFallback(hasActiveTrack),
                    )
                  : _buildArtworkFallback(hasActiveTrack),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 2. Track Title & Artist Readout
        Column(
          children: [
            Text(
              hasActiveTrack ? media.title : 'Media Standby',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              hasActiveTrack
                  ? (media.artist.isNotEmpty ? media.artist : media.sourceApp)
                  : 'No track streaming • Tap Play to resume PC media',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: hasActiveTrack ? AppColors.accentLive : AppColors.metricNormal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (hasActiveTrack && media.album.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                media.album,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.45),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),

        // 3. Track Seek Bar (when duration available)
        if (hasActiveTrack && media.durationMs > 0) ...[
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.accentLive,
              inactiveTrackColor: const Color(0xFF222A38),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              trackHeight: 4,
            ),
            child: Slider(
              value: progressPct,
              onChanged: (v) {
                final targetMs = (v * media.durationMs).round();
                mediaCtrl.seek(targetMs);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(media.positionMs),
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6), fontFamily: 'monospace'),
                ),
                Text(
                  _formatDuration(media.durationMs),
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6), fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // 4. Universal Playback Transport Buttons (ALWAYS accessible!)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Previous
              IconButton(
                iconSize: 30,
                icon: const Icon(Icons.skip_previous_rounded),
                color: Colors.white70,
                tooltip: 'Previous Track',
                onPressed: () => mediaCtrl.previous(),
              ),

              // Play / Pause Toggle (Hero Button)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => mediaCtrl.toggle(),
                  borderRadius: BorderRadius.circular(36),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentLive,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentLive.withOpacity(0.4),
                          blurRadius: 18,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      (media?.isPlaying ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 38,
                      color: const Color(0xFF0B0F17),
                    ),
                  ),
                ),
              ),

              // Next
              IconButton(
                iconSize: 30,
                icon: const Icon(Icons.skip_next_rounded),
                color: Colors.white70,
                tooltip: 'Next Track',
                onPressed: () => mediaCtrl.next(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 5. Quick Launch Media Apps (especially helpful on standby)
        if (!hasActiveTrack) ...[
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'QUICK LAUNCH ON PC',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.metricNormal,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildQuickChip(
                  icon: Icons.music_note_rounded,
                  label: 'Spotify',
                  onTap: () => apiClient.openUrl('https://open.spotify.com'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickChip(
                  icon: Icons.play_circle_outline_rounded,
                  label: 'YouTube',
                  onTap: () => apiClient.openUrl('https://youtube.com'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickChip(
                  icon: Icons.movie_outlined,
                  label: 'Netflix',
                  onTap: () => apiClient.openUrl('https://netflix.com'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // 6. Master Volume Slider (Always Available)
        if (audio != null)
          CustomSliderCard(
            title: 'Master Volume',
            value: audio.masterVolume,
            icon: Icons.volume_up_rounded,
            accentColor: AppColors.accentLive,
            onChanged: (v) => audioCtrl.setVolume(v),
            onNudgeDown: () => audioCtrl.stepVolume(-5),
            onNudgeUp: () => audioCtrl.stepVolume(5),
          ),
      ],
    );
  }

  Widget _buildArtworkFallback(bool hasActiveTrack) {
    return Container(
      color: const Color(0xFF141923),
      child: Center(
        child: Icon(
          hasActiveTrack ? Icons.music_note_rounded : Icons.radio_rounded,
          size: 64,
          color: hasActiveTrack ? AppColors.accentLive : AppColors.metricNormal.withOpacity(0.6),
        ),
      ),
    );
  }

  Widget _buildQuickChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.buttonSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.buttonBorder, width: 1.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.accentLive),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
