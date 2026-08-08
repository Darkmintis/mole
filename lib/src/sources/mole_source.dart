/// Abstract contract for a storage source Mole can inspect.
///
/// Each built-in adapter wraps an existing storage instance the developer
/// already created. Mole never creates or owns storage instances itself.
///
/// Sources **push** changes via [watch]; Mole never polls. Implementations
/// must emit an initial snapshot on first listen, then emit again whenever the
/// underlying storage changes (including changes Mole performs through
/// [setValue] / [deleteValue] / [clearAll]).
library;

import '../core/mole_entry.dart';

export '../core/mole_entry.dart';

/// A storage source Mole can inspect.
abstract class MoleSource {
  /// Display name, e.g. `"SharedPreferences"`.
  String get name;

  /// Stable machine identifier: `prefs` | `hive` | `secure` | `isar`.
  String get type;

  /// Live snapshot stream of all entries in this source.
  ///
  /// Emits the current full list immediately on subscription and again on
  /// every change.
  Stream<List<MoleDataEntry>> watch();

  /// Writes [value] under [key].
  Future<void> setValue(String key, dynamic value);

  /// Deletes a single key. No-op when [key] does not exist.
  Future<void> deleteValue(String key);

  /// Clears all values in this source.
  Future<void> clearAll();
}