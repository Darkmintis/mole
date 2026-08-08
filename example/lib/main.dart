import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mole/mole.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  Mole.install(
    config: const MoleConfig(),
    sources: [
      MoleSharedPrefsSource(prefs),
      MoleHiveSource(await StorageService.openBox()),
      MoleSecureStorageSource(const FlutterSecureStorage()),
      MoleCacheSource(),
    ],
  );

  runApp(const MoleExampleApp());
}