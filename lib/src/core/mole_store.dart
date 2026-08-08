import 'dart:async';

import 'package:flutter/foundation.dart';

import '../sources/mole_source.dart';

/// In-memory live view over the registered storage sources.
///
/// Holds the latest snapshot of every registered [MoleSource] and exposes
/// source/entry counts plus read/write helpers. Notifies listeners on any
/// change, with a **debounce** so rapid writes (tight loops) batch into a
/// single rebuild instead of rebuilding per write.
class MoleStore extends ChangeNotifier {
  MoleStore({Duration debounce = const Duration(milliseconds: 200)})
    : _debounce = debounce;

  final Duration _debounce;
  final List<MoleSource> _sources = <MoleSource>[];
  final Map<MoleSource, List<MoleDataEntry>> _cache = {};
  final Map<MoleSource, StreamSubscription<List<MoleDataEntry>>> _subs = {};
  Timer? _timer;
  bool _disposed = false;

  /// Registered sources, in registration order.
  List<MoleSource> get sources => List.unmodifiable(_sources);

  /// Total number of stored entries across all sources.
  int get totalEntries {
    var total = 0;
    for (final v in _cache.values) {
      total += v.length;
    }
    return total;
  }

  /// True when no sources are registered.
  bool get isEmpty => _sources.isEmpty;

  /// Snapshot of [source]'s entries. Empty list when unknown.
  List<MoleDataEntry> entriesOf(MoleSource source) {
    return List.unmodifiable(_cache[source] ?? const <MoleDataEntry>[]);
  }

  /// Number of entries in [source].
  int countOf(MoleSource source) => _cache[source]?.length ?? 0;

  /// Registers a source and starts listening to its live stream.
  ///
  /// Ignores duplicates (same instance).
  void addSource(MoleSource source) {
    if (_disposed || _sources.contains(source)) return;
    _sources.add(source);
    _cache[source] = [];
    // ignore: cancel_subscriptions — lifecycle managed by removeSource/dispose.
    final sub = source.watch().listen(
      (entries) {
        if (_disposed) return;
        _cache[source] = List.of(entries);
        _scheduleNotify();
      },
      onError: (Object e) {
        if (_disposed) return;
        _cache[source] = [];
        _scheduleNotify();
      },
    );
    _subs[source] = sub;
    _scheduleNotify();
  }

  /// Removes and unsubscribes from a source.
  void removeSource(MoleSource source) {
    if (_disposed) return;
    _subs.remove(source)?.cancel();
    _sources.remove(source);
    _cache.remove(source);
    _scheduleNotify();
  }

  /// Writes a value through the store (also refreshes the source stream).
  Future<void> setValue(MoleSource source, String key, dynamic value) async {
    await source.setValue(key, value);
    _scheduleNotify();
  }

  /// Deletes a single key through the given source.
  Future<void> deleteValue(MoleSource source, String key) async {
    await source.deleteValue(key);
    _scheduleNotify();
  }

  /// Clears one source with a confirmation handled by the UI layer.
  Future<void> clearSource(MoleSource source) async {
    await source.clearAll();
    _scheduleNotify();
  }

  /// Clears every registered source.
  Future<void> clearAll() async {
    for (final source in List<MoleSource>.of(_sources)) {
      await source.clearAll();
    }
    _scheduleNotify();
  }

  void _scheduleNotify() {
    _timer?.cancel();
    _timer = Timer(_debounce, _notify);
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    for (final sub in _subs.values) {
      sub.cancel();
    }
    _subs.clear();
    _cache.clear();
    _sources.clear();
    super.dispose();
  }
}