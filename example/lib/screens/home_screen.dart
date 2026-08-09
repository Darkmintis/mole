import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/storage_service.dart';

/// One single form-based demo screen that exercises all 4 registered sources.
///
/// This is the proof Mole is a *live window into storage*, not a snapshot.
/// Documented two-way test flow (see §10b of MOLE_PLAN.md):
///
/// 1. Fill the form, tap each Save/Login/Cache button → open the Mole bubble →
///    confirm all 4 sources show the new data.
/// 2. In Mole, edit one SharedPreferences value directly → return here and tap
///    **Reload from storage** (or restart the app) → the fields must show the
///    edited value. This proves Mole writes through to real storage.
/// 3. Repeat the edit check for the Hive entry (a non-binary field like
///    `profile.name`) and confirm it also writes through.
/// 4. Delete a key from Mole (in each of Prefs, Secure Storage, Hive) →
///    confirm the app reflects the default/empty state on next read.
/// 5. Delete the cached image file from Mole → confirm it's gone from disk /
///    the app re-downloads it if reloaded.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.prefs,
    this.box,
  });

  /// Provide the already-registered instances so edits in Mole echo back.
  /// When null (widget tests), the screen resolves its own instances.
  final SharedPreferences? prefs;
  final Box? box;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SharedPreferences? _prefs;
  Box? _box;

  final _nameController = TextEditingController();
  bool _darkMode = false;
  bool _notifications = false;

  String _status = 'Fill the form, save, then open the Mole bubble';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = widget.prefs ?? await _resolvePrefs();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _loadIntoForm();
    });
    // Box resolution is optional; it may not exist in widget tests.
    final box = widget.box ?? await _resolveBox();
    if (!mounted || box == null) return;
    setState(() => _box = box);
  }

  /// Tests use `SharedPreferences.setMockInitialValues`; resolve if not passed.
  Future<SharedPreferences?> _resolvePrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } on Object {
      return null;
    }
  }

  /// Opens the demo Hive box. Fails silently when plugins are unavailable
  /// (e.g. widget tests) — the demo screen then just can't write to Hive.
  Future<Box?> _resolveBox() async {
    try {
      return await StorageService.openBox();
    } on Object {
      return null;
    }
  }

  /// Re-reads current storage values into the form controls — this is what
  /// proves Mole's edits/deletes "write through" to the app (§10b steps 2-5).
  void _loadIntoForm() {
    final current = _prefs == null
        ? const <String, Object?>{}
        : StorageService.currentPrefs(_prefs!);
    _nameController.text = (current['name'] as String?) ?? '';
    _darkMode = (current['dark_mode'] as bool?) ?? false;
    _notifications = (current['notifications'] as bool?) ?? false;
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = '$label…';
    });
    try {
      await action();
      if (!mounted) return;
      setState(() => _status = '$label done — open the Mole bubble to inspect.');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _status = '$label failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePrefs() => _run(
    'Saving preferences',
    () => StorageService.savePrefs(
      _prefs!,
      name: _nameController.text.trim(),
      darkMode: _darkMode,
      notifications: _notifications,
    ),
  );

  Future<void> _login() =>
      _run('Logging in', () => StorageService.login());

  Future<void> _saveProfile() => _run(
    'Saving profile',
    () => StorageService.saveProfile(_box!),
  );

  Future<void> _saveCache() =>
      _run('caching sample image', () => StorageService.writeCache());

  @override
  Widget build(BuildContext context) {
    final ready = _prefs != null && _box != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Mole Demo — Storage Playground'),
        actions: [
          IconButton(
            tooltip: 'Reload from storage',
            onPressed: ready
                ? () => setState(() {
                      _loadIntoForm();
                      _status =
                          'Reloaded — values now reflect what Mole has stored.';
                    })
                : null,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            'Each section writes to a real storage backend. Open the floating '
            'Mole bubble to inspect, edit, delete, or clear the stored data.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),

          _SectionCard(
            title: 'SharedPreferences',
            icon: Icons.tune_rounded,
            color: const Color(0xFF1B6B4A),
            enabled: ready,
            child: Column(
              children: [
                _label(context, 'Name'),
                TextField(
                  controller: _nameController,
                  enabled: ready,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Mole',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dark mode'),
                  value: _darkMode,
                  onChanged: ready
                      ? (v) => setState(() => _darkMode = v)
                      : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Notifications'),
                  value: _notifications,
                  onChanged: ready
                      ? (v) => setState(() => _notifications = v)
                      : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: _button(
                    context,
                    label: 'Save',
                    icon: Icons.save_outlined,
                    onPressed: ready ? _savePrefs : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _SectionCard(
            title: 'Secure Storage',
            icon: Icons.lock_outline_rounded,
            color: const Color(0xFF6A1B9A),
            enabled: ready,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(
                  context,
                  'Writes a fake auth_token — masked/tap-to-reveal in Mole.',
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: _button(
                    context,
                    label: 'Login',
                    icon: Icons.login_rounded,
                    onPressed: ready ? _login : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _SectionCard(
            title: 'Hive',
            icon: Icons.storage_rounded,
            color: const Color(0xFF1565C0),
            enabled: ready,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(
                  context,
                  'Saves a nested Map profile + raw image bytes '
                  '(proves the thumbnail renderer).',
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: _button(
                    context,
                    label: 'Save Profile',
                    icon: Icons.person_outline_rounded,
                    onPressed: ready ? _saveProfile : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _SectionCard(
            title: 'Cache',
            icon: Icons.folder_open_rounded,
            color: const Color(0xFFB67420),
            enabled: ready,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(
                  context,
                  'Caches the bundled profile.png + a JSON summary into the '
                  'app temp cache dir. Files are view/delete only in Mole.',
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: _button(
                    context,
                    label: 'Cache image',
                    icon: Icons.cloud_download_outlined,
                    onPressed: ready ? _saveCache : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(_status, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text, [String? second]) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          text: text,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          children: [
            if (second != null)
              TextSpan(
                text: second,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _button(
    BuildContext context, {
    required String label,
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color color;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color.withValues(alpha: 0.16),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}