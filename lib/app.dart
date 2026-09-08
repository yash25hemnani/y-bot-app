import 'package:flutter/material.dart';
import 'package:y_bot_app/core/theme/app_theme.dart';
import 'package:y_bot_app/screens/root/root_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Y-BOT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const RootScreen(),
    );
  }
}
