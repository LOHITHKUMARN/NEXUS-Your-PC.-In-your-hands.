import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pc_control_center/core/network/websocket_client.dart';
import 'package:pc_control_center/core/providers/telemetry_provider.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';

class ConnectionBadge extends ConsumerStatefulWidget {
  const ConnectionBadge({super.key});

  @override
  ConsumerState<ConnectionBadge> createState() => _ConnectionBadgeState();
}

class _ConnectionBadgeState extends ConsumerState<ConnectionBadge> with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  void _ensurePulseAnimation() {
    if (_pulseController == null) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      )..repeat(reverse: true);

      _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
        CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _ensurePulseAnimation();
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _ensurePulseAnimation();
    final statusAsync = ref.watch(connectionStatusProvider);
    final latencyAsync = ref.watch(latencyStreamProvider);
    final isStaleAsync = ref.watch(isStaleStreamProvider);

    final status = statusAsync.value ?? telemetryWsClient.status;
    final latency = latencyAsync.value;
    final isStale = isStaleAsync.value ?? telemetryWsClient.isStale;

    Color color;
    String text;
    bool shouldPulse = false;

    switch (status) {
      case ConnectionStatus.connected:
        if (isStale) {
          color = AppColors.warningAmber;
          final s = telemetryWsClient.secondsSinceLastFrame;
          text = s != null ? 'Stale (${s}s)' : 'Stale';
        } else {
          color = AppColors.accentLive;
          text = latency != null ? '${latency}ms' : 'Live';
          shouldPulse = true;
        }
        break;
      case ConnectionStatus.connecting:
        color = AppColors.warningAmber;
        text = 'Reconnecting...';
        break;
      case ConnectionStatus.error:
        color = AppColors.criticalRed;
        text = 'Offline';
        break;
      case ConnectionStatus.disconnected:
        color = AppColors.metricNormal;
        text = 'Disconnected';
        break;
    }

    return InkWell(
      onTap: () {
        if (status != ConnectionStatus.connected) {
          telemetryWsClient.connect();
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            (shouldPulse && _pulseAnimation != null)
                ? ScaleTransition(
                    scale: _pulseAnimation!,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                fontFamily: 'monospace',
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
