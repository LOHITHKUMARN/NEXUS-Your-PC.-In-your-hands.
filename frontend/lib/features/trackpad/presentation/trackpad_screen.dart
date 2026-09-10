import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pc_control_center/core/network/input_websocket_client.dart';
import 'package:pc_control_center/core/network/websocket_client.dart' show ConnectionStatus;
import 'package:pc_control_center/core/providers/input_provider.dart';
import 'package:pc_control_center/core/providers/settings_provider.dart';
import 'package:pc_control_center/core/providers/telemetry_provider.dart';
import 'package:pc_control_center/core/theme/app_theme.dart';

class TrackpadScreen extends ConsumerStatefulWidget {
  const TrackpadScreen({super.key});

  @override
  ConsumerState<TrackpadScreen> createState() => _TrackpadScreenState();
}

class _TrackpadScreenState extends ConsumerState<TrackpadScreen> with WidgetsBindingObserver {
  // Pointers tracker for multi-touch gestures
  final Map<int, Offset> _pointers = {};
  final Map<int, Offset> _pointerStartPos = {};
  final Map<int, DateTime> _pointerStartTime = {};

  // Double-tap-hold drag state
  DateTime? _lastTapEndTime;
  Offset? _lastTapEndPos;
  Timer? _dragEngageTimer;
  bool _isDragging = false;

  // Visual cursor touch indicator
  Offset? _touchIndicatorPos;

  // Scroll rail dynamic thumb position (normalized 0.0 - 1.0)
  double _scrollThumbY = 0.5;

  // Virtual keyboard controller & focus node
  final TextEditingController _keyboardController = TextEditingController();
  final FocusNode _keyboardFocusNode = FocusNode();
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final settings = ref.read(settingsProvider);
    inputWsClient.configure(
      host: settings.host,
      port: settings.port,
      apiKey: settings.apiKey,
    );
    inputWsClient.connect();

    _keyboardFocusNode.addListener(() {
      setState(() {
        _isKeyboardVisible = _keyboardFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dragEngageTimer?.cancel();
    _keyboardController.dispose();
    _keyboardFocusNode.dispose();
    inputWsClient.disconnect();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      // Auto-lock on background/screen lock:
      // Drop input connection immediately so pocket-dials don't move PC mouse or hold buttons.
      _dragEngageTimer?.cancel();
      if (_isDragging) {
        setState(() {
          _isDragging = false;
        });
      }
      _pointers.clear();
      _touchIndicatorPos = null;
      inputWsClient.disconnect();
    } else if (state == AppLifecycleState.resumed) {
      // Fresh reconnect when returning to foreground
      inputWsClient.connect();
    }
  }

  void _onPointerDown(PointerDownEvent event, TrackpadPreferences prefs) {
    _pointers[event.pointer] = event.localPosition;
    _pointerStartPos[event.pointer] = event.localPosition;
    _pointerStartTime[event.pointer] = DateTime.now();

    setState(() {
      _touchIndicatorPos = event.localPosition;
    });

    // Double-tap-hold drag detection:
    // "two taps within 300ms, second tap held >= 150ms before drag begins engages drag mode"
    if (_pointers.length == 1) {
      final now = DateTime.now();
      final tapEndTime = _lastTapEndTime;
      final tapEndPos = _lastTapEndPos;
      if (tapEndTime != null && tapEndPos != null) {
        final timeDiff = now.difference(tapEndTime).inMilliseconds;
        final distDiff = (event.localPosition - tapEndPos).distance;

        if (timeDiff <= 300 && distDiff <= 35) {
          // Second tap detected within 300ms — start hold timer of 150ms
          _dragEngageTimer?.cancel();
          _dragEngageTimer = Timer(const Duration(milliseconds: 150), () {
            if (_pointers.containsKey(event.pointer)) {
              setState(() {
                _isDragging = true;
              });
              HapticFeedback.mediumImpact();
              inputWsClient.sendClick("left", "down");
            }
          });
          return;
        }
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event, TrackpadPreferences prefs) {
    final prevPos = _pointers[event.pointer];
    _pointers[event.pointer] = event.localPosition;

    setState(() {
      _touchIndicatorPos = event.localPosition;
    });

    if (prevPos == null) return;

    final dx = event.localPosition.dx - prevPos.dx;
    final dy = event.localPosition.dy - prevPos.dy;

    // Single finger: Move cursor
    if (_pointers.length == 1) {
      inputWsClient.sendMove(dx, dy, sensitivity: prefs.sensitivity);
    }
    // Two fingers: Two-finger scroll
    else if (_pointers.length == 2) {
      inputWsClient.sendScroll(dy * 0.4, dx: dx * 0.4, natural: prefs.isNaturalScroll);
    }
  }

  void _onPointerUp(PointerUpEvent event, TrackpadPreferences prefs) {
    _dragEngageTimer?.cancel();

    final startPos = _pointerStartPos.remove(event.pointer);
    final startTime = _pointerStartTime.remove(event.pointer);
    _pointers.remove(event.pointer);

    if (_pointers.isEmpty) {
      setState(() {
        _touchIndicatorPos = null;
      });
    }

    // If we were dragging, release left button immediately
    if (_isDragging) {
      setState(() {
        _isDragging = false;
      });
      HapticFeedback.lightImpact();
      inputWsClient.sendClick("left", "up");
      _lastTapEndTime = null;
      _lastTapEndPos = null;
      return;
    }

    final now = DateTime.now();
    final duration = startTime != null ? now.difference(startTime).inMilliseconds : 500;
    final distance = startPos != null ? (event.localPosition - startPos).distance : 999.0;

    // Quick tap check: finger held < 280ms and moved < 15px
    if (duration < 280 && distance < 15.0) {
      if (_pointers.isEmpty) {
        // Single-finger tap -> Left click tap
        HapticFeedback.selectionClick();
        inputWsClient.sendClick("left", "tap");

        _lastTapEndTime = now;
        _lastTapEndPos = event.localPosition;
      } else if (_pointers.length == 1) {
        // Two-finger tap -> Right click tap
        HapticFeedback.mediumImpact();
        inputWsClient.sendClick("right", "tap");
        _lastTapEndTime = null;
        _lastTapEndPos = null;
      }
    } else {
      _lastTapEndTime = null;
      _lastTapEndPos = null;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _dragEngageTimer?.cancel();
    _pointers.remove(event.pointer);
    _pointerStartPos.remove(event.pointer);
    _pointerStartTime.remove(event.pointer);
    if (_isDragging) {
      setState(() => _isDragging = false);
      inputWsClient.sendClick("left", "up");
    }
    if (_pointers.isEmpty) {
      setState(() => _touchIndicatorPos = null);
    }
  }

  void _showSensitivityDialog(BuildContext context, TrackpadPreferences prefs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentSens = ref.watch(trackpadPreferencesProvider).sensitivity;
            final isNatural = ref.watch(trackpadPreferencesProvider).isNaturalScroll;

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Trackpad Preferences',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${currentSens.toStringAsFixed(1)}x',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Pointer Sensitivity', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.cyan,
                      thumbColor: AppColors.cyan,
                      inactiveTrackColor: Colors.white12,
                    ),
                    child: Slider(
                      value: currentSens,
                      min: 0.5,
                      max: 3.0,
                      divisions: 25,
                      label: '${currentSens.toStringAsFixed(1)}x',
                      onChanged: (val) {
                        ref.read(trackpadPreferencesProvider.notifier).setSensitivity(val);
                      },
                    ),
                  ),
                  const Divider(height: 24, color: Colors.white12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Natural Scrolling', style: TextStyle(fontSize: 14)),
                    subtitle: const Text(
                      'Content follows finger movement (like mobile touchscreens)',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    value: isNatural,
                    activeColor: AppColors.cyan,
                    onChanged: (val) {
                      ref.read(trackpadPreferencesProvider.notifier).setNaturalScroll(val);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleTextInput(String val) {
    if (val.isEmpty) return;
    inputWsClient.sendText(val);
    _keyboardController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(trackpadPreferencesProvider);
    final wsStatus = ref.watch(inputConnectionStatusProvider).value ?? inputWsClient.status;
    final isConnected = wsStatus == ConnectionStatus.connected;
    final latency = ref.watch(latencyStreamProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Exit Trackpad',
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Remote Trackpad',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected ? AppColors.accentLive : AppColors.criticalRed,
                    boxShadow: [
                      BoxShadow(
                        color: (isConnected ? AppColors.accentLive : AppColors.criticalRed).withOpacity(0.6),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isConnected ? (latency != null ? 'Connected • $latency ms' : 'Connected') : 'Offline',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isConnected ? AppColors.accentLive : AppColors.metricNormal,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Hotkeys tray toggle
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.keyboard_command_key_rounded,
              color: prefs.showHotkeys ? AppColors.accentLive : AppColors.metricNormal,
              size: 20,
            ),
            tooltip: 'Special Modifiers & Hotkeys',
            onPressed: () {
              ref.read(trackpadPreferencesProvider.notifier).setShowHotkeys(!prefs.showHotkeys);
            },
          ),
          // Keyboard toggle
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.keyboard_alt_rounded,
              color: _isKeyboardVisible ? AppColors.accentLive : AppColors.metricNormal,
              size: 20,
            ),
            tooltip: 'Virtual Keyboard',
            onPressed: () {
              if (_keyboardFocusNode.hasFocus) {
                _keyboardFocusNode.unfocus();
              } else {
                _keyboardFocusNode.requestFocus();
              }
            },
          ),
          // Preferences button
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.tune_rounded, color: AppColors.metricNormal, size: 20),
            tooltip: 'Sensitivity & Preferences',
            onPressed: () => _showSensitivityDialog(context, prefs),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // Hidden off-screen TextField for native virtual keyboard
          Positioned(
            left: -9999,
            top: -9999,
            child: SizedBox(
              width: 1,
              height: 1,
              child: TextField(
                controller: _keyboardController,
                focusNode: _keyboardFocusNode,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.send,
                onSubmitted: (val) {
                  if (val.isNotEmpty) {
                    inputWsClient.sendText(val);
                    _keyboardController.clear();
                  }
                  inputWsClient.sendKey("enter", action: "tap");
                },
                onChanged: _handleTextInput,
              ),
            ),
          ),

          // Main Layout
          Column(
            children: [
              // Optional Hotkey Bar
              if (prefs.showHotkeys) _buildHotkeyBar(),

              // Dragging mode indicator badge
              if (_isDragging)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cyan, width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pan_tool_rounded, size: 14, color: AppColors.cyan),
                      SizedBox(width: 6),
                      Text(
                        'DRAG ACTIVE (Left Click Held)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cyan,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

              // Touch Surface + Scroll Strip
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      // Main Touchpad Area
                      Expanded(
                        child: _buildTouchpadSurface(prefs),
                      ),
                      const SizedBox(width: 10),
                      // Dedicated Vertical Scroll Strip
                      _buildScrollStrip(prefs),
                    ],
                  ),
                ),
              ),

              // Bottom Physical Click Zones
              _buildBottomClickBar(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHotkeyBar() {
    final hotkeys = [
      {'label': 'Esc', 'action': () => inputWsClient.sendKey('esc')},
      {'label': 'Win+D', 'action': () => inputWsClient.sendCombo(['win', 'd'])},
      {'label': 'Alt+Tab', 'action': () => inputWsClient.sendCombo(['alt', 'tab'])},
      {'label': 'Ctrl+C', 'action': () => inputWsClient.sendCombo(['ctrl', 'c'])},
      {'label': 'Ctrl+V', 'action': () => inputWsClient.sendCombo(['ctrl', 'v'])},
      {'label': 'Ctrl+Z', 'action': () => inputWsClient.sendCombo(['ctrl', 'z'])},
      {'label': 'Enter ↵', 'action': () => inputWsClient.sendKey('enter')},
      {'label': '⌫ Back', 'action': () => inputWsClient.sendKey('backspace')},
      {'label': 'Task Mgr', 'action': () => inputWsClient.sendCombo(['ctrl', 'shift', 'esc'])},
    ];

    return Container(
      height: 42,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0.0, 0.90, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(right: 28),
          itemCount: hotkeys.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, idx) {
            final hk = hotkeys[idx];
            return InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                (hk['action'] as VoidCallback)();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.buttonSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.buttonBorder, width: 1.0),
                ),
                child: Text(
                  hk['label'] as String,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTouchpadSurface(TrackpadPreferences prefs) {
    return Listener(
      onPointerDown: (e) => _onPointerDown(e, prefs),
      onPointerMove: (e) => _onPointerMove(e, prefs),
      onPointerUp: (e) => _onPointerUp(e, prefs),
      onPointerCancel: _onPointerCancel,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF11151D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isDragging ? AppColors.accentLive.withOpacity(0.8) : AppColors.panelBorder,
            width: _isDragging ? 1.5 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // 1. Tactile Precision Dot-Matrix Background
              Positioned.fill(
                child: CustomPaint(
                  painter: _DotGridPainter(),
                ),
              ),

              // 2. Crisp, Readable Gesture Hints (fades smoothly on touch)
              Center(
                child: AnimatedOpacity(
                  opacity: _pointers.isEmpty ? 0.70 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1218).withOpacity(0.75),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.panelBorder.withOpacity(0.6)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.touch_app_rounded, size: 36, color: AppColors.accentLive),
                        const SizedBox(height: 10),
                        const Text(
                          '1 Finger: Move & Tap  •  2 Fingers: Right Click & Scroll',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Double-Tap & Hold: Drag Window / Select Text',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.metricNormal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Visual Touch Cursor Ring with Glowing Feedback
              if (_touchIndicatorPos case final touchPos?)
                Positioned(
                  left: touchPos.dx - 24,
                  top: touchPos.dy - 24,
                  child: IgnorePointer(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_isDragging ? AppColors.accentLive : Colors.white).withOpacity(0.18),
                        border: Border.all(
                          color: _isDragging ? AppColors.accentLive : AppColors.accentLive.withOpacity(0.8),
                          width: 1.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentLive.withOpacity(0.35),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isDragging ? AppColors.accentLive : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollStrip(TrackpadPreferences prefs) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        inputWsClient.sendScroll(details.delta.dy * 0.8, natural: prefs.isNaturalScroll);
        setState(() {
          _scrollThumbY = (_scrollThumbY + details.delta.dy * 0.015).clamp(0.05, 0.95);
        });
      },
      child: Container(
        width: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF11151D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.panelBorder, width: 1.2),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxTravel = constraints.maxHeight - 46;
            final thumbTop = (_scrollThumbY * maxTravel).clamp(6.0, maxTravel + 6.0);

            return Stack(
              alignment: Alignment.topCenter,
              children: [
                // Centered subtle rail line
                Positioned(
                  top: 14,
                  bottom: 14,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                // Top arrow
                const Positioned(
                  top: 6,
                  child: Icon(Icons.keyboard_arrow_up_rounded, size: 16, color: Colors.white24),
                ),
                // Bottom arrow
                const Positioned(
                  bottom: 6,
                  child: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.white24),
                ),
                // Dynamic tactile scroll thumb indicator
                Positioned(
                  top: thumbTop,
                  child: Container(
                    width: 20,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.buttonSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.buttonBorder, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 8,
                        height: 2,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomClickBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              // Left Click (Large Primary Zone)
              Expanded(
                flex: 65,
                child: _ClickButton(
                  label: 'Left Click',
                  icon: Icons.mouse_rounded,
                  isLeft: true,
                  onDown: () {
                    HapticFeedback.lightImpact();
                    inputWsClient.sendClick("left", "down");
                  },
                  onUp: () {
                    inputWsClient.sendClick("left", "up");
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Right Click (Secondary Zone)
              Expanded(
                flex: 35,
                child: _ClickButton(
                  label: 'Right Click',
                  icon: Icons.menu_rounded,
                  isLeft: false,
                  onDown: () {
                    HapticFeedback.lightImpact();
                    inputWsClient.sendClick("right", "down");
                  },
                  onUp: () {
                    inputWsClient.sendClick("right", "up");
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClickButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isLeft;
  final VoidCallback onDown;
  final VoidCallback onUp;

  const _ClickButton({
    required this.label,
    required this.icon,
    required this.isLeft,
    required this.onDown,
    required this.onUp,
  });

  @override
  State<_ClickButton> createState() => _ClickButtonState();
}

class _ClickButtonState extends State<_ClickButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        widget.onDown();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onUp();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        widget.onUp();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          decoration: BoxDecoration(
            color: _isPressed
                ? (widget.isLeft ? const Color(0xFFE2E8F0) : AppColors.buttonSurface)
                : AppColors.panelBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isPressed
                  ? (widget.isLeft ? Colors.white : AppColors.accentLive)
                  : AppColors.panelBorder,
              width: _isPressed ? 1.5 : 1.2,
            ),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: (widget.isLeft ? Colors.white : AppColors.accentLive).withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  size: 16,
                  color: _isPressed
                      ? (widget.isLeft ? const Color(0xFF0B0F17) : Colors.white)
                      : Colors.white70,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _isPressed
                        ? (widget.isLeft ? const Color(0xFF0B0F17) : Colors.white)
                        : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for precision tactile dot-matrix texture
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF222A38)
      ..style = PaintingStyle.fill;
    const double step = 22.0;
    for (double x = step / 2; x < size.width; x += step) {
      for (double y = step / 2; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
