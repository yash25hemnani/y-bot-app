import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y_bot_app/core/providers/bluetooth_connection_provider.dart';
import 'package:y_bot_app/core/services/bluetooth_service.dart';
import 'package:y_bot_app/core/services/permission_service.dart';

class BluetoothScreen extends ConsumerStatefulWidget {
  const BluetoothScreen({super.key});

  @override
  ConsumerState<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends ConsumerState<BluetoothScreen> {
  final _bt = AppBluetoothService.instance;
  List<ScanResult> _results = [];

  @override
  void initState() {
    super.initState();

    _bt.startScan();

    _bt.scanResults.listen((results) {
      setState(() => _results = results);
    });
  }

  Future<void> _onScanPressed() async {
    final started = await _bt.startScan();
    if (!started && mounted) {
      _showPermissionDeniedDialog();
    }
  }

  Future<void> _onDeviceTap(BluetoothDevice device) async {
    final id = device.remoteId.str;
    final connectionNotifier = ref.read(bluetoothConnectionProvider.notifier);
    final connectedId = ref.read(bluetoothConnectionProvider).connectedId;

    if (connectedId == id) {
      final shouldDisconnect = await showDisconnectConfirmDialog(context);

      if (shouldDisconnect == true) {
        // actually disconnect the BLE device here
        await _disconnect(device);
      }

      return;
    }

    final previousDevice = ref.read(bluetoothConnectionProvider).connectedDevice;
    if (previousDevice != null) {
      await _disconnect(previousDevice);
    }

    final shouldConnect = await showConnectConfirmDialog(context);

    if (shouldConnect != true) {
      return;
    }

    connectionNotifier.setConnecting(id);

    try {
      await _bt.connect(device);
      _listenForDisconnect(device);
      if (mounted) {
        connectionNotifier.setConnected(device);
      }
    } catch (e) {
      if (mounted) {
        connectionNotifier.clearConnecting();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to connect: $e')));
      }
    }
  }

  Future<void> _disconnect(BluetoothDevice device) async {
    try {
      await _bt.disconnect(device);
    } finally {
      if (mounted) {
        ref.read(bluetoothConnectionProvider.notifier).clearConnected();
      }
    }
  }

  void _listenForDisconnect(BluetoothDevice device) {
    final id = device.remoteId.str;

    _bt.connectionState(device).listen((state) {
      final connectedId = ref.read(bluetoothConnectionProvider).connectedId;
      if (state == BluetoothConnectionState.disconnected &&
          mounted &&
          connectedId == id) {
        ref.read(bluetoothConnectionProvider.notifier).clearConnected();
      }
    });
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bluetooth permission needed'),
        content: const Text(
          'This app needs Bluetooth and location permissions to scan for nearby devices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              AppPermissionService.instance.openSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bt.stopScan();
    super.dispose();
  }

  Future<bool?> showDisconnectConfirmDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Disconnect?"),
        content: const Text("This will end your current connection."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Disconnect"),
          ),
        ],
      ),
    );
  }

  Future<bool?> showConnectConfirmDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Connect?"),
        content: const Text("Are you sure you want to connect?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Connect"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(bluetoothConnectionProvider);

    return SafeArea(
      child: Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: _onScanPressed,
          child: const Icon(Icons.bluetooth_searching),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text("Available Devices", textAlign: TextAlign.left, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))
            ),
            SizedBox(height: 4,),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final device = _results[index].device;
                  final id = device.remoteId.str;
                  final isConnecting = connection.connectingId == id;
                  final isConnected = connection.connectedId == id;
      
                  return ListTile(
                    title: Text(
                      device.advName.isNotEmpty
                          ? device.advName
                          : device.platformName.isNotEmpty
                          ? device.platformName
                          : 'Unknown device',
                    ),
                    subtitle: Text(id),
                    trailing: isConnecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isConnected ? 'Connected' : 'Tap to connect',
                            style: TextStyle(
                              color: isConnected ? Colors.green : Colors.grey,
                            ),
                          ),
                    onTap: isConnecting ? null : () => _onDeviceTap(device),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
