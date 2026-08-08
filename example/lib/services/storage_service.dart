import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared storage helper so the demo app has somewhere to write data before
/// inspecting it with Mole.
class StorageService {
  StorageService._();

  static const secure = FlutterSecureStorage();

  static Future<Box> openBox() async {
    try {
      Hive.init('hive');
    } on Object {
      // Already initialized.
    }
    return Hive.openBox('mole_demo');
  }

  static Future<void> writePrefs(SharedPreferences prefs) async {
    await prefs.setString('username', 'mole');
    await prefs.setInt('login', 3);
    await prefs.setBool('dark_mode', false);
    await prefs.setDouble('rating', 4.75);
    await prefs.setStringList('theme_searches', ['mole', 'storage']);
  }

  static Future<void> writeHive(Box box) async {
    await box.put('profile', {'name': 'Mole', 'stats': [1, 2, 3]});
    await box.put('last_sync', DateTime.now().toIso8601String());
    await box.put('counter', 42);
  }

  static Future<void> writeSecure() async {
    await secure.write(key: 'access_token', value: 'secure-token-abc123');
    await secure.write(key: 'refresh_token', value: 'refresh-token-xyz789');
  }

  /// Writes a couple of cache files (one image, one json) into the app's temp
  /// directory so MoleCacheSource has something to display.
  static Future<void> writeCache() async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/mole_demo_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    // A tiny valid 1x1 PNG so the renderer can decode a thumbnail.
    await File('${cacheDir.path}/demo.png').writeAsBytes(_pngBytes());
    await File('${cacheDir.path}/summary.json')
        .writeAsString('{"app":"mole","entries":42}');
  }

  static Uint8List _pngBytes() => Uint8List.fromList(<int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);
}