import 'dart:async';

import 'package:hive/hive.dart';

import 'mole_source.dart';

/// Adapts an existing Hive [Box] for inspection.
///
/// Values are shown exactly as stored — no masking. The stream is derived
/// from the box's change events, so external writes push live updates too.
class MoleHiveSource implements MoleSource {
  MoleHiveSource(this.box);

  final Box<dynamic> box;
  late final StreamController<List<MoleDataEntry>> _stream = StreamController<List<MoleDataEntry>>.broadcast(onListen: _emit);
  StreamSubscription<dynamic>? _boxSub;

  @override
  String get name => 'Hive Box';

  @override
  String get type => 'hive';

  @override
  Stream<List<MoleDataEntry>> watch() {
    _boxSub ??= box.watch().listen((_) {
      _emit();
    });
    return _stream.stream;
  }

  void _emit() {
    if (_stream.isClosed) return;
    _stream.add(_snapshot());
  }

  List<MoleDataEntry> _snapshot() {
    return [
      for (final key in box.keys)
        MoleDataEntry(
          key: key.toString(),
          value: box.get(key),
          sourceType: type,
        ),
    ];
  }

  @override
  Future<void> setValue(String key, dynamic value) async {
    await box.put(key, value);
    _emit();
  }

  @override
  Future<void> deleteValue(String key) async {
    await box.delete(key);
    _emit();
  }

  @override
  Future<void> clearAll() async {
    await box.clear();
    _emit();
  }

  void dispose() {
    unawaited(_boxSub?.cancel());
    _stream.close();
  }
}