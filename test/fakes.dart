import 'dart:async';

import 'package:mole/mole.dart';

/// In-memory fake source for unit/widget tests.
class FakeMoleSource implements MoleSource {
  FakeMoleSource({
    Map<String, dynamic>? store,
    this.name = 'Fake Source',
    this.type = 'prefs',
  }) : _values = {
    ...?store,
  };

  final Map<String, dynamic> _values;
  late final StreamController<List<MoleDataEntry>> _controller =
      StreamController<List<MoleDataEntry>>.broadcast(onListen: _emit);

  /// List of currently cached entries.
  List<MoleDataEntry> _cache = const [];

  @override
  final String name;

  @override
  final String type;

  Map<String, dynamic> get values => Map.unmodifiable(_values);

  /// Current cached snapshot.
  List<MoleDataEntry> get cache => List.unmodifiable(_cache);

  int get length => _values.length;

  @override
  Stream<List<MoleDataEntry>> watch() => _controller.stream;

  void push(List<MoleDataEntry> entries) {
    _values
      ..clear()
      ..addEntries(
        entries.map((e) => MapEntry(e.key, e.value)),
      );
    _emit();
  }

  void set(String key, dynamic value) {
    _values[key] = value;
    _emit();
  }

  /// Simulates an external write (e.g. the host app talking directly to
  /// SharedPreferences) - the backing store changes WITHOUT a stream emit,
  /// exactly like sources that lack change notifications. Only [MoleStore.rescan]
  /// makes it visible.
  void seed(String key, dynamic value) {
    _values[key] = value;
  }

  @override
  Future<void> setValue(String key, dynamic value) async {
    _values[key] = value;
    _emit();
  }

  @override
  Future<void> deleteValue(String key) async {
    _values.remove(key);
    _emit();
  }

  @override
  Future<void> clearAll() async {
    _values.clear();
    _emit();
  }

  void _emit() {
    _cache = [
      for (final e in _values.entries)
        MoleDataEntry(
          key: e.key,
          value: e.value,
          sourceType: type,
        ),
    ];
    if (!_controller.isClosed) {
      _controller.add(_cache);
    }
  }

  void dispose() => _controller.close();
}