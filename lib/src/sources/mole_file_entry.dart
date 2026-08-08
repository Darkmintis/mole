/// Describes a single file inside a cache/temp directory, for inspection only.
///
/// Instances are produced by [MoleCacheSource] via a platform shim. The
/// absolute [path] is retained so the UI can read thumbnail bytes on demand
/// (lazily), but Mole itself never modifies these files except through the
/// explicit delete/clear actions — it never creates, owns, or writes to the
/// cache layer.
class MoleFileEntry {
  const MoleFileEntry({
    required this.name,
    required this.path,
    required this.size,
    required this.modified,
    required this.mimeType,
    required this.isImage,
  });

  /// Display name: the file's basename, e.g. `image.png`.
  final String name;

  /// Absolute filesystem path. Used by the renderer to read bytes for image
  /// previews when needed.
  final String path;

  /// File size in bytes.
  final int size;

  /// Last-modified timestamp, if available.
  final DateTime? modified;

  /// Best-effort MIME type, derived from the file extension.
  final String mimeType;

  /// Whether the extension is a known image type.
  final bool isImage;

  /// Human-friendly size, e.g. `1.2 KB`.
  String get displaySize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  @override
  String toString() => 'MoleFileEntry($name, $size bytes)';
}
