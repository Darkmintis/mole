import 'dart:async';

import 'cache_lister.dart';
import 'mole_source.dart';

/// Inspects real files in a cache/temp directory.
///
/// Cache is a **different shape** from the other built-in sources: it is files
/// on disk (written by `flutter_cache_manager`, `cached_network_image`, etc.),
/// not key/value pairs. This source only **reads and lists** them.
///
/// - **Zero config**: with no arguments it inspects the app's temporary
///   directory (the same directory the OS and cache packages use). Pass
///   [directoryPath] (mainly for tests) to inspect somewhere else.
/// - **Never creates, owns, or writes** to the cache layer — Mole only ever
///   lists, deletes individual files, or clears the directory on explicit user
///   command.
/// - **Read / delete only**: [setValue] throws, because files are never edited
///   through Mole.
/// - **No live watch of external writes**: like SharedPreferences, the snapshot
///   refreshes on registration and on every Mole-performed mutation. External
///   writes (the cache package writing new files) appear on the next rescan.
class MoleCacheSource implements MoleSource {
  /// [directoryPath] overrides the directory used (for tests). When `null`,
  /// the platform's temporary directory is resolved lazily on first watch.
  MoleCacheSource({String? directoryPath}) : _directoryPath = directoryPath;

  final String? _directoryPath;

  late final StreamController<List<MoleDataEntry>> _stream =
      StreamController<List<MoleDataEntry>>.broadcast(onListen: _emit);

  @override
  String get name => 'Cache';

  @override
  String get type => 'cache';

  @override
  Stream<List<MoleDataEntry>> watch() => _stream.stream;

  Future<String?> _resolveDir() {
    if (_directoryPath != null) return Future.value(_directoryPath);
    return moleTempPath();
  }

  Future<void> _emit() async {
    if (_stream.isClosed) return;
    final dir = await _resolveDir();
    if (dir == null || dir.isEmpty) {
      if (!_stream.isClosed) _stream.add(<MoleDataEntry>[]);
      return;
    }
    try {
      final files = await listFiles(dir);
      _stream.add([
        for (final f in files)
          MoleDataEntry(
            key: relativePath(dir, f.path),
            value: f,
            sourceType: type,
          ),
      ]);
    } on UnsupportedError {
      if (!_stream.isClosed) _stream.add(<MoleDataEntry>[]);
    } catch (_) {
      if (!_stream.isClosed) _stream.add(<MoleDataEntry>[]);
    }
  }

  @override
  Future<void> setValue(String key, dynamic value) async {
    throw UnsupportedError(
      'Cache files are read/delete only. '
      'MoleCacheSource does not implement setValue.',
    );
  }

  @override
  Future<void> deleteValue(String key) async {
    final dir = await _resolveDir();
    if (dir == null || dir.isEmpty) return;
    final absolute = '$dir/$key';
    await deleteFile(absolute);
    await _emit();
  }

  @override
  Future<void> clearAll() async {
    final dir = await _resolveDir();
    if (dir == null || dir.isEmpty) return;
    await clearDirectory(dir);
    await _emit();
  }

  void dispose() {
    _stream.close();
  }
}
