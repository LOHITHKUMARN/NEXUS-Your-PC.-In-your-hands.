import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pc_control_center/core/network/api_client.dart';
import 'package:pc_control_center/core/network/discovery_service.dart';
import 'package:pc_control_center/core/providers/settings_provider.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';
import 'package:pc_control_center/shared/widgets/glass_card.dart';
import 'package:pc_control_center/shared/widgets/pc_action_button.dart';
import 'package:pc_control_center/shared/widgets/pc_icon_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pc_control_center/core/network/wol_service.dart';
import 'package:pc_control_center/features/settings/presentation/diagnostics_screen.dart';
import 'package:pc_control_center/features/settings/presentation/audit_log_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _hostCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _apiKeyCtrl;
  bool _obscureKey = true;
  bool _isTesting = false;
  ConnectionTestResult? _testResult;
  bool _isScanning = false;
  final List<DiscoveredHost> _discoveredHosts = [];
  StreamSubscription<DiscoveredHost>? _scanSub;
  String _macAddress = '';

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _hostCtrl = TextEditingController(text: s.host);
    _portCtrl = TextEditingController(text: s.port.toString());
    _apiKeyCtrl = TextEditingController(text: s.apiKey);

    SharedPreferences.getInstance().then((sp) {
      final savedMac = sp.getString('saved_mac_address') ?? '';
      if (mounted && savedMac.isNotEmpty) {
        setState(() => _macAddress = savedMac);
      }
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  void _startSubnetScan() {
    _scanSub?.cancel();
    setState(() {
      _isScanning = true;
      _discoveredHosts.clear();
    });

    _scanSub = discoveryService.scanSubnetStream(baseSubnet: _hostCtrl.text.trim()).listen(
      (host) {
        setState(() {
          if (!_discoveredHosts.any((h) => h.ip == host.ip)) {
            _discoveredHosts.add(host);
          }
        });
      },
      onDone: () {
        if (mounted) setState(() => _isScanning = false);
      },
      onError: (_) {
        if (mounted) setState(() => _isScanning = false);
      },
    );

    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _isScanning) {
        _scanSub?.cancel();
        setState(() => _isScanning = false);
      }
    });
  }

  void _showFastPairDialog() {
    final pairCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_2_rounded, color: AppColors.cyan, size: 22),
            SizedBox(width: 8),
            Text('Fast-Pair with Code / URI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste the Fast-Pairing URI or code from your PC server system tray or console banner.',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pairCtrl,
              style: const TextStyle(fontSize: 12, color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'pccontrol://192.168.29.249:8765?key=...',
                hintStyle: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final parsed = parsePairingUri(pairCtrl.text.trim());
              if (parsed != null) {
                setState(() {
                  _hostCtrl.text = parsed.host;
                  _portCtrl.text = parsed.port.toString();
                  _apiKeyCtrl.text = parsed.apiKey;
                });
                final settingsNotifier = ref.read(settingsProvider.notifier);
                settingsNotifier.updateHost(parsed.host);
                settingsNotifier.updatePort(parsed.port);
                settingsNotifier.updateApiKey(parsed.apiKey);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Paired with ${parsed.name ?? parsed.host} successfully!')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid pairing URI. Must start with pcc://')),
                );
              }
            },
            child: const Text('Pair Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showWolDialog() {
    final macCtrl = TextEditingController(text: _macAddress);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.power_settings_new_rounded, color: AppColors.cyan, size: 22),
            SizedBox(width: 8),
            Text('Wake-on-LAN (Wake PC)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Broadcasts a magic packet to turn on your PC from sleep or powered-off state.',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: macCtrl,
              style: const TextStyle(fontSize: 13, color: Colors.white, fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'Target PC MAC Address',
                hintText: 'e.g. CC:5E:F8:53:56:3F',
                labelStyle: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Target Subnet: ${_hostCtrl.text.trim()}',
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: const Text('Send Magic Packet', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              final mac = macCtrl.text.trim();
              if (mac.isEmpty) return;

              final sp = await SharedPreferences.getInstance();
              await sp.setString('saved_mac_address', mac);
              if (mounted) setState(() => _macAddress = mac);

              final success = await WakeOnLanService.sendWakeOnLan(
                macAddress: mac,
                hostIp: _hostCtrl.text.trim(),
              );

              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Wake-on-LAN Magic Packet broadcasted!'
                          : 'Failed to broadcast WoL packet. Check MAC format.',
                    ),
                    backgroundColor: success ? Colors.green[800] : Colors.red[800],
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _rotateApiKey() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rotate API Key?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will invalidate the existing key on your PC and generate a new random security key.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.amber, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rotate Key'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await apiClient.rotateApiKey();
      if (res != null && res['api_key'] != null) {
        final newKey = res['api_key'] as String;
        setState(() {
          _apiKeyCtrl.text = newKey;
        });
        ref.read(settingsProvider.notifier).updateApiKey(newKey);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('API Key rotated & updated successfully!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to rotate API Key. Ensure PC is connected.')),
          );
        }
      }
    }
  }

  Future<void> _runConnectionTest() async {
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 8765;
    final apiKey = _apiKeyCtrl.text.trim();

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final result = await apiClient.testConnection(
      host: host,
      port: port,
      apiKey: apiKey,
    );

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResult = result;
      });
    }
  }

  Widget _buildCategoryHeader(IconData icon, String title) {
    return Row(
      children: [
        PcIconBadge(icon: icon, size: 32, iconSize: 16),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 88),
      children: [
        // 1. Connection Config Card
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryHeader(Icons.lan_rounded, 'PC Connection Settings'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.buttonSurface,
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.buttonBorder),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: Icon(
                        _isScanning ? Icons.sync_rounded : Icons.radar_rounded,
                        size: 15,
                        color: AppColors.metricNormal,
                      ),
                      label: Text(
                        _isScanning ? 'Scanning...' : 'Auto-Scan PC',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: _isScanning ? null : _startSubnetScan,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.buttonSurface,
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.buttonBorder),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 15, color: AppColors.metricNormal),
                      label: const Text(
                        'Fast-Pair QR',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: _showFastPairDialog,
                    ),
                  ),
                ],
              ),
              if (_discoveredHosts.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: _discoveredHosts.map((h) => ActionChip(
                    avatar: const Icon(Icons.desktop_windows_rounded, size: 14, color: AppColors.emerald),
                    label: Text('${h.hostname} (${h.ip})', style: const TextStyle(fontSize: 11)),
                    backgroundColor: AppColors.emerald.withOpacity(0.15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onPressed: () {
                      setState(() {
                        _hostCtrl.text = h.ip;
                        _portCtrl.text = h.port.toString();
                      });
                    },
                  )).toList(),
                ),
                const SizedBox(height: 6),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _hostCtrl,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'PC Host IP',
                        labelStyle: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                        hintText: '192.168.29.249',
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _portCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Port',
                        labelStyle: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                        hintText: '8765',
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  ActionChip(
                    label: const Text('192.168.29.249 (Wi-Fi)', style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.white.withOpacity(0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    onPressed: () => setState(() => _hostCtrl.text = "192.168.29.249"),
                  ),
                  ActionChip(
                    label: const Text('10.0.2.2 (Emulator)', style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.white.withOpacity(0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    onPressed: () => setState(() => _hostCtrl.text = "10.0.2.2"),
                  ),
                  ActionChip(
                    label: const Text('127.0.0.1 (Local)', style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.white.withOpacity(0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    onPressed: () => setState(() => _hostCtrl.text = "127.0.0.1"),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _apiKeyCtrl,
                obscureText: _obscureKey,
                style: const TextStyle(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'API Key',
                  labelStyle: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                  hintText: 'Pre-shared API Key from PC Tray icon',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureKey ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.amber,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 13),
                    label: const Text('Rotate Key on PC', style: TextStyle(fontSize: 11)),
                    onPressed: _rotateApiKey,
                  ),
                ],
              ),
              if (_testResult != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _testResult!.isSuccess
                        ? AppColors.emerald.withOpacity(0.12)
                        : (_testResult!.status == ConnectionTestStatus.invalidApiKey
                            ? AppColors.amber.withOpacity(0.12)
                            : AppColors.red.withOpacity(0.12)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _testResult!.isSuccess
                          ? AppColors.emerald.withOpacity(0.4)
                          : (_testResult!.status == ConnectionTestStatus.invalidApiKey
                              ? AppColors.amber.withOpacity(0.4)
                              : AppColors.red.withOpacity(0.4)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testResult!.isSuccess
                            ? Icons.check_circle_rounded
                            : (_testResult!.status == ConnectionTestStatus.invalidApiKey
                                ? Icons.key_off_rounded
                                : Icons.cancel_rounded),
                        color: _testResult!.isSuccess
                            ? AppColors.emerald
                            : (_testResult!.status == ConnectionTestStatus.invalidApiKey
                                ? AppColors.amber
                                : AppColors.red),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _testResult!.message,
                          style: const TextStyle(fontSize: 11, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: PcActionButton(
                      label: 'Test Connection',
                      icon: Icons.network_check_rounded,
                      isOutlined: true,
                      isLoading: _isTesting,
                      onPressed: _isTesting ? null : _runConnectionTest,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PcActionButton(
                      label: 'Save Settings',
                      icon: Icons.save_rounded,
                      onPressed: () {
                        final host = _hostCtrl.text.trim();
                        final port = int.tryParse(_portCtrl.text.trim()) ?? 8765;
                        final apiKey = _apiKeyCtrl.text.trim();

                        settingsNotifier.updateHost(host);
                        settingsNotifier.updatePort(port);
                        settingsNotifier.updateApiKey(apiKey);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Settings saved & reconnecting!')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Health & Self-Diagnostics Card
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryHeader(Icons.health_and_safety_rounded, 'Connection Diagnostics'),
              const SizedBox(height: 8),
              Text(
                'Run automated tests on LAN reachability, API key validation, telemetry streaming, and zero-displacement input sockets.',
                style: TextStyle(fontSize: 11, color: AppColors.metricNormal, height: 1.3),
              ),
              const SizedBox(height: 12),
              PcActionButton(
                label: 'Run "Test My Setup" Diagnostics',
                icon: Icons.speed_rounded,
                isFullWidth: true,
                isOutlined: true,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Wake-on-LAN (Magic Packet) Card
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryHeader(Icons.power_settings_new_rounded, 'Wake-on-LAN (WoL)'),
              const SizedBox(height: 8),
              Text(
                'Turn on your sleeping or powered-off PC remotely over local network via UDP magic packet.',
                style: TextStyle(fontSize: 11, color: AppColors.metricNormal, height: 1.3),
              ),
              if (_macAddress.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Target MAC: $_macAddress',
                  style: const TextStyle(fontSize: 11, color: AppColors.metricNormal, fontFamily: 'monospace'),
                ),
              ],
              const SizedBox(height: 12),
              PcActionButton(
                label: 'Wake PC (Send Magic Packet)',
                icon: Icons.bolt_rounded,
                isFullWidth: true,
                isOutlined: true,
                onPressed: _showWolDialog,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 4. PC Security & Audit Log Card
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryHeader(Icons.security_rounded, 'PC Security & Activity Log'),
              const SizedBox(height: 8),
              Text(
                'Inspect the rolling 100-event audit log of device connections, key rotations, failed auth attempts, and power actions recorded on your PC.',
                style: TextStyle(fontSize: 11, color: AppColors.metricNormal, height: 1.3),
              ),
              const SizedBox(height: 12),
              PcActionButton(
                label: 'View PC Activity Log',
                icon: Icons.list_alt_rounded,
                isFullWidth: true,
                isOutlined: true,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuditLogScreen()),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 5. Theme Customization Card
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryHeader(Icons.palette_outlined, 'Theme & Aesthetics'),
              const SizedBox(height: 12),
              _buildThemeOption(
                title: 'Cyber Dark (Default)',
                subtitle: 'Deep Slate Glass with Cyan & Violet Neon Accents',
                mode: AppThemeMode.cyberDark,
                current: settings.themeMode,
                color: AppColors.cyan,
                onSelected: () => settingsNotifier.updateTheme(AppThemeMode.cyberDark),
              ),
              const SizedBox(height: 8),
              _buildThemeOption(
                title: 'Midnight AMOLED Black',
                subtitle: 'Pure Black background for OLED displays with maximum battery savings',
                mode: AppThemeMode.amoledBlack,
                current: settings.themeMode,
                color: AppColors.violet,
                onSelected: () => settingsNotifier.updateTheme(AppThemeMode.amoledBlack),
              ),
              const SizedBox(height: 8),
              _buildThemeOption(
                title: 'Midnight Blue Glass',
                subtitle: 'Deep navy glassmorphism with emerald glow accents',
                mode: AppThemeMode.midnightBlue,
                current: settings.themeMode,
                color: AppColors.emerald,
                onSelected: () => settingsNotifier.updateTheme(AppThemeMode.midnightBlue),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 6. Network & Firewall Help Tip
        GlassCard(
          padding: const EdgeInsets.all(14),
          borderColor: AppColors.panelBorder,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.metricNormal, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LAN & Firewall Notice',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ensure your PC network profile is set to "Private" in Windows Settings and Windows Firewall allows inbound connections on Port 8765.',
                      style: TextStyle(fontSize: 11, color: AppColors.metricNormal, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 7. About App & Branding Card
        GlassCard(
          padding: const EdgeInsets.all(16),
          borderColor: AppColors.panelBorder,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.panelBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.accentLive.withOpacity(0.35),
                    width: 1.2,
                  ),
                ),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.desktop_windows_rounded,
                    color: AppColors.accentLive,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PC Control Center',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Version 1.0.0 • Modern PC Cockpit Remote',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.metricNormal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption({
    required String title,
    required String subtitle,
    required AppThemeMode mode,
    required AppThemeMode current,
    required Color color,
    required VoidCallback onSelected,
  }) {
    final isSelected = mode == current;
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.5) : Colors.white.withOpacity(0.1),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : Colors.transparent,
                border: Border.all(color: color, width: 2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
