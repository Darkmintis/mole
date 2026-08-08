import 'package:flutter/material.dart';
import 'package:mole/mole.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

class MoleExampleApp extends StatelessWidget {
  const MoleExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mole Demo',
      debugShowCheckedModeBanner: false,
      navigatorKey: Mole.navigatorKey,
      builder: Mole.builder,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const HomeScreen(),
    );
  }
}