import 'package:flutter/material.dart';

/// 全局 Material 3 主题：统一配色、卡片圆角/阴影/边距、字阶与页面过渡动画。
/// 支持多色板：工业蓝（默认）、翡翠绿、深空紫、琥珀橙。
class AppTheme {
  static const _seeds = <String, Color>{
    'industrial': Color(0xFF00639B),
    'emerald': Color(0xFF00875A),
    'violet': Color(0xFF6750A4),
    'amber': Color(0xFFB45309),
  };

  static const seedNames = {
    'industrial': '工业蓝',
    'emerald': '翡翠绿',
    'violet': '深空紫',
    'amber': '琥珀橙',
  };

  static Color seedOf(String name) => _seeds[name] ?? _seeds['industrial']!;
  static Color seed = _seeds['industrial']!;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // 页面切换平滑过渡（Android 用缩放淡入）。
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      // 卡片统一：14 圆角、低阴影、留白舒适。
      cardTheme: CardTheme(
        elevation: isDark ? 1.0 : 1.5,
        shadowColor: scheme.shadow.withOpacity(0.20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      ),
      // 字阶：标题层级清晰，正文舒展。
      textTheme: Typography.blackMountainView.copyWith(
        displaySmall: const TextStyle(
            fontSize: 34, fontWeight: FontWeight.w700, height: 1.25),
        headlineSmall: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w700, height: 1.3),
        titleLarge: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w600, height: 1.35),
        titleMedium: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
        titleSmall: const TextStyle(
            fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.4),
        bodyLarge: const TextStyle(fontSize: 15.5, height: 1.6),
        bodyMedium: const TextStyle(fontSize: 14, height: 1.5),
        bodySmall: const TextStyle(fontSize: 12, height: 1.45),
        labelLarge: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
        labelMedium: const TextStyle(fontSize: 11.5, height: 1.3),
        labelSmall: const TextStyle(fontSize: 10.5, height: 1.25),
      ).apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withOpacity(0.7),
        thickness: 1,
        space: 20,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant.withOpacity(0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
