import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissionService {
  AppPermissionService._();

  static final AppPermissionService instance = AppPermissionService._();

  /// Android 12+ (API 31+) doesn't need location for BLE 
  Future<bool> _needsLocationPermission() async {
    if (!Platform.isAndroid) return false;
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt < 31;
  }

  Future<bool> requestBluetoothPermissions() async {
    if (Platform.isAndroid) {
      final needsLocation = await _needsLocationPermission();

      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        if (needsLocation) Permission.locationWhenInUse,
      ].request();

      return statuses.values.every(
        (status) => status.isGranted || status.isLimited,
      );
    }

    if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      return status.isGranted;
    }

    return false;
  }

  /// Call this to check without triggering a prompt.
  Future<bool> hasBluetoothPermissions() async {
    if (Platform.isAndroid) {
      final scan = await Permission.bluetoothScan.status;
      final connect = await Permission.bluetoothConnect.status;
      if (!scan.isGranted || !connect.isGranted) return false;

      if (await _needsLocationPermission()) {
        final location = await Permission.locationWhenInUse.status;
        return location.isGranted;
      }
      return true;
    }
    if (Platform.isIOS) {
      return (await Permission.bluetooth.status).isGranted;
    }
    return false;
  }

  Future<void> openSettings() => openAppSettings();
}
