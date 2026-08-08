import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/mole_entry.dart';
import '../sources/cache_lister.dart';

/// One shared value renderer used by every source's list and detail views.
///
/// Instead of per-source rendering, this single widget decides how to draw an
/// entry's [MoleDataEntry.value] based on its runtime type:
/// - **Primitive** (`String`/`int`/`bool`/`double`) → inline text
/// - **Map / List** → pretty-printed, expandable JSON tree
/// - **Uint8List** → attempted image render; falls back to hex preview if the
///   bytes are not a decodable image
/// - **MoleFileEntry** (Cache) → file-type icon or image thumbnail + size/meta
///
/// Sensitive values are masked at the widget boundary; pass [revealed] based
/// on the source's "show sensitive" toggle. [compact] renders a denser,
/// no-decode representation suitable for list rows.
class MoleValueRenderer extends StatelessWidget {
  const MoleValueRenderer({
    super.key,
    required this.entry,
    this.revealed = true,
    this.compact = false,
  });

  final MoleDataEntry entry;

  /// Whether sensitive values should be shown in full (vs masked).
  final bool revealed;

  /// Whether to render a compact, decode-free row for list contexts.
  final bool compact;

  /// Central, single source of truth for the editing rule:
  /// only primitives and JSON-safe `Map`/`List` values are editable.
  /// Raw bytes (Hive `Uint8List`) and Cache files are **view/delete only**.
  static bool canEdit(MoleDataEntry entry) {
    final v = entry.value;
    if (entry.sourceType == 'cache') return false; // files are never edited
    if (v is Uint8List) return false; // raw bytes are never edited
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final v = entry.value;

    if (entry.isSensitive && !revealed) {
      return _masked();
    }

    if (compact) {
      return _Compact(entry: entry, value: v);
    }

    if (v is MoleFileEntry) return _FileDetail(file: v);
    if (v is Uint8List) return _BytesDetail(bytes: v);
    if (v is Map || v is List) return _JsonDetail(value: v);
    if (v is String) return _TextDetail(text: v);
    if (v is num || v is bool) return _TextDetail(text: v.toString());
    if (v == null) return const _TextDetail(text: 'null');

    return _TextDetail(text: 'Unsupported value of type ${v.runtimeType}');
  }

  Widget _masked() {
    const dots = '••••••••';
    return compact
        ? Text(dots, style: _style)
        : SelectableText(dots, style: _style);
  }

  static TextStyle get _style => const TextStyle(
        fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
      );
}

// ---------------------------------------------------------------------------
// Compact (list row) rendering
// ---------------------------------------------------------------------------

class _Compact extends StatelessWidget {
  const _Compact({required this.entry, this.value});

  final MoleDataEntry entry;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      color: scheme.onSurfaceVariant,
      height: 1.4,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );

    if (value is MoleFileEntry) {
      final f = value as MoleFileEntry;
      final icon = _fileIcon(f);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '${f.displaySize} · ${_modified(f)}',
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    if (value is Uint8List) {
      return Text(
        'Binary — ${(value as Uint8List).lengthInBytes} bytes',
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (value is Map || value is List) {
      String text;
      try {
        text = const JsonEncoder().convert(value);
      } on Object {
        text = value.toString();
      }
      if (text.length > 80) text = '${text.substring(0, 80)}…';
      return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final preview = entry.preview;
    return Text(preview, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  String _modified(MoleFileEntry f) {
    if (f.modified == null) return '';
    return '${f.modified!.month}/${f.modified!.day} ${_modifiedTime(f.modified!)}';
  }

  String _modifiedTime(DateTime d) {
    final h = d.hour.clamp(1, 12);
    final m = '${d.minute}'.padLeft(2, '0');
    final ap = d.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }
}

// ---------------------------------------------------------------------------
// Detailed rendering (detail view)
// ---------------------------------------------------------------------------

class _TextDetail extends StatelessWidget {
  const _TextDetail({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SelectableText(
      text,
      style: TextStyle(
        height: 1.45,
        color: scheme.onSurface,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }
}

class _JsonDetail extends StatefulWidget {
  const _JsonDetail({required this.value});

  final dynamic value;

  @override
  State<_JsonDetail> createState() => _JsonDetailState();
}

class _JsonDetailState extends State<_JsonDetail> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String text;
    try {
      text = const JsonEncoder.withIndent('  ').convert(widget.value);
    } on Object {
      text = widget.value.toString();
    }

    final isLong = text.length > 600;
    final shown = isLong
        ? (_expanded ? text : '${text.substring(0, 600)}…')
        : text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          shown,
          style: TextStyle(
            height: 1.45,
            color: scheme.onSurface,
            fontFamily: 'monospace',
          ),
        ),
        if (isLong)
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(
              _expanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
              size: 16,
            ),
            label: Text(_expanded ? 'Show less' : 'Show full'),
          ),
      ],
    );
  }
}

class _BytesDetail extends StatelessWidget {
  const _BytesDetail({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        return Image.memory(
          bytes,
          width: maxWidth.isFinite ? maxWidth : null,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _hexPreview(bytes),
        );
      },
    );
  }

  Widget _hexPreview(Uint8List bytes) {
    final preview = bytes.take(32);
    final buffer = StringBuffer()..write('Binary data — ${bytes.lengthInBytes} bytes\n');
    var i = 0;
    for (final b in preview) {
      if (i % 8 == 0 && i != 0) {
        buffer.write('\n');
      }
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
      buffer.write(' ');
      i += 1;
    }
    if (bytes.lengthInBytes > 32) {
      buffer.write('…');
    }
    return SelectableText(
      buffer.toString(),
      style: const TextStyle(fontFamily: 'monospace'),
    );
  }
}

class _FileDetail extends StatelessWidget {
  const _FileDetail({required this.file});

  final MoleFileEntry file;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget imagePreview;
    if (file.isImage) {
      imagePreview = FutureBuilder<Uint8List>(
        future: readFileBytes(file.path),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator(strokeAlign: -5)),
            );
          }
          final bytes = snapshot.data;
          if (bytes == null || bytes.isEmpty) {
            return const Icon(Icons.broken_image_outlined, size: 48);
          }
          return Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image_outlined, size: 48),
          );
        },
      );
    } else {
      imagePreview = const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (file.isImage) ...[imagePreview, const SizedBox(height: 16)],
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _meta(scheme, Icons.title_outlined, 'Name', file.name),
            _meta(scheme, Icons.numbers_outlined, 'Size', file.displaySize),
            _meta(scheme, Icons.image_outlined, 'Type', file.mimeType),
            if (file.modified != null)
              _meta(
                scheme,
                Icons.calendar_today_outlined,
                'Modified',
                file.modified!.toIso8601String(),
              ),
            _meta(scheme, Icons.link_outlined, 'Path', file.path),
          ],
        ),
      ],
    );
  }

  Widget _meta(ColorScheme scheme, IconData icon, String label, String value) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cache file icon helper
// ---------------------------------------------------------------------------

IconData _fileIcon(MoleFileEntry file) {
  if (file.isImage) return Icons.image_outlined;
  if (file.mimeType == 'application/json') return Icons.data_object_outlined;
  return Icons.description_outlined;
}
