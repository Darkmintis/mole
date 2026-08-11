/// A single stored key/value pair in a storage source.
///
/// [value] is the raw value exactly as stored. [isSensitive] marks the value
/// as sensitive (e.g. Secure Storage), which makes Mole mask it by default
/// in-app and reveal it only via explicit tap-to-reveal.
class MoleDataEntry {
  const MoleDataEntry({
    required this.key,
    this.value,
    this.sourceType = 'unknown',
    this.isSensitive = false,
  });

  /// The key of the stored value.
  final String key;

  /// The raw stored value. `null` entries are still real keys.
  final dynamic value;

  /// Machine identifier of the source type: `prefs` | `hive` | `secure` |
  /// `isar`.
  final String sourceType;

  /// Whether this value must be masked by default in the UI.
  final bool isSensitive;

  /// Human-friendly preview used for list rows.
  String get preview {
    if (value == null) return 'null';
    final text = value.toString();
    if (text.length <= 120) return text;
    return '${text.substring(0, 120)}…';
  }

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return key.toLowerCase().contains(q) ||
        (value?.toString().toLowerCase().contains(q) ?? false);
  }

  @override
  String toString() => 'MoleDataEntry($key = ${isSensitive ? '***' : preview})';
}
