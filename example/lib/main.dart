import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mole/mole.dart';
import 'package:mole/secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'mole_config.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final box = await StorageService.openBox();
  final storageRevision = ValueNotifier<int>(0);

  Mole.install(
    config: moleConfig,
    sources: [
      MoleSharedPrefsSource(prefs),
      MoleHiveSource(box),
      MoleSecureStorageSource(const FlutterSecureStorage()),
      MoleCacheSource(),
    ],
    onStorageChanged: () => storageRevision.value++,
  );

  runApp(
    MoleExampleApp(
      prefs: prefs,
      box: box,
      storageRevision: storageRevision,
    ),
  );
}
