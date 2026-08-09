/// Configuration for [Mole.install].
///
/// Defaults are safe for day-one install: on in debug/profile, off in release
/// unless [enableInRelease] is explicitly set.
///
/// When Mole is active in a release build, the console banner and red
/// on-screen tag are **always** shown and cannot be disabled.
class MoleConfig {
  /// Master switch. When `false`, Mole is a no-op even in debug.
  final bool enabled;

  /// Explicit opt-in to run in release builds. Default `false`.
  ///
  /// When `true`, Mole always prints a loud console warning and shows a
  /// permanent red "MOLE ACTIVE" tag. That warning cannot be turned off.
  final bool enableInRelease;

  /// Whether the release-mode on-screen tag is shown.
  ///
  /// Always `true` when [enableInRelease] is set — never configurable down.
  final bool showReleaseWarning;

  /// Floating bubble starts minimized.
  final bool startMinimized;

  /// Minimum gap between UI refreshes while a source is being written to
  /// rapidly. Prevents rebuilding on every single write in a tight loop.
  final Duration refreshDebounce;

  /// Total cache size (across all [MoleCacheSource] directories) in MB that,
  /// when exceeded, shows a small red warning dot on the floating bubble.
  ///
  /// See plan §3b: the red dot is a **useful signal**, not decoration — Mole's
  /// bubble never shows a persistent count. Default: `50`.
  final int cacheSizeWarningThresholdMB;

  const MoleConfig({
    this.enabled = true,
    this.enableInRelease = false,
    this.showReleaseWarning = true,
    this.startMinimized = true,
    this.refreshDebounce = const Duration(milliseconds: 200),
    this.cacheSizeWarningThresholdMB = 50,
  });

  MoleConfig copyWith({
    bool? enabled,
    bool? enableInRelease,
    bool? showReleaseWarning,
    bool? startMinimized,
    Duration? refreshDebounce,
    int? cacheSizeWarningThresholdMB,
  }) {
    return MoleConfig(
      enabled: enabled ?? this.enabled,
      enableInRelease: enableInRelease ?? this.enableInRelease,
      showReleaseWarning: showReleaseWarning ?? this.showReleaseWarning,
      startMinimized: startMinimized ?? this.startMinimized,
      refreshDebounce: refreshDebounce ?? this.refreshDebounce,
      cacheSizeWarningThresholdMB:
          cacheSizeWarningThresholdMB ?? this.cacheSizeWarningThresholdMB,
    );
  }

  @override
  String toString() {
    return 'MoleConfig('
        'enabled: $enabled, '
        'enableInRelease: $enableInRelease, '
        'showReleaseWarning: $showReleaseWarning, '
        'startMinimized: $startMinimized, '
        'refreshDebounce: $refreshDebounce, '
        'cacheSizeWarningThresholdMB: $cacheSizeWarningThresholdMB'
        ')';
  }
}
