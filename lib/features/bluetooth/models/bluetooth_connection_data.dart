import 'package:flutter_blue_plus/flutter_blue_plus.dart';

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
