import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y_bot_app/core/theme/app_colors.dart';
import 'package:y_bot_app/core/theme/app_type.dart';
import 'package:y_bot_app/core/widgets/status_lamp.dart';
import 'package:y_bot_app/core/widgets/pulsing_icon.dart';
import 'package:y_bot_app/features/bluetooth/providers/bluetooth_connection_provider.dart';
import 'package:y_bot_app/features/bluetooth/services/bluetooth_service.dart';
import 'package:y_bot_app/features/bluetooth/services/permission_service.dart';

class BluetoothScreen extends ConsumerStatefulWidget {
  const BluetoothScreen({super.key});

  @override
  ConsumerState<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends ConsumerState<BluetoothScreen> {
  final _bt = AppBluetoothService.instance;
  List<ScanResult> _results = [];
  bool _isScanning = false;
  late final StreamSubscription<List<ScanResult>> _resultsSub;
  late final StreamSubscription<bool> _scanningSub;

  @override
  void initState() {
    super.initState();

    _resultsSub = _bt.scanResults.listen((results) {
      if (mounted) setState(() => _results = results);
    });
    _scanningSub = _bt.isScanning.listen((scanning) {
      if (mounted) setState(() => _isScanning = scanning);
    });

    _onScanPressed();
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

    final previousDevice = ref
        .read(bluetoothConnectionProvider)
        .connectedDevice;
    if (previousDevice != null) {
      await _disconnect(previousDevice);
    }
    if (!mounted) return;

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
    _resultsSub.cancel();
    _scanningSub.cancel();
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
            child: const Text(
              "Cancel",
              style: TextStyle(color: AppColors.textSecondary),
            ),
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
            child: const Text(
              "Cancel",
              style: TextStyle(color: AppColors.textSecondary),
            ),
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
    final textTheme = Theme.of(context).textTheme;

    final (title, hint) = _isScanning
        ? (
            'Scanning for Y-Bot...',
            'Make sure your Y-Bot is powered on and in pairing mode.',
          )
        : _results.isEmpty
        ? ('No Y-Bot found', 'Check it is powered on, then scan again.')
        : ('Pick your Y-Bot', 'Tap a device to connect.');

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Bluetooth', style: AppType.display),
              const SizedBox(height: 32),

              // Rings always pulse; tap to scan again
              Center(
                child: PulsingIcon(
                  icon: Icons.bluetooth_rounded,
                  onTap: _isScanning ? null : _onScanPressed,
                ),
              ),
              const SizedBox(height: 32),

              Text(
                title,
                textAlign: TextAlign.center,
                style: AppType.name,
              ),
              const SizedBox(height: 8),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              Expanded(
                child: ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final result = _results[index];
                    final id = result.device.remoteId.str;

                    return _DeviceCard(
                      result: result,
                      isConnecting: connection.connectingId == id,
                      isConnected: connection.connectedId == id,
                      onTap: () => _onDeviceTap(result.device),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              OutlinedButton(
                onPressed: _isScanning ? _bt.stopScan : _onScanPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
                child: Text(_isScanning ? 'Cancel' : 'Scan again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final ScanResult result;
  final bool isConnecting;
  final bool isConnected;
  final VoidCallback onTap;

  const _DeviceCard({
    required this.result,
    required this.isConnecting,
    required this.isConnected,
    required this.onTap,
  });

  String get _name {
    final device = result.device;
    if (device.advName.isNotEmpty) return device.advName;
    if (device.platformName.isNotEmpty) return device.platformName;
    return 'Unknown device';
  }

  // Rough RSSI buckets: closer devices show more bars
  IconData get _signalIcon {
    if (result.rssi >= -60) return Icons.signal_cellular_alt_rounded;
    if (result.rssi >= -75) return Icons.signal_cellular_alt_2_bar_rounded;
    return Icons.signal_cellular_alt_1_bar_rounded;
  }

  String get _status {
    if (isConnected) return 'Connected';
    if (isConnecting) return 'Connecting';
    return 'Tap to connect';
  }

  @override
  Widget build(BuildContext context) {
    final lamp = isConnected
        ? LampState.connected
        : isConnecting
        ? LampState.connecting
        : LampState.idle;

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isConnected ? AppColors.primaryDark : Colors.transparent,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isConnecting ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
          child: Row(
            children: [
              StatusLamp(state: lamp),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.name.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _status,
                      style: AppType.style(
                        size: 13,
                        color: isConnected ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isConnecting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Semantics(
                  label: 'Signal strength',
                  child: Icon(_signalIcon, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
