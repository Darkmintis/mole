import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/mole_store.dart';
import '../sources/mole_source.dart';
import 'mole_theme.dart';
import 'mole_value_renderer.dart';

/// Single entry: shows key/value (masked when sensitive), with **Edit** and
/// **Delete** actions. Edits are raw-string for MVP (see plan §3, V2 for
/// type-aware edits).
class MoleDetailView extends StatefulWidget {
  const MoleDetailView({
    super.key,
    required this.store,
    required this.source,
    required this.entry,
  });

  final MoleStore store;
  final MoleSource source;
  final MoleDataEntry entry;

  @override
  State<MoleDetailView> createState() => _MoleDetailViewState();
}

class _MoleDetailViewState extends State<MoleDetailView> {
  late bool _revealed;

  @override
  void initState() {
    super.initState();
    _revealed = !widget.entry.isSensitive;
    widget.store.addListener(_onStore);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    super.dispose();
  }

  MoleDataEntry? get _currentEntry {
    for (final entry in widget.store.entriesOf(widget.source)) {
      if (entry.key == widget.entry.key) return entry;
    }
    return null;
  }

  void _onStore() {
    if (!mounted) return;
    if (_currentEntry == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {});
  }

  Future<void> _editValue() async {
    final entry = _currentEntry ?? widget.entry;
    final controller = TextEditingController(
      text: entry.value?.toString() ?? '',
    );
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit value'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Value',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != null && mounted) {
      await widget.store.setValue(widget.source, entry.key, saved);
    }
  }

  Future<void> _delete() async {
    final entry = _currentEntry ?? widget.entry;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete?'),
        content: Text('Delete "${entry.key}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await widget.store.deleteValue(widget.source, entry.key);
    }
  }

  Future<void> _copy() async {
    final entry = _currentEntry ?? widget.entry;
    final text = entry.isSensitive
        ? '(sensitive)'
        : '${entry.key} = ${entry.value}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = _currentEntry ?? widget.entry;

    return MoleTheme.wrap(context, (context) {
      final scheme = Theme.of(context).colorScheme;

      return Scaffold(
        appBar: AppBar(
          title: Text(entry.key),
          actions: [
            if (widget.source.type == 'secure')
              IconButton(
                tooltip: _revealed ? 'Hide value' : 'Reveal value',
                isSelected: _revealed,
                onPressed: () => setState(() => _revealed = !_revealed),
                icon: Icon(
                  _revealed
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            IconButton(
              tooltip: 'Copy',
              onPressed: _copy,
              icon: const Icon(Icons.copy_rounded),
            ),
            if (MoleValueRenderer.canEdit(entry))
              IconButton(
                tooltip: 'Edit',
                onPressed: _editValue,
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Text(
              'Key',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            SelectableText(
              entry.key,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'Value',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: entry.isSensitive ? 6 : 8),
            MoleValueRenderer(
              entry: entry,
              revealed: _revealed,
            ),
            if (entry.isSensitive && !MoleValueRenderer.canEdit(entry))
              const SizedBox(height: 8),
            if (entry.isSensitive)
              Text(
                'Sensitive value - masked by default. Use the eye icon to reveal.',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (MoleValueRenderer.canEdit(entry)) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _editValue,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
