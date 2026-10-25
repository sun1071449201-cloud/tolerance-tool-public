/// 输入无法解析（公差代号格式错误等）。
class ParseException implements Exception {
  const ParseException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 查询的数值未包含在当前占位数据集中（不允许编造标准值，只允许明确提示缺失）。
class DataNotSeedException implements Exception {
  const DataNotSeedException(this.message);
  final String message;

  @override
  String toString() => message;
}
