import 'package:flutter/material.dart';

/// Host-app-independent theme for Mole UI.
///
/// Always builds a fresh Material 3 [ThemeData] so host apps that set custom
/// fonts (Google Fonts, etc.) do not restyle the inspector.
abstract final class MoleTheme {
  static const Color seed = Color(0xFF1B6B4A);
  static const Color mint = Color(0xFF3DDC97);

  static ThemeData of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scheme = ColorScheme.fromSeed(
      seedColor: brightness == Brightness.dark ? mint : seed,
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
