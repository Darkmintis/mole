/// Secure Storage adapter for Mole.
///
/// Import this library only when your app uses
/// [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage).
///
/// ```dart
/// import 'package:mole/mole.dart';
/// import 'package:mole/secure_storage.dart';
/// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
///
/// Mole.install(
///   sources: [
///     MoleSecureStorageSource(yourExistingFlutterSecureStorageInstance),
///   ],
/// );
/// ```
///
/// Add `flutter_secure_storage` to **your app's** `pubspec.yaml` at the version
/// you already use (9.x, 10.x, or 11.x). Mole supports `>=9.2.4 <12.0.0`.
library;

export 'src/sources/secure_storage_source.dart';
