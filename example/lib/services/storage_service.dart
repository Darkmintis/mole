import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared storage helper so the demo app has somewhere to write data before
/// inspecting it with Mole.
///
/// Every section of the demo screen (see §10 of MOLE_PLAN.md) writes to a real
/// source:
/// - SharedPreferences - three separate pref keys (name / dark_mode /
///   notifications).
/// - Secure Storage - a fake `auth_token` (demonstrates masked display).
/// - Hive - a nested `Map` profile PLUS raw `Uint8List` bytes read from the
///   bundled `assets/profile.png` (proves the image-thumbnail path).
/// - Cache - a profile image file written under the app's temporary directory
///   so `MoleCacheSource` has a real, inspectable/deletable file.
class StorageService {
  StorageService._();

  static const secure = FlutterSecureStorage();

  /// Hive keys used by the demo. Editing/deleting `profile` in Mole should
  /// write through to the app on the next read.
  static const profileKey = 'profile';
  static const profileImageKey = 'profile_image';
  static const tokenKey = 'auth_token';

  static Future<Box> openBox() async {
    // Hive must be initialized with an absolute, app-private path. A relative
    // path (e.g. 'hive') resolves to a read-only location on Android/iOS and
    // throws `FileSystemException: Read-only file system`.
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    return Hive.openBox('mole_demo');
  }

  /// Reads the current preferences so the form can pre-fill from real storage
  /// (and reflect edits Mole made). Uses [SharedPreferences.get] so mixed
  /// types from inspector edits do not crash typed getters.
  static Map<String, Object?> currentPrefs(SharedPreferences prefs) {
    return {
      'name': prefs.get('name'),
      'dark_mode': prefs.get('dark_mode'),
      'notifications': prefs.get('notifications'),
    };
  }

  static String readString(Object? value) {
    if (value == null) return '';
    return value.toString();
  }

  static bool readBool(Object? value) {
    if (value is bool) return value;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true') return true;
      if (lower == 'false') return false;
    }
    return false;
  }

  /// Writes each form field as its own pref key - §10 SharedPreferences section.
  static Future<void> savePrefs(
    SharedPreferences prefs, {
    required String name,
    required bool darkMode,
    required bool notifications,
  }) async {
    await prefs.setString('name', name);
    await prefs.setBool('dark_mode', darkMode);
    await prefs.setBool('notifications', notifications);
  }

  /// Fake login - Secure Storage section.
  static Future<void> login() async {
    await secure.write(key: tokenKey, value: 'fake-token-abc123');
  }

  /// Reads the logged-in token, if any (used to echo the secure value back).
  static Future<String?> currentToken() => secure.read(key: tokenKey);

  /// Hive section: writes a nested profile Map plus raw image bytes from the
  /// bundled asset.
  static Future<void> saveProfile(Box box) async {
    await box.put(profileKey, <String, dynamic>{
      'name': 'Mole Demo',
      'theme': {'mode': 'system', 'accent': 'green'},
      'prefs': <String, dynamic>{
        'dark': true,
        'savedAt': DateTime.now().toIso8601String(),
      },
    });
    final imageBytes = await bundleImageBytes();
    await box.put(profileImageKey, imageBytes);
  }

  /// Loads the bundled [profile.png] (flutter asset) as raw bytes. This is
  /// what proves `MoleValueRenderer` can thumbnail real binary data.
  static Future<Uint8List> bundleImageBytes() async {
    final data = await rootBundle.load('assets/profile.png');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  /// Cache section: writes the bundled profile image + a JSON summary into the
  /// app temp directory so `MoleCacheSource` lists them as real files.
  static Future<void> writeCache() async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/mole_demo_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    // The cached "image" is the same bundled profile.png the Hive section
    // stored as raw bytes, so the thumbnail renderer decodes a real image.
    await File('${cacheDir.path}/profile.png').writeAsBytes(await _assetBytes());
    await File('${cacheDir.path}/summary.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'app': 'mole',
        'entries': 42,
        'repo': 'github.com/Darkmintis/mole',
      }),
    );
  }

  /// The bundled asset in normal runs; falls back to an inline 1x1 PNG so
  /// `flutter test` (no asset bundle) still works.
  static Future<Uint8List> _assetBytes() async {
    try {
      return await bundleImageBytes();
    } on Object {
      return _pngBytes();
    }
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