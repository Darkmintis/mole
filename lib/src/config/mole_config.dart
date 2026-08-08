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

  const MoleConfig({
    this.enabled = true,
    this.enableInRelease = false,
    this.showReleaseWarning = true,
    this.startMinimized = true,
    this.refreshDebounce = const Duration(milliseconds: 200),
  });

  MoleConfig copyWith({
    bool? enabled,
    bool? enableInRelease,
    bool? showReleaseWarning,
    bool? startMinimized,
    Duration? refreshDebounce,
  }) {
    return MoleConfig(
      enabled: enabled ?? this.enabled,
      enableInRelease: enableInRelease ?? this.enableInRelease,
      showReleaseWarning: showReleaseWarning ?? this.showReleaseWarning,
      startMinimized: startMinimized ?? this.startMinimized,
      refreshDebounce: refreshDebounce ?? this.refreshDebounce,
    );
  }

  @override
  String toString() {
    return 'MoleConfig('
        'enabled: $enabled, '
        'enableInRelease: $enableInRelease, '
        'showReleaseWarning: $showReleaseWarning, '
        'startMinimized: $startMinimized, '
        'refreshDebounce: $refreshDebounce'
        ')';
  }
}
