import 'package:flutter/material.dart';

import '../config/mole_config.dart';
import '../core/mole_store.dart';
import '../sources/mole_source.dart';
import 'mole_source_view.dart';
import 'mole_theme.dart';

/// Dashboard home: list of registered storage sources with live entry counts.
///
/// Tap a source to inspect its keys/values. Long-press or trailing button to
/// clear a single source.
class MoleDashboard extends StatefulWidget {
  const MoleDashboard({
    super.key,
    required this.store,
    required this.config,
    this.onClearAll,
  });

  final MoleStore store;
  final MoleConfig config;
  final VoidCallback? onClearAll;

  @override
  State<MoleDashboard> createState() => _MoleDashboardState();
}

class _MoleDashboardState extends State<MoleDashboard> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  void _openSource(MoleSource source) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 120),
        reverseTransitionDuration: const Duration(milliseconds: 100),
        pageBuilder: (context, animation, secondaryAnimation) {
          return MoleSourceView(
            store: widget.store,
            source: source,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _confirmClearSource(MoleSource source) async {
    final count = widget.store.countOf(source);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear this source?'),
        content: Text(
          'This deletes all $count stored values in '
          '“${source.name}”. This cannot be undone.',
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
      await widget.store.clearSource(source);
    }
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear everything?'),
        content: const Text(
          'This deletes every value in every registered source. '
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
            child: const Text('Clear all'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await widget.store.clearAll();
      widget.onClearAll?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sources = widget.store.sources;

    return MoleTheme.wrap(
      context,
      (context) => Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mole'),
              Text(
                sources.isEmpty
                    ? 'No sources registered'
                    : '${sources.length} source${sources.length == 1 ? '' : 's'} · '
                          '${widget.store.totalEntries} entries',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            if (sources.isNotEmpty)
              IconButton(
                tooltip: 'Rescan storage',
                onPressed: () {
                  widget.store.rescan();
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
            if (sources.isNotEmpty && widget.onClearAll != null)
              IconButton(
                tooltip: 'Clear everything',
                onPressed: _confirmClearAll,
                icon: const Icon(Icons.delete_forever_rounded),
              ),
          ],
        ),
        body: sources.isEmpty
            ? const _EmptyState()
            : ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                itemCount: sources.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final source = sources[index];
                  final count = widget.store.countOf(source);
                  final scheme = Theme.of(context).colorScheme;
                  return Material(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(
                          _iconFor(source),
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(
                        source.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '$count entr${count == 1 ? 'y' : 'ies'} · $count',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (count > 0)
                            IconButton(
                              tooltip: 'Clear ${source.name}',
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                              ),
                              onPressed: () => _confirmClearSource(source),
                            ),
                          if (count > 0)
                            IconButton(
                              tooltip: 'Open ${source.name}',
                              icon: const Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                              ),
                              onPressed: () => _openSource(source),
                            ),
                        ],
                      ),
                      onTap: count > 0 ? () => _openSource(source) : null,
                      onLongPress: count > 0
                          ? () => _confirmClearSource(source)
                          : null,
                    ),
                  );
                },
              ),
      ),
    );
  }

  IconData _iconFor(MoleSource source) {
    switch (source.type) {
      case 'prefs':
        return Icons.tune_rounded;
      case 'hive':
        return Icons.storage_rounded;
      case 'secure':
        return Icons.lock_outline_rounded;
      case 'cache':
        return Icons.folder_open_rounded;
      case 'isar':
        return Icons.data_object_rounded;
      default:
        return Icons.data_object_rounded;
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
              Icons.folder_open_rounded,
              size: 40,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              'No sources registered',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Register storage instances in Mole.install(sources: …) '
              'to inspect them here.',
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