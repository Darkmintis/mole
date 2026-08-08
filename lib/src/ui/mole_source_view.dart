import 'package:flutter/material.dart';

import '../core/mole_store.dart';
import '../sources/mole_source.dart';
import 'mole_detail_view.dart';
import 'mole_theme.dart';
import 'mole_value_renderer.dart';

/// Table/list of all keys + values in a single source, live-updating.
///
/// Search by key, tap an entry to view/edit/delete, clear the whole source
/// with a confirmation dialog.
class MoleSourceView extends StatefulWidget {
  const MoleSourceView({
    super.key,
    required this.store,
    required this.source,
  });

  final MoleStore store;
  final MoleSource source;

  @override
  State<MoleSourceView> createState() => _MoleSourceViewState();
}

class _MoleSourceViewState extends State<MoleSourceView> {
  final _search = TextEditingController();
  String _query = '';
  bool _sensitiveVisible = false;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    _search.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  List<MoleDataEntry> get _visible {
    final all = widget.store.entriesOf(widget.source);
    if (_query.trim().isEmpty) return all;
    return all.where((e) => e.matches(_query)).toList(growable: false);
  }

  Future<void> _openEntry(MoleDataEntry entry) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 120),
        reverseTransitionDuration: const Duration(milliseconds: 100),
        pageBuilder: (context, animation, secondaryAnimation) {
          return MoleDetailView(
            store: widget.store,
            source: widget.source,
            entry: entry,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _confirmClear() async {
    final count = widget.store.countOf(widget.source);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear this source?'),
        content: Text(
          'This deletes all $count values in “${widget.source.name}”. '
          'This cannot be undone.',
        ),
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
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await widget.store.clearSource(widget.source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final all = widget.store.entriesOf(widget.source);
    final visible = _visible;

    return MoleTheme.wrap(
      context,
      (context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.source.name),
          actions: [
            if (widget.source.type == 'secure')
              IconButton(
                tooltip: _sensitiveVisible
                    ? 'Hide sensitive values'
                    : 'Reveal sensitive values',
                isSelected: _sensitiveVisible,
                onPressed: () {
                  setState(() => _sensitiveVisible = !_sensitiveVisible);
                },
                icon: Icon(
                  _sensitiveVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            IconButton(
              tooltip: 'Clear ${widget.source.name}',
              onPressed: all.isEmpty ? null : _confirmClear,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Search key or value…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? _EmptyState(searching: _query.trim().isNotEmpty)
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        24 + MediaQuery.paddingOf(context).bottom,
                      ),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = visible[index];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: entry.isSensitive
                                ? scheme.errorContainer
                                : scheme.primaryContainer,
                            child: Icon(
                              entry.isSensitive
                                  ? Icons.lock_outline_rounded
                                  : Icons.key_rounded,
                              size: 16,
                              color: entry.isSensitive
                                  ? scheme.onErrorContainer
                                  : scheme.onPrimaryContainer,
                            ),
                          ),
                           title: Text(
                            entry.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: MoleValueRenderer(
                            entry: entry,
                            revealed: _sensitiveVisible,
                            compact: true,
                          ),
                          onTap: () => _openEntry(entry),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? Icons.search_off_rounded : Icons.inbox_outlined,
              size: 40,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              searching ? 'No matches' : 'Empty source',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              searching
                  ? 'No keys match your search.'
                  : 'This source has no stored values.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}