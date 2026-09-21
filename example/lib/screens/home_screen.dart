import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/storage_service.dart';

/// One single form-based demo screen that exercises all 4 registered sources.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.prefs,
    this.box,
    this.storageRevision,
  });

  final SharedPreferences? prefs;
  final Box? box;
  final ValueNotifier<int>? storageRevision;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SharedPreferences? _prefs;
  Box? _box;

  final _nameController = TextEditingController();
  bool _darkMode = false;
  bool _notifications = false;

  String? _prefsNotice;
  String? _secureNotice;
  String? _hiveNotice;
  String? _cacheNotice;

  bool _busy = false;

  bool get _prefsReady => _prefs != null;
  bool get _hiveReady => _box != null;

  @override
  void initState() {
    super.initState();
    widget.storageRevision?.addListener(_onMoleStorageChanged);
    _init();
  }

  @override
  void dispose() {
    widget.storageRevision?.removeListener(_onMoleStorageChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onMoleStorageChanged() {
    if (!mounted) return;
    if (_prefs != null) {
      _loadIntoForm();
      _prefsNotice =
          'Updated from Mole - form reloaded from SharedPreferences.';
    }
    _secureNotice =
        'Updated from Mole - check auth_token in Secure Storage.';
    _hiveNotice = 'Updated from Mole - check profile keys in Hive.';
    _cacheNotice = 'Updated from Mole - rescan Cache in the inspector.';
    setState(() {});
  }

  Future<void> _init() async {
    // Load prefs first so the form can prefill without waiting on Hive /
    // path_provider (which may be slow or unavailable in widget tests).
    final prefs = widget.prefs ?? await _resolvePrefs();
    if (!mounted) return;
    if (prefs != null) {
      setState(() {
        _prefs = prefs;
      });
      _loadIntoForm();
      if (mounted) setState(() {});
    }

    final box = widget.box ?? await _resolveBox();
    if (!mounted) return;
    setState(() {
      _box = box;
    });
  }

  Future<SharedPreferences?> _resolvePrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } on Object {
      return null;
    }
  }

  Future<Box?> _resolveBox() async {
    try {
      return await StorageService.openBox();
    } on Object {
      return null;
    }
  }

  void _loadIntoForm() {
    if (_prefs == null) return;
    final current = StorageService.currentPrefs(_prefs!);
    _nameController.text = StorageService.readString(current['name']);
    _darkMode = StorageService.readBool(current['dark_mode']);
    _notifications = StorageService.readBool(current['notifications']);
  }

  Future<void> _runSection({
    required String label,
    required Future<void> Function() action,
    required void Function(String message) setNotice,
    required String successMessage,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      setState(() => setNotice(successMessage));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => setNotice('$label failed: $e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePrefs() => _runSection(
        label: 'Save preferences',
        action: () => StorageService.savePrefs(
          _prefs!,
          name: _nameController.text.trim(),
          darkMode: _darkMode,
          notifications: _notifications,
        ),
        setNotice: (message) => _prefsNotice = message,
        successMessage:
            'SharedPreferences saved (name, dark_mode, notifications). '
            'Open Mole to inspect.',
      );

  Future<void> _login() => _runSection(
        label: 'Login',
        action: StorageService.login,
        setNotice: (message) => _secureNotice = message,
        successMessage:
            'auth_token written to Secure Storage. '
            'It is masked in Mole until you tap reveal.',
      );

  Future<void> _saveProfile() => _runSection(
        label: 'Save profile',
        action: () => StorageService.saveProfile(_box!),
        setNotice: (message) => _hiveNotice = message,
        successMessage:
            'Hive profile map + image bytes saved. '
            'Open Mole to browse thumbnails.',
      );

  Future<void> _saveCache() => _runSection(
        label: 'Cache image',
        action: StorageService.writeCache,
        setNotice: (message) => _cacheNotice = message,
        successMessage:
            'profile.png and summary.json written to the app cache dir. '
            'Open Mole Cache source to view them.',
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mole Demo - Storage Playground'),
        actions: [
          IconButton(
            tooltip: 'Reload from storage',
            onPressed: _prefsReady
                ? () {
                    _loadIntoForm();
                    setState(() {
                      _prefsNotice =
                          'Reloaded from SharedPreferences.';
                    });
                  }
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
            color: const Color(0xFF0F6B7A),
            child: Column(
              children: [
                _label(context, 'Name'),
                TextField(
                  controller: _nameController,
                  enabled: _prefsReady && !_busy,
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
                  onChanged: _prefsReady && !_busy
                      ? (v) => setState(() => _darkMode = v)
                      : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Notifications'),
                  value: _notifications,
                  onChanged: _prefsReady && !_busy
                      ? (v) => setState(() => _notifications = v)
                      : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: _button(
                    label: 'Save',
                    icon: Icons.save_outlined,
                    onPressed: _prefsReady && !_busy ? _savePrefs : null,
                  ),
                ),
              ],
            ),
          ),
          _SectionNotice(message: _prefsNotice),
          const SizedBox(height: 8),
          _SectionCard(
            title: 'Secure Storage',
            icon: Icons.lock_outline_rounded,
            color: const Color(0xFF6A1B9A),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(
                  context,
                  'Writes a fake auth_token - masked/tap-to-reveal in Mole.',
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: _button(
                    label: 'Login',
                    icon: Icons.login_rounded,
                    onPressed: !_busy ? _login : null,
                  ),
                ),
              ],
            ),
          ),
          _SectionNotice(message: _secureNotice),
          const SizedBox(height: 8),
          _SectionCard(
            title: 'Hive',
            icon: Icons.storage_rounded,
            color: const Color(0xFF1565C0),
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
                    label: 'Save Profile',
                    icon: Icons.person_outline_rounded,
                    onPressed: _hiveReady && !_busy ? _saveProfile : null,
                  ),
                ),
              ],
            ),
          ),
          _SectionNotice(message: _hiveNotice),
          const SizedBox(height: 8),
          _SectionCard(
            title: 'Cache',
            icon: Icons.folder_open_rounded,
            color: const Color(0xFFB67420),
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
                    label: 'Cache image',
                    icon: Icons.cloud_download_outlined,
                    onPressed: !_busy ? _saveCache : null,
                  ),
                ),
              ],
            ),
          ),
          _SectionNotice(message: _cacheNotice),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
      ),
    );
  }

  Widget _button({
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
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color color;
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

class _SectionNotice extends StatelessWidget {
  const _SectionNotice({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
      child: Text(
        message!,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
