import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y_bot_app/core/theme/app_colors.dart';
import 'package:y_bot_app/core/theme/app_type.dart';
import 'package:y_bot_app/core/widgets/screen_header.dart';
import 'package:y_bot_app/core/widgets/status_lamp.dart';
import 'package:y_bot_app/features/bluetooth/providers/bluetooth_connection_provider.dart';
import 'package:y_bot_app/features/bluetooth/services/bluetooth_service.dart';
import 'package:y_bot_app/features/bluetooth/screens/bluetooth_screen.dart';
import 'package:y_bot_app/features/controller_pad/screens/controller_pad_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _bt = AppBluetoothService.instance;

  BluetoothService? service;
  BluetoothCharacteristic? rxCharacteristic;
  BluetoothCharacteristic? txCharacteristic;
  StreamSubscription<List<int>>? _txSubscription;

  // Last LED state we sent. The robot doesn't report it back yet.
  bool _ledOn = false;

  Future<void> _loadServices(BluetoothDevice device) async {
    try {
      final services = await _bt.discoverServices(device);

      if (!mounted || services.isEmpty) return;

      debugPrint(
        "Discovered services: ${services.map((s) => s.uuid.str128).toList()}",
      );

      final loadedService = services.firstWhere(
        (s) => s.uuid.str128 == AppBluetoothService.serviceUuid,
      );

      debugPrint(
        "Discovered characteristics: "
        "${loadedService.characteristics.map((c) => c.uuid.str128).toList()}",
      );

      final loadedRxCharacteristic = loadedService.characteristics.firstWhere(
        (c) => c.uuid.str128 == AppBluetoothService.rxCharacteristicUuid,
      );

      final loadedTxCharacteristic = loadedService.characteristics.firstWhere(
        (c) => c.uuid.str128 == AppBluetoothService.txCharacteristicUuid,
      );

      await loadedTxCharacteristic.setNotifyValue(true);
      await _txSubscription?.cancel();

      _txSubscription = loadedTxCharacteristic.lastValueStream.listen((value) {
        debugPrint("BLE notify: ${String.fromCharCodes(value)}");
      });

      setState(() {
        service = loadedService;
        rxCharacteristic = loadedRxCharacteristic;
        txCharacteristic = loadedTxCharacteristic;
      });

      await loadedRxCharacteristic.write("settings:setup_completed".codeUnits);
    } catch (e) {
      debugPrint("Failed to discover services: $e");
    } 
  }

  

  @override
  void dispose() {
    _txSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(bluetoothConnectionProvider, (previous, next) {
      final device = next.connectedDevice;

      if (device != null &&
          previous?.connectedDevice?.remoteId != device.remoteId) {
        _loadServices(device);
      } else if (device == null && previous?.connectedDevice != null) {
        _txSubscription?.cancel();
        setState(() {
          service = null;
          rxCharacteristic = null;
          txCharacteristic = null;
          _ledOn = false;
        });
      }
    });

    final connection = ref.watch(bluetoothConnectionProvider);
    final isConnected = connection.connectedId.isNotEmpty;
    final isReady = rxCharacteristic != null;
    final device = connection.connectedDevice;
    final name = device == null
        ? 'Y-Bot'
        : device.advName.isNotEmpty
        ? device.advName
        : device.platformName.isNotEmpty
        ? device.platformName
        : 'Y-Bot';

    final (title, subtitle) = !isConnected
        ? ('No robot connected', 'Connect to your Y-Bot over Bluetooth to control it.')
        : isReady
        ? ('$name is ready', 'Connected over Bluetooth.')
        : ('Connecting to $name', 'Getting the robot ready for commands.');

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          children: [
            ScreenHeader(title: title, subtitle: subtitle),
            const SizedBox(height: 32),

            // Faceplate: which robot, and whether it's live
            _Plate(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                child: Row(
                  children: [
                    StatusLamp(
                      state: !isConnected
                          ? LampState.idle
                          : isReady
                          ? LampState.connected
                          : LampState.connecting,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isConnected ? name : 'Not connected',
                            style: AppType.name.copyWith(
                              color: isConnected ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                          if (isConnected) ...[
                            const SizedBox(height: 2),
                            Text(
                              connection.connectedId,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const BluetoothScreen()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(isConnected ? 'Change' : 'Connect'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            Text('Controls', style: AppType.section),
            const SizedBox(height: 12),

            // The desk: one row per control
            _Plate(
              child: Column(
                children: [
                  _ControlRow(
                    icon: Icons.lightbulb_outline_rounded,
                    title: 'Light',
                    subtitle: isReady ? (_ledOn ? 'On' : 'Off') : 'Connect a robot first',
                    enabled: isReady,
                    trailing: Switch(
                      value: _ledOn,
                      onChanged: isReady ? _setLight : null,
                    ),
                    onTap: isReady ? () => _setLight(!_ledOn) : null,
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _ControlRow(
                    icon: Icons.gamepad_outlined,
                    title: 'Controller pad',
                    subtitle: 'Drive the motors, in landscape',
                    enabled: true,
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const ControllerPadScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Switch moves first, then the command goes out; on failure it moves back
  Future<void> _setLight(bool on) async {
    final characteristic = rxCharacteristic;
    if (characteristic == null) return;
    setState(() => _ledOn = on);
    try {
      await characteristic.write((on ? 'led:on' : 'led:off').codeUnits);
    } catch (e) {
      if (!mounted) return;
      setState(() => _ledOn = !on);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Couldn't switch the light ${on ? 'on' : 'off'}. Check the robot is still connected."),
        ),
      );
    }
  }
}

// A flat surface panel, as on the admin panel's desk
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

class _ControlRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final Widget trailing;
  final VoidCallback? onTap;

  const _ControlRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = enabled ? AppColors.textPrimary : AppColors.textDisabled;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Icon(icon, color: enabled ? AppColors.primary : AppColors.textDisabled),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppType.style(size: 17, weight: 600, width: AppType.semiWide, color: titleColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppType.style(size: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }
}
