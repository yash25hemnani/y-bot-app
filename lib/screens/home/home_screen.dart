import 'package:flutter/material.dart';
import 'package:y_bot_app/screens/bluetooth/bluetooth_screen.dart';
import 'package:y_bot_app/screens/home/widgets/connected_device_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                ConnectedDeviceCard(),
                Text(
                  "Welcome",
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const BluetoothScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.bluetooth),
                  label: const Text('Bluetooth Devices'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
