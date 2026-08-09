import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mole/mole.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final box = await StorageService.openBox();

  Mole.install(
    config: const MoleConfig(),
    sources: [
      MoleSharedPrefsSource(prefs),
      MoleHiveSource(box),
      MoleSecureStorageSource(const FlutterSecureStorage()),
      MoleCacheSource(),
    ],
  );

  runApp(MoleExampleApp(prefs: prefs, box: box));
}