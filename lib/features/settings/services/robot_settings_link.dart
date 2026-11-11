import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:y_bot_app/features/bluetooth/services/bluetooth_service.dart';

// Why a settings command failed, in words the screen can show.
class RobotSettingsException implements Exception {
  final String code;

  const RobotSettingsException(this.code);

  String get message => switch (code) {
    'timeout' => "The robot didn't answer. Move closer and try again.",
    'busy' => 'The robot is busy. Wait a moment and try again.',
    'too_long' => 'One of the values is too long for the robot.',
    'format' => "The robot couldn't read that command.",
    'unknown_key' => "This robot's firmware doesn't support that setting.",
    'not_ybot' => "This device isn't a Y-Bot.",
    _ => 'The robot refused the change ($code).',
  };

  @override
  String toString() => 'RobotSettingsException($code)';
}

enum WifiResult { connected, wrongPassword, noNetwork, noCredentials, timedOut }

// Talks to the robot's settings module over BLE.
//
// Protocol (firmware: src/modules/settings/SettingsModule.h):
//   settings:write:<key>:<value>  -> ok:queued, then settings:write:<key>:ok
//   settings:read:<key>           -> settings:read:<key>:<value> (not for secrets)
//   settings:wifi_ready           -> settings:wifi_ready:1|0
//   settings:setup_completed      -> settings:setup_completed:1|0 (device_id + hmac_secret saved)
//   wifi:reconnect                -> wifi:status:connecting, then connected:<ip> | wrong_password | ...
// The robot handles one command at a time and answers error:busy otherwise,
// so every command waits for its own reply before the next one goes out.
class RobotSettingsLink {
  final BluetoothCharacteristic _rx;
  final StreamController<String> _replies = StreamController.broadcast();
  StreamSubscription<List<int>>? _notifications;
  Future<void> _queue = Future.value();

  // Values are stored in a 128-byte buffer on the robot (127 + terminator)
  static const int maxValueBytes = 127;

  RobotSettingsLink._(this._rx);

  static Future<RobotSettingsLink> open(BluetoothDevice device) async {
    // Home may be discovering services at the same moment; try once more if so
    List<BluetoothService> services;
    try {
      services = await device.discoverServices();
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 500));
      services = await device.discoverServices();
    }
    final service = services.where((s) => s.uuid.str128 == AppBluetoothService.serviceUuid).firstOrNull;
    if (service == null) throw const RobotSettingsException('not_ybot');

    BluetoothCharacteristic find(String uuid) =>
        service.characteristics.firstWhere((c) => c.uuid.str128 == uuid,
            orElse: () => throw const RobotSettingsException('not_ybot'));

    final rx = find(AppBluetoothService.rxCharacteristicUuid);
    final tx = find(AppBluetoothService.txCharacteristicUuid);

    final link = RobotSettingsLink._(rx);
    if (!tx.isNotifying) await tx.setNotifyValue(true);
    // onValueReceived only carries new notifications (lastValueStream would replay an old one)
    link._notifications = tx.onValueReceived.listen(
      (bytes) => link._replies.add(utf8.decode(bytes, allowMalformed: true).trim()),
    );
    return link;
  }

  Future<void> close() async {
    await _notifications?.cancel();
    await _replies.close();
  }

  // ---------- Commands ----------

  Future<void> write(String key, String value) async {
    if (utf8.encode(value).length > maxValueBytes) throw const RobotSettingsException('too_long');
    await _send('settings:write:$key:$value', 'settings:write:$key:ok');
  }

  Future<String> read(String key) async {
    final prefix = 'settings:read:$key:';
    final reply = await _send('settings:read:$key', prefix);
    return reply.substring(prefix.length);
  }

  Future<bool> wifiReady() async => (await _send('settings:wifi_ready', 'settings:wifi_ready:')).endsWith(':1');

  Future<bool> serverReady() async =>
      (await _send('settings:setup_completed', 'settings:setup_completed:')).endsWith(':1');

  // Applies saved Wi-Fi details now and waits for the outcome.
  // The robot also re-reads device_id / hmac_secret when it next reaches the server.
  Future<(WifiResult, String?)> reconnectWifi({Duration timeout = const Duration(seconds: 20)}) {
    return _enqueue(() async {
      final outcome = _replies.stream
          .where((r) => r.startsWith('wifi:status:') && r != 'wifi:status:connecting')
          .first
          .timeout(timeout);
      await _rx.write(utf8.encode('wifi:reconnect'));
      try {
        final status = (await outcome).substring('wifi:status:'.length);
        if (status.startsWith('connected')) {
          final ip = status.length > 'connected:'.length ? status.substring('connected:'.length) : null;
          return (WifiResult.connected, ip);
        }
        return (
          switch (status) {
            'wrong_password' => WifiResult.wrongPassword,
            'no_network' => WifiResult.noNetwork,
            _ => WifiResult.noCredentials,
          },
          null,
        );
      } on TimeoutException {
        return (WifiResult.timedOut, null);
      }
    });
  }

  // ---------- Plumbing ----------

  // Run commands strictly one after another, even if the screen fires several
  Future<T> _enqueue<T>(Future<T> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<String> _send(String command, String expectPrefix) {
    return _enqueue(() async {
      for (var attempt = 0; attempt < 6; attempt++) {
        // Listen before writing so a fast reply can't be missed
        final reply = _replies.stream
            .where((r) => r.startsWith(expectPrefix) || r.startsWith('error:'))
            .first
            .timeout(const Duration(seconds: 5));

        await _rx.write(utf8.encode(command));

        final String text;
        try {
          text = await reply;
        } on TimeoutException {
          throw const RobotSettingsException('timeout');
        }

        if (text == 'error:busy') {
          await Future.delayed(const Duration(milliseconds: 300));
          continue;
        }
        if (text.startsWith('error:')) throw RobotSettingsException(text.substring('error:'.length));
        return text;
      }
      throw const RobotSettingsException('busy');
    });
  }
}
