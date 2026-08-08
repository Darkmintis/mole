import 'dart:typed_data';

import 'mole_file_entry.dart';

/// Web / unsupported-platform stub for cache browsing.
///
/// Cache inspection relies on a real filesystem, so it is intentionally a
/// no-op here — registering [MoleCacheSource] on the web surfaces an empty
/// source rather than crashing at import time.

Never _unsupported(String action) => throw UnsupportedError(
  'MoleCacheSource does not support "$action" on this platform. '
  'Cache browsing requires a filesystem-backed device.',
);

Future<String> moleTempPath() => Future.sync(() => _unsupported('read cache directory'));

Future<List<MoleFileEntry>> listFiles(String absoluteDir) =>
    Future.value(const <MoleFileEntry>[]);

Future<Uint8List> readFileBytes(String absolutePath) =>
    Future.sync(() => _unsupported('read cache file'));

Future<void> deleteFile(String absolutePath) =>
    Future.sync(() => _unsupported('delete cache file'));

Future<void> clearDirectory(String absoluteDir) =>
    Future.sync(() => _unsupported('clear cache directory'));

String relativePath(String root, String full) => full;
