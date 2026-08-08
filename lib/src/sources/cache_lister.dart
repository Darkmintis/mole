/// Platform shim for cache-file inspection.
///
/// Exposes the platform-specific implementation of cache browsing:
/// - On native (dart:io) this resolves to [cache_io.dart], which walks the
///   device's temp directory and reads file bytes.
/// - On the web (or any non-io platform) this resolves to [cache_web.dart],
///   which reports an empty list and declines destructive actions.
///
/// Every exported symbol uses platform-agnostic signatures (plain `String`
/// paths, [Uint8List], and [MoleFileEntry]), so importing this file never
/// pulls `dart:io` into a web build.
library;

export 'cache_io.dart' if (dart.library.html) 'cache_web.dart';
export 'mole_file_entry.dart';
