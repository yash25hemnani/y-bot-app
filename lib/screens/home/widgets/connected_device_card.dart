import 'package:flutter/material.dart';

class ConnectedDeviceCard extends StatelessWidget {
  const ConnectedDeviceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 250,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [Text("ESP32-DEV-4A2C", style: TextStyle(fontSize: 16),)],
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Image.asset('assets/images/esp32.png', width: 200, height: 200),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
