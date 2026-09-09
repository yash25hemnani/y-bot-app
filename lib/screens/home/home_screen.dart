import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y_bot_app/core/providers/bluetooth_connection_provider.dart';
import 'package:y_bot_app/core/services/bluetooth_service.dart';
import 'package:y_bot_app/screens/bluetooth/bluetooth_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _bt = AppBluetoothService.instance;

  BluetoothService? service;
  BluetoothCharacteristic? characteristic;

  Future<void> _loadServices(BluetoothDevice device) async {
    try {
      final services = await _bt.discoverServices(device);

      if (!mounted || services.isEmpty) return;

      final loadedService = services.firstWhere(
        (s) => s.uuid.str128 == "12345678-1234-1234-1234-123456789000",
      );

      final loadedCharacteristic = loadedService.characteristics.firstWhere(
        (c) => c.uuid.str128 == "12345678-1234-1234-1234-123456789001",
      );

      setState(() {
        service = loadedService;
        characteristic = loadedCharacteristic;
      });
    } catch (e) {
      debugPrint("Failed to discover services: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(bluetoothConnectionProvider, (previous, next) {
      final device = next.connectedDevice;

      if (device != null &&
          previous?.connectedDevice?.remoteId != device.remoteId) {
        _loadServices(device);
      } else if (device == null && previous?.connectedDevice != null) {
        setState(() {
          service = null;
          characteristic = null;
        });
      }
    });

    final connection = ref.watch(bluetoothConnectionProvider);
    final isConnected = connection.connectedId.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Chip(
                  avatar: Icon(
                    isConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    color: isConnected ? Colors.green : Colors.grey,
                  ),
                  label: Text(isConnected ? "Connected" : "Disconnected"),
                ),
                const SizedBox(height: 4),
                Text(
                  connection.connectedId.isNotEmpty
                      ? connection.connectedId
                      : "-",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const BluetoothScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.bluetooth),
                  label: Text(isConnected ? 'Manage Devices' : 'Find a Device'),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: characteristic == null
                          ? null
                          : () async {
                              await characteristic!.write("LED_ON".codeUnits);
                            },
                      child: const Text("ON"),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: characteristic == null
                          ? null
                          : () async {
                              await characteristic!.write(
                                "LED_OFF".codeUnits,
                              );
                            },
                      child: const Text("OFF"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
