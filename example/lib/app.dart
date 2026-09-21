import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:mole/mole.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

class MoleExampleApp extends StatelessWidget {
  const MoleExampleApp({
    super.key,
    this.prefs,
    this.box,
    this.storageRevision,
  });

  final SharedPreferences? prefs;
  final Box? box;
  final ValueNotifier<int>? storageRevision;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mole Demo',
      debugShowCheckedModeBanner: false,
      // Required so the floating bubble can push the inspector.
      navigatorKey: Mole.navigatorKey,
      builder: Mole.builder,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: HomeScreen(
        key: ValueKey(prefs),
        prefs: prefs,
        box: box,
        storageRevision: storageRevision,
      ),
    );
  }
}