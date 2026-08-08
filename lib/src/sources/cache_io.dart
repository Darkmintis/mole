import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'mole_file_entry.dart';

/// Native (dart:io) implementation of cache browsing.

/// Absolute path to the app's temporary directory.
Future<String> moleTempPath() async => (await getTemporaryDirectory()).path;

/// Recursively lists every file under [absoluteDir] as inspection entries.
Future<List<MoleFileEntry>> listFiles(String absoluteDir) async {
  final dir = Directory(absoluteDir);
  if (!await dir.exists()) return const <MoleFileEntry>[];

  final result = <MoleFileEntry>[];
  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final size = await entity.length();
    DateTime? modified;
    try {
      modified = await entity.lastModified();
    } on Object {
      modified = null;
    }
    result.add(_toEntry(entity.path, size, modified));
  }
  result.sort((a, b) {
    final ta = a.modified ?? DateTime.fromMicrosecondsSinceEpoch(0);
    final tb = b.modified ?? DateTime.fromMicrosecondsSinceEpoch(0);
    return tb.compareTo(ta);
  });
  return result;
}

/// Reads the full byte content of a cached file. Used by the renderer to build
/// image thumbnails on demand (not eagerly).
Future<Uint8List> readFileBytes(String absolutePath) =>
    File(absolutePath).readAsBytes();

/// Deletes a single cached file.
Future<void> deleteFile(String absolutePath) async {
  final file = File(absolutePath);
  if (await file.exists()) {
    await file.delete();
  }
}

/// Removes every file and subdirectory inside [absoluteDir], leaving the
/// directory itself in place.
Future<void> clearDirectory(String absoluteDir) async {
  final dir = Directory(absoluteDir);
  if (!await dir.exists()) return;

  final entities = <FileSystemEntity>[];
  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    entities.add(entity);
  }
  // Delete deepest-first so non-empty subdirectories clear cleanly.
  entities.sort((a, b) => b.path.length.compareTo(a.path.length));
  for (final entity in entities) {
    await entity.delete(recursive: true);
  }
}

/// Path of [full], expressed relative to [root] using POSIX separators.
String relativePath(String root, String full) {
  if (full.startsWith(root)) {
    var rel = full.substring(root.length);
    while (rel.isNotEmpty && (rel[0] == '/' || rel[0] == '\\')) {
      rel = rel.substring(1);
    }
    return rel.replaceAll('\\', '/');
  }
  return full;
}

MoleFileEntry _toEntry(String path, int size, DateTime? modified) {
  final lower = path.toLowerCase();
  String mimeType = 'application/octet-stream';
  bool isImage = false;
  for (final ext in _imageExts) {
    if (lower.endsWith('.$ext')) {
      mimeType = 'image/$ext';
      isImage = true;
      break;
    }
  }
  if (!isImage && lower.endsWith('.json')) mimeType = 'application/json';

  return MoleFileEntry(
    name: _basename(path),
    path: path,
    size: size,
    modified: modified,
    mimeType: mimeType,
    isImage: isImage,
  );
}

String _basename(String path) {
  final i1 = path.lastIndexOf('/');
  final i2 = path.lastIndexOf('\\');
  final i = i1 > i2 ? i1 : i2;
  return i == -1 ? path : path.substring(i + 1);
}

const List<String> _imageExts = <String>[
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
  'wbmp',
  'svg',
  'heic',
  'avif',
];
