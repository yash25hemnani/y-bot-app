import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:y_bot_app/core/services/bluetooth_service.dart';
import 'package:y_bot_app/core/services/permission_service.dart';

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  final _bt = AppBluetoothService.instance;
  List<ScanResult> _results = [];

  // Tracks devices currently being connected to (shows spinner).
  final Set<String> _connectingIds = {};
  // Tracks devices with an active connection.
  final Set<String> _connectedIds = {};

  @override
  void initState() {
    super.initState();

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

    if (_connectedIds.contains(id)) {
      await _disconnect(device);
      return;
    }

    setState(() => _connectingIds.add(id));

    try {
      await _bt.connect(device);
      _listenForDisconnect(device);
      if (mounted) {
        setState(() {
          _connectingIds.remove(id);
          _connectedIds.add(id);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _connectingIds.remove(id));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to connect: $e')));
      }
    }
  }

  Future<void> _disconnect(BluetoothDevice device) async {
    final id = device.remoteId.str;
    try {
      await _bt.disconnect(device);
    } finally {
      if (mounted) {
        setState(() => _connectedIds.remove(id));
      }
    }
  }

  void _listenForDisconnect(BluetoothDevice device) {
    final id = device.remoteId.str;

    _bt.connectionState(device).listen((state) {
      if (state == BluetoothConnectionState.disconnected && mounted) {
        setState(() => _connectedIds.remove(id));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _onScanPressed,
        child: const Icon(Icons.bluetooth_searching),
      ),
      body: ListView.builder(
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final device = _results[index].device;
          final id = device.remoteId.str;
          final isConnecting = _connectingIds.contains(id);
          final isConnected = _connectedIds.contains(id);

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
    );
  }
}
