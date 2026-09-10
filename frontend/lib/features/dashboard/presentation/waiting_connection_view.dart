import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pc_control_center/core/network/api_client.dart';
import 'package:pc_control_center/core/network/discovery_service.dart';
import 'package:pc_control_center/core/network/websocket_client.dart';
import 'package:pc_control_center/core/providers/settings_provider.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';

class WaitingConnectionView extends ConsumerStatefulWidget {
  const WaitingConnectionView({super.key});

  @override
  ConsumerState<WaitingConnectionView> createState() => _WaitingConnectionViewState();
}

class _WaitingConnectionViewState extends ConsumerState<WaitingConnectionView> with SingleTickerProviderStateMixin {
  late TextEditingController _hostCtrl;
  late TextEditingController _keyCtrl;
  bool _obscureKey = true;
  bool _isTesting = false;
  ConnectionTestResult? _testResult;

  bool _isScanning = false;
  final List<DiscoveredHost> _discoveredHosts = [];
  StreamSubscription<DiscoveredHost>? _scanSub;

  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  void _ensurePulseAnimation() {
    if (_pulseController == null) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat(reverse: true);

      _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
        CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    final initialHost = (s.host == "127.0.0.1" || s.host.isEmpty) ? "192.168.29.249" : s.host;
    _hostCtrl = TextEditingController(text: initialHost);
    _keyCtrl = TextEditingController(text: s.apiKey);
    _ensurePulseAnimation();
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    _scanSub?.cancel();
    _hostCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  void _startSubnetScan() {
    _scanSub?.cancel();
    setState(() {
      _isScanning = true;
      _discoveredHosts.clear();
    });

    final currentHost = _hostCtrl.text.trim();
    _scanSub = discoveryService.scanSubnetStream(baseSubnet: currentHost).listen(
      (host) {
        setState(() {
          if (!_discoveredHosts.any((h) => h.ip == host.ip)) {
            _discoveredHosts.add(host);
          }
        });
      },
      onDone: () {
        if (mounted) {
          setState(() => _isScanning = false);
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() => _isScanning = false);
        }
      },
    );

    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _isScanning) {
        _scanSub?.cancel();
        setState(() => _isScanning = false);
      }
    });
  }

  Future<void> _runConnectionTest() async {
    final host = _hostCtrl.text.trim();
    final port = ref.read(settingsProvider).port;
    final key = _keyCtrl.text.trim();

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final result = await apiClient.testConnection(
      host: host,
      port: port,
      apiKey: key,
    );

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResult = result;
      });
    }
  }

  void _applyAndConnect() {
    final host = _hostCtrl.text.trim();
    final key = _keyCtrl.text.trim();
    final notifier = ref.read(settingsProvider.notifier);

    notifier.updateHost(host);
    notifier.updateApiKey(key);

    telemetryWsClient.disconnect();
    telemetryWsClient.connect();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connecting to $host...'),
        backgroundColor: AppColors.buttonSurface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensurePulseAnimation();
    final settings = ref.watch(settingsProvider);
    final wsStatus = telemetryWsClient.status;
    final lastError = telemetryWsClient.lastError;

    return Center(
      child: SingleChildScrollView(
        // Generous bottom padding (80dp) so content never touches the screen edge or conflicts with navigation
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 80),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hero Brand Header
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 20),
                child: Column(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.panelBackground,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppColors.accentLive.withOpacity(0.35),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentLive.withOpacity(0.18),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.desktop_windows_rounded,
                          color: AppColors.accentLive,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'PC CONTROL CENTER',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Remote PC Cockpit & Dashboard',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.8,
                        color: AppColors.metricNormal,
                      ),
                    ),
                  ],
                ),
              ),

              // 1. Unified 4-State ConnectionStatusCard
              _buildConnectionStatusCard(settings, wsStatus, lastError),
              const SizedBox(height: 16),

              // 2. Primary Action: Auto-Discovery & Subnet Scanner Card
              _buildAutoDiscoverCard(),
              const SizedBox(height: 16),

              // 3. Manual Connection & Quick Targets
              _buildManualDetailsCard(settings),
              const SizedBox(height: 16),

              // 4. Troubleshooting Guide
              _buildTroubleshootingCard(),
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. Single 4-State ConnectionStatusCard ---
  Widget _buildConnectionStatusCard(SettingsState settings, ConnectionStatus wsStatus, String? lastError) {
    final isFirstRun = settings.host.isEmpty && _hostCtrl.text.isEmpty;
    final isConnecting = _isTesting || wsStatus == ConnectionStatus.connecting;
    final isConnected = wsStatus == ConnectionStatus.connected;
    final hasFailed = (wsStatus == ConnectionStatus.error || lastError != null || (_testResult != null && !_testResult!.isSuccess)) && !isConnecting;

    Color stateColor;
    IconData stateIcon;
    String headline;
    String detail;
    bool showPulse = false;

    if (isConnecting) {
      stateColor = AppColors.warningAmber;
      stateIcon = Icons.wifi_tethering_rounded;
      headline = 'Connecting to PC Host...';
      detail = 'Target: http://${_hostCtrl.text.trim()}:${settings.port}';
      showPulse = true;
    } else if (hasFailed) {
      stateColor = AppColors.criticalRed;
      stateIcon = Icons.error_outline_rounded;
      headline = 'Connection Unreachable';
      detail = lastError ?? _testResult?.message ?? 'Ensure PC is on same Wi-Fi & Firewall allows port ${settings.port}.';
    } else if (isConnected) {
      stateColor = AppColors.accentLive;
      stateIcon = Icons.check_circle_rounded;
      headline = 'Connected to PC Host';
      detail = 'Live telemetry streaming from http://${settings.host}:${settings.port}';
    } else if (isFirstRun) {
      stateColor = AppColors.metricNormal;
      stateIcon = Icons.wifi_find_rounded;
      headline = 'Welcome to PC Control Center';
      detail = 'Auto-scan your Wi-Fi network below or enter your PC IP address to connect.';
    } else {
      // Idle / Disconnected with saved host
      stateColor = AppColors.metricNormal;
      stateIcon = Icons.desktop_windows_outlined;
      headline = 'Ready to Connect';
      detail = 'Target: http://${_hostCtrl.text.trim()}:${settings.port}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panelBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFailed ? AppColors.criticalRed.withOpacity(0.5) : AppColors.panelBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // State Icon with optional breathing pulse
              (showPulse && _pulseAnimation != null)
                  ? ScaleTransition(
                      scale: _pulseAnimation!,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: stateColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(stateIcon, color: stateColor, size: 22),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: stateColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(stateIcon, color: stateColor, size: 22),
                    ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: hasFailed ? AppColors.criticalRed : Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.metricNormal,
                        height: 1.3,
                        fontFamily: detail.contains('http') ? 'monospace' : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasFailed) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: AppColors.panelBorder.withOpacity(0.6)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.warningAmber,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry Target', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  // Re-triggers the exact typed host/target, not resetting
                  onPressed: _applyAndConnect,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --- 2. Auto-Discovery & Subnet Scanner Card (Primary Action) ---
  Widget _buildAutoDiscoverCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panelBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.panelBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar_rounded, color: AppColors.accentLive, size: 18),
              const SizedBox(width: 8),
              const Text(
                'AUTO-DISCOVERY (RECOMMENDED)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.metricNormal,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              if (_isScanning)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(color: AppColors.accentLive, strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Locate your PC Host automatically across the Wi-Fi network without typing an IP.',
            style: TextStyle(fontSize: 12, color: AppColors.metricNormal.withOpacity(0.9)),
          ),
          const SizedBox(height: 14),

          // Primary Solid Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonSurface,
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppColors.buttonBorder, width: 1.2),
                elevation: 2,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(
                _isScanning ? Icons.sync_rounded : Icons.search_rounded,
                size: 18,
                color: AppColors.accentLive,
              ),
              label: Text(
                _isScanning ? 'Scanning Wi-Fi Subnet...' : 'Auto-Scan for PC',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.3),
              ),
              onPressed: _isScanning ? null : _startSubnetScan,
            ),
          ),

          // Discovered PC Hosts
          if (_discoveredHosts.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Discovered PC Hosts:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentLive),
            ),
            const SizedBox(height: 8),
            ..._discoveredHosts.map((h) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.panelSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.accentLive.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.desktop_windows_rounded, color: AppColors.accentLive, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h.hostname,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            Text(
                              '${h.ip}:${h.port} (${h.latencyMs}ms)',
                              style: const TextStyle(fontSize: 11, color: AppColors.metricNormal, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentLive,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          _hostCtrl.text = h.ip;
                          _applyAndConnect();
                        },
                        child: const Text('Connect', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  // --- 3. Manual Connection & Quick Targets ---
  Widget _buildManualDetailsCard(SettingsState settings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panelBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.panelBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: AppColors.metricNormal, size: 18),
              SizedBox(width: 8),
              Text(
                'MANUAL CONNECTION DETAILS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.metricNormal,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Labeled Quick Targets Segmented Row
          const Text(
            'Quick Targets:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.metricNormal),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickTargetChip(
                  label: '192.168.29.249 (Wi-Fi)',
                  ip: '192.168.29.249',
                  icon: Icons.wifi_rounded,
                ),
                const SizedBox(width: 8),
                _buildQuickTargetChip(
                  label: '10.0.2.2 (Emulator)',
                  ip: '10.0.2.2',
                  icon: Icons.android_rounded,
                ),
                const SizedBox(width: 8),
                _buildQuickTargetChip(
                  label: '127.0.0.1 (Local)',
                  ip: '127.0.0.1',
                  icon: Icons.home_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Host IP Input
          TextField(
            controller: _hostCtrl,
            style: const TextStyle(fontSize: 13, color: Colors.white, fontFamily: 'monospace'),
            decoration: InputDecoration(
              labelText: 'PC Host IP Address',
              labelStyle: const TextStyle(fontSize: 12, color: AppColors.metricNormal),
              hintText: '192.168.29.249',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: AppColors.panelSurface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.panelBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.accentLive),
              ),
              prefixIcon: const Icon(Icons.computer_rounded, size: 18, color: AppColors.metricNormal),
            ),
          ),
          const SizedBox(height: 12),

          // API Key Input
          TextField(
            controller: _keyCtrl,
            obscureText: _obscureKey,
            style: const TextStyle(fontSize: 13, color: Colors.white, fontFamily: 'monospace'),
            decoration: InputDecoration(
              labelText: 'Host API Key (from PC tray)',
              labelStyle: const TextStyle(fontSize: 12, color: AppColors.metricNormal),
              hintText: 'e.g. 6836b828f758dfa0',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: AppColors.panelSurface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.panelBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.accentLive),
              ),
              prefixIcon: const Icon(Icons.key_rounded, size: 18, color: AppColors.metricNormal),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureKey ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 18,
                  color: AppColors.metricNormal,
                ),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Form Action Buttons (Clean contrast, no overlap)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.buttonBorder, width: 1.2),
                    backgroundColor: AppColors.buttonSurface,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isTesting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.network_check_rounded, size: 16, color: AppColors.metricNormal),
                  label: const Text('Test Connection', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  onPressed: _isTesting ? null : _runConnectionTest,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentLive,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Save & Connect', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  onPressed: _applyAndConnect,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTargetChip({
    required String label,
    required String ip,
    required IconData icon,
  }) {
    final isSelected = _hostCtrl.text.trim() == ip;
    return InkWell(
      onTap: () => setState(() => _hostCtrl.text = ip),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentLive.withOpacity(0.15) : AppColors.panelSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accentLive : AppColors.panelBorder,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? AppColors.accentLive : AppColors.metricNormal),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.accentLive : AppColors.metricNormal,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 4. Troubleshooting Guide ---
  Widget _buildTroubleshootingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panelBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.panelBorder, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.help_outline_rounded, color: AppColors.metricNormal, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connection Tips',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Phone & PC must share the same local Wi-Fi router.\n'
                  '• PC Tray: Right-click > "Copy PC IP Address" & "Copy API Key".\n'
                  '• Windows Firewall: Allow Python/uvicorn on Private Networks.',
                  style: TextStyle(fontSize: 11, color: AppColors.metricNormal, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
