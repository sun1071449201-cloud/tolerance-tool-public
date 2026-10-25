import '../../core/errors/exceptions.dart';
import '../models/tolerance_models.dart';

/// 解析 “⌀50 H7/g6” / “50H7/g6” / “φ50 H7” 等输入。
/// 约定：大写代号 = 孔（H、JS…），小写代号 = 轴（g、js…）。
class DesignationParser {
  DesignationParser._();

  static final RegExp _pattern = RegExp(
    r'^[⌀φΦØø]?[dD]?\s*(\d+(?:\.\d+)?)?\s*([A-Za-z]{1,2})(\d{1,2})\s*(?:/\s*([A-Za-z]{1,2})(\d{1,2}))?$',
  );

  static const holeLetters = {
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'JS', 'K', 'M', 'N', 'P',
    'R', 'S', 'T', 'U', 'V', 'X', 'Y', 'Z', 'ZA', 'ZB', 'ZC',
  };

  static const shaftLetters = {
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'js', 'k', 'm', 'n', 'p',
    'r', 's', 't', 'u', 'v', 'x', 'y', 'z', 'za', 'zb', 'zc',
  };

  static ToleranceDesignation parse(String raw) {
    final m = _pattern.firstMatch(raw.trim());
    if (m == null) {
      throw ParseException('无法识别“$raw”。示例：⌀50 H7/g6、50H7、φ30 H7/k6');
    }

    final sizeStr = m.group(1);
    if (sizeStr == null) {
      throw const ParseException('未识别到基本尺寸，请连同尺寸一起输入，例如 ⌀50 H7/g6');
    }
    final size = double.tryParse(sizeStr);
    if (size == null || size <= 0 || size > 500) {
      throw const ParseException('基本尺寸须大于 0 且不超过 500 mm（当前占位数据集范围）');
    }

    final first = _zone(m.group(2)!, m.group(3)!);
    ZoneCode? second;
    if (m.group(4) != null) {
      second = _zone(m.group(4)!, m.group(5)!);
    }

    // 必须有孔（大写）公差带；轴（小写）可选。
    if (first.isHole) {
      if (second != null && second.isHole) {
        throw const ParseException('两段公差带须一孔一轴（大写/小写），例如 H7/g6');
      }
      return ToleranceDesignation(nominalSize: size, hole: first, shaft: second);
    }
    throw const ParseException('请以大写字母输入孔公差带（如 H7），轴公差带用小写（如 g6）');
  }

  static ZoneCode _zone(String letters, String gradeStr) {
    final grade = int.parse(gradeStr);
    if (grade > 18) {
      throw ParseException('公差等级 $gradeStr 超出 IT0~IT18 范围');
    }
    if (holeLetters.contains(letters)) {
      return ZoneCode(letter: letters, grade: grade, isHole: true);
    }
    if (shaftLetters.contains(letters)) {
      return ZoneCode(letter: letters, grade: grade, isHole: false);
    }
    throw ParseException('偏差代号“$letters”无效（孔用大写如 H/JS/K，轴用小写如 g/js/k）');
  }
}
