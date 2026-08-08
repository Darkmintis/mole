import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/storage_service.dart';

/// Demo home: buttons that write rows into each storage source so the user can
/// open the Mole bubble and inspect / edit / clear them.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Box? _box;
  SharedPreferences? _prefs;
  String _status = 'Write some data, then tap the Mole bubble';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final box = await StorageService.openBox();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _box = box;
    });
  }

  void _setStatus(String message) {
    if (mounted) setState(() => _status = message);
  }

  Future<void> _write(String label, Future<void> Function() action) async {
    _setStatus('Writing $label…');
    await action();
    _setStatus('$label written — open the Mole bubble');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mole Demo')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            'Each button writes into a different storage backend. '
            'Then open the floating Mole bubble to inspect, edit, and clear '
            'the stored data.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
_ActionTile(
            color: const Color(0xFF1B6B4A),
            title: 'SharedPreferences',
            subtitle: 'String · int · bool · double · StringList',
            enabled: _prefs != null,
            onPressed: () => _write(
              'SharedPreferences',
              () => StorageService.writePrefs(_prefs!),
            ),
          ),
          const SizedBox(height: 8),
_ActionTile(
            color: const Color(0xFF1565C0),
            title: 'Hive box',
            subtitle: 'Map · String · int',
            enabled: _box != null,
            onPressed: () => _write('Hive box', () => StorageService.writeHive(_box!)),
          ),
          const SizedBox(height: 8),
          _ActionTile(
            color: const Color(0xFF6A1B9A),
            title: 'Secure Storage',
            subtitle: 'Tokens — masked by default in Mole',
            enabled: true,
            onPressed: () => _write(
              'Secure Storage',
              StorageService.writeSecure,
            ),
          ),
          const SizedBox(height: 8),
          _ActionTile(
            color: const Color(0xFFB67420),
            title: 'Cache',
            subtitle: 'Files — view/delete only, never edited',
            enabled: true,
            onPressed: () => _write('Cache', StorageService.writeCache),
          ),
          const SizedBox(height: 8),
          Text(
            _status,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.color,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onPressed,
  });

  final Color color;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.16),
          child: Icon(Icons.storage_rounded, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: FilledButton(
          onPressed: enabled ? onPressed : null,
          child: const Text('Write'),
        ),
      ),
    );
  }
}