import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  static const _steerColor = Color(0xFF1E88E5);
  static const _forwardColor = Color(0xFF43A047);
  static const _backwardColor = Color(0xFFFB8C00);
  static const _brakeColor = Color(0xFFE53935);

  Widget _commandButton(String label, String command, Color color) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.zero,
      ),
      onPressed: rxCharacteristic == null
          ? null
          : () async {
              await rxCharacteristic!.write(command.codeUnits);
            },
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Controller Pad')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _commandButton(
                        "Left",
                        "motor:left:speed:100",
                        _steerColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _commandButton(
                        "Backward",
                        "motor:backward:speed:100",
                        _backwardColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: _commandButton("Brake", "motor:brake", _brakeColor),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _commandButton(
                        "Right",
                        "motor:right:speed:100",
                        _steerColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _commandButton(
                        "Forward",
                        "motor:forward:speed:100",
                        _forwardColor,
                      ),
                    ),
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
