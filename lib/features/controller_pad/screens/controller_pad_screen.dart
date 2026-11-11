import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y_bot_app/core/theme/app_colors.dart';
import 'package:y_bot_app/core/theme/app_type.dart';
import 'package:y_bot_app/features/bluetooth/providers/bluetooth_connection_provider.dart';
import 'package:y_bot_app/features/bluetooth/services/bluetooth_service.dart';

class ControllerPadScreen extends ConsumerStatefulWidget {
  const ControllerPadScreen({super.key});

  @override
  ConsumerState<ControllerPadScreen> createState() =>
      _ControllerPadScreenState();
}

class _ControllerPadScreenState extends ConsumerState<ControllerPadScreen> {
  final _bt = AppBluetoothService.instance;

  BluetoothService? service;
  BluetoothCharacteristic? rxCharacteristic;
  BluetoothCharacteristic? txCharacteristic;
  StreamSubscription<List<int>>? _txSubscription;

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
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final device = ref.read(bluetoothConnectionProvider).connectedDevice;
    if (device != null) _loadServices(device);
  }

  @override
  void dispose() {
    _txSubscription?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // Control-desk pads: dark surfaces with teal arrows; Brake is the one red pad.
  // Commands are unchanged.
  Widget _pad(String label, String command, IconData icon, {bool danger = false}) {
    final ready = rxCharacteristic != null;
    final accent = !ready
        ? AppColors.textDisabled
        : danger
        ? AppColors.error
        : AppColors.primary;

    return Material(
      color: danger && ready ? AppColors.errorSurface : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: danger && ready ? AppColors.error.withValues(alpha: 0.5) : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: !ready
            ? null
            : () async {
                HapticFeedback.selectionClick();
                await rxCharacteristic!.write(command.codeUnits);
              },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32, color: accent),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppType.style(
                  size: 15,
                  weight: 600,
                  width: AppType.semiWide,
                  color: ready ? AppColors.textPrimary : AppColors.textDisabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = rxCharacteristic != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Controller pad', style: AppType.style(size: 20, weight: 600, width: AppType.wide)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                ready ? 'Ready' : 'Connect a robot to drive',
                style: AppType.style(size: 13, color: ready ? AppColors.primary : AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _pad("Left", "motor:left:speed:100", Icons.arrow_back_rounded)),
                    const SizedBox(height: 12),
                    Expanded(child: _pad("Backward", "motor:backward:speed:100", Icons.arrow_downward_rounded)),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: double.infinity,
                    height: 88,
                    child: _pad("Brake", "motor:brake", Icons.stop_rounded, danger: true),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _pad("Right", "motor:right:speed:100", Icons.arrow_forward_rounded)),
                    const SizedBox(height: 12),
                    Expanded(child: _pad("Forward", "motor:forward:speed:100", Icons.arrow_upward_rounded)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
