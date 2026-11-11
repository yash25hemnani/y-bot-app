import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y_bot_app/core/theme/app_colors.dart';
import 'package:y_bot_app/core/theme/app_type.dart';
import 'package:y_bot_app/core/widgets/screen_header.dart';
import 'package:y_bot_app/core/widgets/status_lamp.dart';
import 'package:y_bot_app/features/bluetooth/providers/bluetooth_connection_provider.dart';
import 'package:y_bot_app/features/bluetooth/screens/bluetooth_screen.dart';
import 'package:y_bot_app/features/settings/services/robot_settings_link.dart';

// Settings saved on the robot itself, over Bluetooth.
// Secrets (Wi-Fi password, secret key) are write-only on the robot, so those
// fields start empty and a blank field means "keep what's saved".
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

enum _Tone { success, warning, error }

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wifiName = TextEditingController();
  final _wifiPassword = TextEditingController();
  final _deviceId = TextEditingController();
  final _secretKey = TextEditingController();

  RobotSettingsLink? _link;
  bool _loading = false;
  bool _saving = false;
  String? _progress;
  bool? _wifiReady;
  bool? _serverReady;
  (String, _Tone)? _message;

  // What the robot had when we last read it, so unchanged fields aren't re-sent
  String _savedWifiName = '';
  String _savedDeviceId = '';

  bool _showPassword = false;
  bool _showSecret = false;

  @override
  void initState() {
    super.initState();
    final device = ref.read(bluetoothConnectionProvider).connectedDevice;
    if (device != null) _connect(device);
  }

  @override
  void dispose() {
    _link?.close();
    _wifiName.dispose();
    _wifiPassword.dispose();
    _deviceId.dispose();
    _secretKey.dispose();
    super.dispose();
  }

  // ---------- Talking to the robot ----------

  Future<void> _connect(BluetoothDevice device) async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final link = await RobotSettingsLink.open(device);
      if (!mounted) return link.close();
      _link = link;
      await _refresh(prefill: true);
    } on RobotSettingsException catch (e) {
      _show(e.message, _Tone.error);
    } catch (_) {
      _show("Couldn't read the robot's settings. Reconnect it and try again.", _Tone.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _disconnect() async {
    await _link?.close();
    _link = null;
    if (!mounted) return;
    setState(() {
      _wifiReady = null;
      _serverReady = null;
      _message = null;
      _savedWifiName = '';
      _savedDeviceId = '';
      for (final c in [_wifiName, _wifiPassword, _deviceId, _secretKey]) {
        c.clear();
      }
    });
  }

  Future<void> _refresh({bool prefill = false}) async {
    final link = _link;
    if (link == null) return;
    final wifiReady = await link.wifiReady();
    final serverReady = await link.serverReady();
    if (prefill) {
      _savedWifiName = await link.read('wifi_name');
      _savedDeviceId = await link.read('device_id');
    }
    if (!mounted) return;
    setState(() {
      _wifiReady = wifiReady;
      _serverReady = serverReady;
      if (prefill) {
        _wifiName.text = _savedWifiName;
        _deviceId.text = _savedDeviceId;
      }
    });
  }

  Future<void> _save() async {
    final link = _link;
    if (link == null || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final name = _wifiName.text.trim();
    final password = _wifiPassword.text;
    final deviceId = _deviceId.text.trim().toLowerCase();
    final secret = _secretKey.text.trim().toLowerCase();

    // Blank fields keep what's saved; unchanged ones aren't re-sent
    final writes = <(String, String, String)>[
      if (name.isNotEmpty && name != _savedWifiName) ('wifi_name', name, 'Wi-Fi name'),
      if (password.isNotEmpty) ('wifi_password', password, 'Wi-Fi password'),
      if (deviceId.isNotEmpty && deviceId != _savedDeviceId) ('device_id', deviceId, 'device ID'),
      if (secret.isNotEmpty) ('hmac_secret', secret, 'secret key'),
    ];

    if (writes.isEmpty) {
      _show('Nothing to save. Change a field first.', _Tone.warning);
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
    });

    try {
      for (final (key, value, label) in writes) {
        setState(() => _progress = 'Saving $label…');
        await link.write(key, value);
      }
      _savedWifiName = name.isNotEmpty ? name : _savedWifiName;
      _savedDeviceId = deviceId.isNotEmpty ? deviceId : _savedDeviceId;
      _wifiPassword.clear();
      _secretKey.clear();

      // Apply now: the robot rejoins Wi-Fi, then reaches the server with the new keys
      setState(() => _progress = 'Connecting to Wi-Fi…');
      final (wifi, ip) = await link.reconnectWifi();
      setState(() => _progress = 'Checking…');
      await _refresh();

      final serverNote = _serverReady == true
          ? ' It will connect to the server with its device ID and key.'
          : ' Add a device ID and secret key so it can reach the server.';
      switch (wifi) {
        case WifiResult.connected:
          _show('Saved. The robot is on Wi-Fi${ip != null ? ' at $ip' : ''}.$serverNote', _Tone.success);
        case WifiResult.wrongPassword:
          _show('Saved, but the Wi-Fi password was wrong. Enter it again and save.', _Tone.error);
        case WifiResult.noNetwork:
          _show("Saved, but the robot can't find “$_savedWifiName”. Check the name and that the network is in range.", _Tone.error);
        case WifiResult.noCredentials:
          _show('Saved. Add a Wi-Fi name and password so the robot can get online.', _Tone.warning);
        case WifiResult.timedOut:
          _show("Saved. The robot is still joining Wi-Fi; check back in a moment.", _Tone.warning);
      }
    } on RobotSettingsException catch (e) {
      _show(e.message, _Tone.error);
    } catch (_) {
      _show('Lost contact with the robot while saving. Reconnect it and try again.', _Tone.error);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _progress = null;
        });
      }
    }
  }

  void _show(String text, _Tone tone) {
    if (mounted) setState(() => _message = (text, tone));
  }

  // ---------- Validation ----------

  static final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
  static final _hex64 = RegExp(r'^[0-9a-fA-F]{64}$');

  String? _checkWifiName(String? v) {
    final value = v?.trim() ?? '';
    if (utf8.encode(value).length > 32) return 'Wi-Fi names are 32 characters at most.';
    return null;
  }

  String? _checkWifiPassword(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return null;
    if (value.length < 8 || value.length > 63) return 'Wi-Fi passwords are 8 to 63 characters.';
    return null;
  }

  String? _checkDeviceId(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty || _uuid.hasMatch(value)) return null;
    return 'Paste the full device ID, like 291c7e62-292f-4225-8feb-44630c5b8d1b.';
  }

  String? _checkSecret(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty || _hex64.hasMatch(value)) return null;
    return 'The secret key is 64 letters and numbers. Copy it again from the admin panel.';
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    ref.listen(bluetoothConnectionProvider, (previous, next) {
      final device = next.connectedDevice;
      if (device != null && previous?.connectedDevice?.remoteId != device.remoteId) {
        _connect(device);
      } else if (device == null && previous?.connectedDevice != null) {
        _disconnect();
      }
    });

    final isConnected = ref.watch(bluetoothConnectionProvider).connectedDevice != null;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            const ScreenHeader(
              title: 'Settings',
              subtitle: 'Saved on the robot over Bluetooth.',
            ),
            const SizedBox(height: 32),
            if (!isConnected) _notConnected(context) else ..._form(context),
          ],
        ),
      ),
    );
  }

  Widget _notConnected(BuildContext context) {
    return _Plate(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connect a robot first', style: AppType.style(size: 18, weight: 600, width: AppType.semiWide)),
            const SizedBox(height: 6),
            Text(
              'Wi-Fi and server details are stored on the robot, so it needs to be connected over Bluetooth.',
              style: AppType.style(size: 14, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const BluetoothScreen()),
              ),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _form(BuildContext context) {
    final busy = _loading || _saving;

    return [
      // Live status, read from the robot
      _Plate(
        child: Column(
          children: [
            _StatusRow(
              label: 'Wi-Fi',
              lamp: _loading
                  ? LampState.connecting
                  : _wifiReady == null
                  ? LampState.idle
                  : _wifiReady!
                  ? LampState.connected
                  : LampState.idle,
              value: _loading
                  ? 'Checking…'
                  : _wifiReady == null
                  ? 'Unknown'
                  : _wifiReady!
                  ? 'Saved'
                  : 'Not set up',
            ),
            const Divider(height: 1, color: AppColors.border),
            _StatusRow(
              label: 'Server',
              lamp: _loading
                  ? LampState.connecting
                  : _serverReady == null
                  ? LampState.idle
                  : _serverReady!
                  ? LampState.connected
                  : LampState.idle,
              value: _loading
                  ? 'Checking…'
                  : _serverReady == null
                  ? 'Unknown'
                  : _serverReady!
                  ? 'Device ID and key saved'
                  : 'Needs device ID and key',
            ),
          ],
        ),
      ),
      const SizedBox(height: 32),

      Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Wi-Fi', style: AppType.section),
              const SizedBox(height: 6),
              Text(
                'The network the robot joins to reach the server.',
                style: AppType.style(size: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              _Field(
                controller: _wifiName,
                label: 'Network name',
                enabled: !busy,
                validator: _checkWifiName,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              _Field(
                controller: _wifiPassword,
                label: 'Password',
                helper: _wifiReady == true ? 'Leave blank to keep the saved password.' : null,
                enabled: !busy,
                obscure: !_showPassword,
                onToggleObscure: () => setState(() => _showPassword = !_showPassword),
                validator: _checkWifiPassword,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 32),

              Text('Server', style: AppType.section),
              const SizedBox(height: 6),
              Text(
                'Copy these from the admin panel: Devices, then this robot. The secret key is only shown when you register the robot or issue a new key.',
                style: AppType.style(size: 14, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              _Field(
                controller: _deviceId,
                label: 'Device ID',
                enabled: !busy,
                validator: _checkDeviceId,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              _Field(
                controller: _secretKey,
                label: 'Secret key',
                helper: _serverReady == true ? 'Leave blank to keep the saved key.' : null,
                enabled: !busy,
                obscure: !_showSecret,
                onToggleObscure: () => setState(() => _showSecret = !_showSecret),
                validator: _checkSecret,
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 32),

      if (_message != null) ...[
        _Notice(text: _message!.$1, tone: _message!.$2),
        const SizedBox(height: 16),
      ],

      ElevatedButton(
        onPressed: busy ? null : _save,
        child: _saving
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  Text(_progress ?? 'Saving…'),
                ],
              )
            : const Text('Save to robot'),
      ),
    ];
  }
}

// ---------- Pieces ----------

class _Plate extends StatelessWidget {
  final Widget child;

  const _Plate({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final LampState lamp;
  final String value;

  const _StatusRow({required this.label, required this.lamp, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 20, 14),
      child: Row(
        children: [
          StatusLamp(state: lamp, size: 12),
          const SizedBox(width: 10),
          Text(label, style: AppType.style(size: 17, weight: 600, width: AppType.semiWide)),
          const Spacer(),
          Text(value, style: AppType.style(size: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? helper;
  final bool enabled;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;

  const _Field({
    required this.controller,
    required this.label,
    required this.enabled,
    this.helper,
    this.obscure = false,
    this.onToggleObscure,
    this.validator,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: textInputAction,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: AppType.style(size: 16),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 2,
        errorMaxLines: 3,
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                onPressed: onToggleObscure,
                tooltip: obscure ? 'Show' : 'Hide',
                icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  final _Tone tone;

  const _Notice({required this.text, required this.tone});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (tone) {
      _Tone.success => (AppColors.success, Icons.check_circle_outline_rounded),
      _Tone.warning => (AppColors.warning, Icons.warning_amber_rounded),
      _Tone.error => (AppColors.error, Icons.error_outline_rounded),
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Color.alphaBlend(color.withValues(alpha: 0.12), AppColors.background),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: AppType.style(size: 14, height: 1.4))),
          ],
        ),
      ),
    );
  }
}
