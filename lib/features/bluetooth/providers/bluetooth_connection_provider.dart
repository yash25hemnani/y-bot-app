import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BluetoothConnectionData {
  // Device currently being connected to (drives the spinner).
  final String connectingId;
  // Device with an active connection.
  final String connectedId;
  final BluetoothDevice? connectedDevice;

  const BluetoothConnectionData({
    this.connectingId = "",
    this.connectedId = "",
    this.connectedDevice,
  });

  BluetoothConnectionData copyWith({
    String? connectingId,
    String? connectedId,
    BluetoothDevice? connectedDevice,
    bool clearConnectedDevice = false,
  }) {
    return BluetoothConnectionData(
      connectingId: connectingId ?? this.connectingId,
      connectedId: connectedId ?? this.connectedId,
      connectedDevice: clearConnectedDevice
          ? null
          : (connectedDevice ?? this.connectedDevice),
    );
  }
}

class BluetoothConnectionNotifier extends Notifier<BluetoothConnectionData> {
  @override
  BluetoothConnectionData build() => const BluetoothConnectionData();

  void setConnecting(String id) => state = state.copyWith(connectingId: id);

  void setConnected(BluetoothDevice device) => state = state.copyWith(
    connectingId: "",
    connectedId: device.remoteId.str,
    connectedDevice: device,
  );

  void clearConnecting() => state = state.copyWith(connectingId: "");

  void clearConnected() =>
      state = state.copyWith(connectedId: "", clearConnectedDevice: true);
}

final bluetoothConnectionProvider =
    NotifierProvider<BluetoothConnectionNotifier, BluetoothConnectionData>(
      BluetoothConnectionNotifier.new,
    );
