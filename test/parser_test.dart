import 'package:flutter_test/flutter_test.dart';
import 'package:tolerance_tool/core/errors/exceptions.dart';
import 'package:tolerance_tool/domain/parsing/designation_parser.dart';

void main() {
  group('DesignationParser', () {
    test('解析 ⌀50 H7/g6', () {
      final d = DesignationParser.parse('⌀50 H7/g6');
      expect(d.nominalSize, 50);
      expect(d.hole.letter, 'H');
      expect(d.hole.grade, 7);
      expect(d.hole.isHole, isTrue);
      expect(d.shaft!.letter, 'g');
      expect(d.shaft!.grade, 6);
      expect(d.shaft!.isHole, isFalse);
      expect(d.display, '⌀50 H7/g6');
    });

    test('宽容匹配：无符号 50 H7/g6', () {
      final d = DesignationParser.parse('50 H7/g6');
      expect(d.nominalSize, 50);
      expect(d.hole.code, 'H7');
      expect(d.shaft!.code, 'g6');
    });

    test('宽容匹配：d50 H7/g6 与 D50 H7/g6', () {
      for (final input in ['d50 H7/g6', 'D50 H7/g6', 'd50H7/g6']) {
        final d = DesignationParser.parse(input);
        expect(d.nominalSize, 50, reason: input);
        expect(d.hole.code, 'H7', reason: input);
        expect(d.shaft!.code, 'g6', reason: input);
      }
    });

    test('宽容匹配：无符号 50 H7/g6 已在上方覆盖', () {
      final d = DesignationParser.parse('50 H7/g6');
      expect(d.hole.code, 'H7');
    });

    test('宽容匹配：⌀ 符号可省略的仅孔查询 50H7', () {
      final d = DesignationParser.parse('50H7');
      expect(d.hole.code, 'H7');
      expect(d.shaft, isNull);
    });

    test('解析 50H7/g6（无空格）', () {
      final d = DesignationParser.parse('50H7/g6');
      expect(d.nominalSize, 50);
      expect(d.hole.code, 'H7');
      expect(d.shaft!.code, 'g6');
    });

    test('解析 φ30 H7/k6（φ 前缀）', () {
      final d = DesignationParser.parse('φ30 H7/k6');
      expect(d.nominalSize, 30);
      expect(d.hole.code, 'H7');
      expect(d.shaft!.code, 'k6');
    });

    test('解析 50 H7（仅孔）', () {
      final d = DesignationParser.parse('50 H7');
      expect(d.hole.code, 'H7');
      expect(d.shaft, isNull);
    });

    test('解析 ⌀18 JS9（两字母孔代号）', () {
      final d = DesignationParser.parse('⌀18 JS9');
      expect(d.hole.letter, 'JS');
      expect(d.hole.grade, 9);
    });

    test('缺少基本尺寸时报错', () {
      expect(() => DesignationParser.parse('H7/g6'), throwsA(isA<ParseException>()));
    });

    test('无效代号报错', () {
      expect(() => DesignationParser.parse('50 Q7/g6'), throwsA(isA<ParseException>()));
    });

    test('等级超界报错', () {
      expect(() => DesignationParser.parse('50 H19/g6'), throwsA(isA<ParseException>()));
    });

    test('尺寸超界报错', () {
      expect(() => DesignationParser.parse('⌀600 H7/g6'), throwsA(isA<ParseException>()));
    });

    test('两段均为孔代号报错', () {
      expect(() => DesignationParser.parse('50 H7/G6'), throwsA(isA<ParseException>()));
    });
  });
}
