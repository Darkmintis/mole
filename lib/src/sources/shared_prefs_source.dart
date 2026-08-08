import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'mole_source.dart';

/// Adapts an existing [SharedPreferences] instance for inspection.
///
/// Values are shown exactly as stored — no masking.
///
/// `SharedPreferences` offers no external change notifications, so the stream
/// refreshes when Mole itself mutates the store, and the store re-snapshots on
/// source registration. Rapid writes are debounced by the store, not here.
class MoleSharedPrefsSource implements MoleSource {
  MoleSharedPrefsSource(this.prefs);

  final SharedPreferences prefs;
  late final StreamController<List<MoleDataEntry>> _stream = StreamController<List<MoleDataEntry>>.broadcast(onListen: _emit);

  @override
  String get name => 'SharedPreferences';

  @override
  String get type => 'prefs';

  @override
  Stream<List<MoleDataEntry>> watch() => _stream.stream;

  void _emit() {
    if (_stream.isClosed) return;
    _stream.add(_snapshot());
  }

  List<MoleDataEntry> _snapshot() {
    return [
      for (final key in prefs.getKeys())
        MoleDataEntry(
          key: key,
          value: prefs.get(key),
          sourceType: type,
        ),
    ];
  }

  @override
  Future<void> setValue(String key, dynamic value) async {
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(key, value);
    } else {
      await prefs.setString(key, value?.toString() ?? '');
    }
    _emit();
  }

  @override
  Future<void> deleteValue(String key) async {
    await prefs.remove(key);
    _emit();
  }

  @override
  Future<void> clearAll() async {
    await prefs.clear();
    _emit();
  }

  void dispose() {
    _stream.close();
  }
}