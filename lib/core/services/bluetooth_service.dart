import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:y_bot_app/core/services/permission_service.dart';

class AppBluetoothService {
  AppBluetoothService._();

  static final AppBluetoothService instance = AppBluetoothService._();

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  Future<bool> startScan({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final granted = await AppPermissionService.instance
        .requestBluetoothPermissions();

    if (!granted) return false;

    if (await FlutterBluePlus.isSupported == false) return false;

    await FlutterBluePlus.startScan(timeout: timeout);

    return true;
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  Future<void> connect(
    BluetoothDevice device, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await device.connect(
      license: License.nonprofit,
      autoConnect: false,
      timeout: timeout,
    );
  }

  Future<void> disconnect(BluetoothDevice device) => device.disconnect();

  Stream<BluetoothConnectionState> connectionState(BluetoothDevice device) =>
      device.connectionState;

  Future<List<BluetoothService>> discoverServices(BluetoothDevice device) =>
      device.discoverServices();

  
}
