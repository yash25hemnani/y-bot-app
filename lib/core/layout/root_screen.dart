import 'package:flutter/material.dart';
import 'package:y_bot_app/core/widgets/segmented_nav_bar.dart';
import 'package:y_bot_app/features/bluetooth/screens/bluetooth_screen.dart';
import 'package:y_bot_app/features/home/screens/home_screen.dart';
import 'package:y_bot_app/features/settings/screens/settings_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    BluetoothScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: SegmentedNavBar(
        selectedIndex: _currentIndex,
        onSelected: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          SegmentedNavItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: "Home",
          ),
          SegmentedNavItem(
            icon: Icons.bluetooth_outlined,
            selectedIcon: Icons.bluetooth_rounded,
            label: 'Bluetooth',
          ),
          SegmentedNavItem(
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
