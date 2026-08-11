import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'mole_source.dart';

/// Adapts an existing [FlutterSecureStorage] instance for inspection.
///
/// All entries are flagged [MoleDataEntry.isSensitive] and masked by default
/// in-app. Tap-to-reveal is handled by the UI layer.
///
/// `flutter_secure_storage` offers no change notifications, so the stream
/// refreshes when Mole itself mutates the store, and on registration.
class MoleSecureStorageSource implements MoleSource {
  /// Wraps an existing [FlutterSecureStorage] instance for Mole inspection.
  MoleSecureStorageSource(this.storage);

  final FlutterSecureStorage storage;
  late final StreamController<List<MoleDataEntry>> _stream =
      StreamController<List<MoleDataEntry>>.broadcast(onListen: _emit);

  @override
  String get name => 'Secure Storage';

  @override
  String get type => 'secure';

  @override
  Stream<List<MoleDataEntry>> watch() => _stream.stream;

  Future<void> _emit() async {
    if (_stream.isClosed) return;
    final all = await storage.readAll();
    _stream.add([
      for (final entry in all.entries)
        MoleDataEntry(
          key: entry.key,
          value: entry.value,
          sourceType: type,
          isSensitive: true,
        ),
    ]);
  }

  @override
  Future<void> setValue(String key, dynamic value) async {
    await storage.write(key: key, value: value?.toString());
    await _emit();
  }

  @override
  Future<void> deleteValue(String key) async {
    await storage.delete(key: key);
    await _emit();
  }

  @override
  Future<void> clearAll() async {
    await storage.deleteAll();
    await _emit();
  }

  void dispose() {
    _stream.close();
  }
}
