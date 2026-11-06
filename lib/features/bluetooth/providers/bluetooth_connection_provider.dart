import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y_bot_app/features/bluetooth/models/bluetooth_connection_data.dart';

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
