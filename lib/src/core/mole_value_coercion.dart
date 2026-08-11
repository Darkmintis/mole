import 'dart:convert';

/// Coerces a string from the Mole edit dialog back toward the stored type.
dynamic coerceEditedValue(String text, dynamic existing) {
  if (existing is bool) {
    final lower = text.trim().toLowerCase();
    if (lower == 'true') return true;
    if (lower == 'false') return false;
    return existing;
  }
  if (existing is int) {
    return int.tryParse(text.trim()) ?? existing;
  }
  if (existing is double) {
    return double.tryParse(text.trim()) ?? existing;
  }
  if (existing is List || existing is Map) {
    try {
      return jsonDecode(text);
    } on Object {
      return existing;
    }
  }
  return text;
}
