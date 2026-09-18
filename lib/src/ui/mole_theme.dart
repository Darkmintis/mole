import 'package:flutter/material.dart';

/// Host-app-independent theme for Mole UI.
///
/// Always builds a fresh Material 3 [ThemeData] so host apps that set custom
/// fonts (Google Fonts, etc.) do not restyle the inspector.
abstract final class MoleTheme {
  /// Deep teal for light mode.
  static const Color seed = Color(0xFF0F6B7A);

  /// Brighter teal for dark mode.
  static const Color teal = Color(0xFF5EC8D8);

  static ThemeData of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scheme = ColorScheme.fromSeed(
      seedColor: brightness == Brightness.dark ? teal : seed,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: scheme.primary,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
        thickness: 1,
      ),
    );
  }

  /// Wraps Mole UI in an isolated theme.
  ///
  /// Pass a [builder] so `Theme.of(context)` inside resolves to Mole, not
  /// the host app's fonts.
  static Widget wrap(BuildContext context, WidgetBuilder builder) {
    final theme = of(context);
    return Theme(
      data: theme,
      child: Builder(builder: builder),
    );
  }
}
