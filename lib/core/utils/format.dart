/// 偏差与公差统一以微米（μm）整数存储；显示换算为毫米并保留 3 位小数。
/// 带符号（正值加 +，零显示 0.000）。
String formatUmSigned(int um) {
  if (um == 0) return '0.000';
  final sign = um > 0 ? '+' : '-';
  return '$sign${(um.abs() / 1000).toStringAsFixed(3)}';
}

/// 绝对值毫米显示（过盈量按正值表述，如“最大过盈 0.042”）。
String formatUmMagnitude(int um) => (um.abs() / 1000).toStringAsFixed(3);

String formatMm(double v) => v.toStringAsFixed(2);
