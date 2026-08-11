import 'dart:async';

import 'package:flutter/foundation.dart';

import '../sources/mole_file_entry.dart';
import '../sources/mole_source.dart';

/// In-memory live view over the registered storage sources.
///
/// Holds the latest snapshot of every registered [MoleSource] and exposes
/// source/entry counts plus read/write helpers. Notifies listeners on any
/// change, with a **debounce** so rapid writes (tight loops) batch into a
/// single rebuild instead of rebuilding per write.
class MoleStore extends ChangeNotifier {
  MoleStore({
    Duration debounce = const Duration(milliseconds: 200),
    VoidCallback? onStorageChanged,
  })  : _debounce = debounce,
        onStorageChanged = onStorageChanged;

  final Duration _debounce;
  final List<MoleSource> _sources = <MoleSource>[];
  final Map<MoleSource, List<MoleDataEntry>> _cache = {};
  final Map<MoleSource, StreamSubscription<List<MoleDataEntry>>> _subs = {};
  Timer? _timer;
  bool _disposed = false;

  /// Called immediately after Mole writes to or deletes from real storage.
  ///
  /// Use this so the host app can reload UI that reads the same instances
  /// Mole already mutates (SharedPreferences, Hive box, etc.).
  VoidCallback? onStorageChanged;

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

  /// Total bytes across every cached file in cache-type sources.
  ///
  /// Used by the floating bubble for the §3b cache-size warning dot. Only
  /// [MoleFileEntry] values (files surfaced by a [MoleCacheSource]) count.
  int get totalCacheBytes {
    var total = 0;
    for (final entries in _cache.values) {
      for (final entry in entries) {
        final value = entry.value;
        if (value is MoleFileEntry) {
          total += value.size;
        }
      }
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
    // ignore: cancel_subscriptions - lifecycle managed by removeSource/dispose.
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
    onStorageChanged?.call();
    _scheduleNotify();
  }

  /// Deletes a single key through the given source.
  Future<void> deleteValue(MoleSource source, String key) async {
    await source.deleteValue(key);
    onStorageChanged?.call();
    _scheduleNotify();
  }

  /// Clears one source with a confirmation handled by the UI layer.
  Future<void> clearSource(MoleSource source) async {
    await source.clearAll();
    onStorageChanged?.call();
    _scheduleNotify();
  }

  /// Clears every registered source.
  Future<void> clearAll() async {
    for (final source in List<MoleSource>.of(_sources)) {
      await source.clearAll();
    }
    onStorageChanged?.call();
    _scheduleNotify();
  }

  /// Forces every source to re-read its backing storage and re-emit its
  /// current snapshot.
  ///
  /// Sources whose storage offers no change notifications (SharedPreferences,
  /// Secure Storage, Cache) can't detect external writes on their own. Opening
  /// the dashboard triggers this so data written behind Mole's back always
  /// shows up.
  Future<void> rescan() async {
    if (_disposed) return;
    for (final source in List<MoleSource>.of(_sources)) {
      final sub = _subs.remove(source);
      if (sub != null) {
        await sub.cancel();
      }
      // Re-listening runs the source's on-listen snapshot again, so it pulls
      // the freshest state from the backing storage (esp. non-notifying ones).
      // ignore: cancel_subscriptions - lifecycle managed by removeSource/dispose.
      final next = source.watch().listen(
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
      _subs[source] = next;
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