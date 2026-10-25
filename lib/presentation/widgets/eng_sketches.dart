import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import 'mermaid_lite.dart';

/// 书籍/速查中的 ```mermaid``` 与 ```sketch:xxx``` 代码块渲染器：
/// mermaid → MermaidLite 逻辑图；sketch → 工程截面简图（CustomPaint 注册表）。
class DiagramCodeBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent.trim();
    final cls = element.attributes['class'] ?? '';
    if (cls.contains('mermaid') ||
        text.startsWith('graph ') ||
        text.startsWith('flowchart ')) {
      return MermaidLite(source: text);
    }
    // ```sketch:undercut 形式：language-sketch-undercut 或正文首行 sketch:xxx
    final m = RegExp(r'sketch-?(\w+)').firstMatch(cls) ??
        RegExp(r'^sketch:\s*(\w+)').firstMatch(text);
    final name = m?.group(1);
    if (name != null && name.isNotEmpty) {
      final w = EngSketches.byName(name);
      if (w != null) return w;
    }
    return null; // 普通代码块走默认渲染
  }
}

/// 工程简图注册表：按名称返回截面示意图组件。
class EngSketches {
  static Widget? byName(String name) {
    switch (name) {
      case 'undercut':
        return const _SketchCard(
            title: '外圆磨削退刀槽（轴肩处）', painter: _UndercutPainter());
      case 'tapdrill':
        return const _SketchCard(
            title: '螺纹底孔与丝锥（盲孔结构）', painter: _TapDrillPainter());
      case 'dimgap':
        return const _SketchCard(
            title: '尺寸链：A₁ + A₂ − A₃ = N（封闭环）', painter: _DimChainPainter());
      case 'sheetbend':
        return const _SketchCard(
            title: '钣金折弯：中性层与 K 因子', painter: _SheetBendPainter());
      case 'poshole':
        return const _SketchCard(
            title: '孔组位置度：理论位置 ± 偏差 → Øt 圆柱带', painter: _PosHolePainter());
      default:
        return null;
    }
  }
}

class _SketchCard extends StatelessWidget {
  const _SketchCard({required this.title, required this.painter});

  final String title;
  final CustomPainter painter;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            CustomPaint(painter: painter, child: const AspectRatio(aspectRatio: 2.0)),
          ],
        ),
      ),
    );
  }
}

void _label(Canvas c, String t, Offset at, [double size = 10]) {
  TextPainter(
    text: TextSpan(
        text: t,
        style: TextStyle(fontSize: size, color: const Color(0xFF1B3B6F))),
    textDirection: TextDirection.ltr,
  )
    ..layout()
    ..paint(c, at);
}

/// 退刀槽截面：轴 + 砂轮越程槽 + 轴肩。
class _UndercutPainter extends CustomPainter {
  const _UndercutPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cy = h / 2;
    final part = Paint()..color = Colors.blueGrey.shade300;
    final edge = Paint()
      ..color = Colors.blueGrey.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final zone = Paint()..color = const Color(0x333D7EFF);

    // 大直径轴段（左）
    canvas.drawRect(Rect.fromLTRB(6, cy - 22, w * 0.55, cy + 22), part);
    canvas.drawRect(Rect.fromLTRB(6, cy - 22, w * 0.55, cy + 22), edge);
    // 小直径轴段（右）
    canvas.drawRect(Rect.fromLTRB(w * 0.62, cy - 12, w - 6, cy + 12), part);
    canvas.drawRect(Rect.fromLTRB(w * 0.62, cy - 12, w - 6, cy + 12), edge);
    // 轴肩立面
    canvas.drawLine(Offset(w * 0.55, cy - 22), Offset(w * 0.55, cy - 12), edge);
    canvas.drawLine(Offset(w * 0.55, cy + 12), Offset(w * 0.55, cy + 22), edge);
    // 退刀槽（小径凹槽）
    canvas.drawRect(Rect.fromLTRB(w * 0.55, cy - 12, w * 0.62, cy + 12), zone);
    canvas.drawRect(Rect.fromLTRB(w * 0.55, cy - 12, w * 0.62, cy + 12), edge);

    _label(canvas, 'd₁', Offset(8, cy - 36));
    _label(canvas, 'd₂', Offset(w - 30, cy - 26));
    _label(canvas, '退刀槽 b×h', Offset(w * 0.5, cy + 30));
    // 砂轮示意
    canvas.drawCircle(Offset(w * 0.58, cy - 26), 6, edge);
    _label(canvas, '砂轮', Offset(w * 0.58 + 10, cy - 30), 9);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 螺纹底孔：盲孔 + 丝锥 + 底部排屑空间。
class _TapDrillPainter extends CustomPainter {
  const _TapDrillPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final part = Paint()..color = Colors.blueGrey.shade300;
    final edge = Paint()
      ..color = Colors.blueGrey.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final hole = Paint()..color = Colors.white;
    final tap = Paint()
      ..color = const Color(0xFF3D7EFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // 工件
    canvas.drawRect(Rect.fromLTRB(w * 0.3, 6, w * 0.7, h - 6), part);
    canvas.drawRect(Rect.fromLTRB(w * 0.3, 6, w * 0.7, h - 6), edge);
    // 底孔（白色）
    final drillBottom = h * 0.78;
    canvas.drawRect(
        Rect.fromLTRB(w * 0.44, 6, w * 0.56, drillBottom), hole);
    canvas.drawRect(
        Rect.fromLTRB(w * 0.44, 6, w * 0.56, drillBottom), edge);
    // 螺纹段（牙型示意：斜线）
    final threadBottom = h * 0.6;
    var y = 12.0;
    while (y < threadBottom) {
      canvas.drawLine(Offset(w * 0.44, y), Offset(w * 0.56, y + 4), tap);
      y += 8;
    }
    // 丝锥（顶部进入）
    canvas.drawLine(Offset(w * 0.5, 0), Offset(w * 0.5, 20), tap);
    // 排屑空间标注
    _label(canvas, '螺纹深度', Offset(w * 0.58, threadBottom * 0.5), 9);
    _label(canvas, '排屑余量 2~3P', Offset(w * 0.58, drillBottom - 14), 9);
    _label(canvas, '底孔 Ø', Offset(w * 0.16, 16), 10);
    canvas.drawLine(Offset(w * 0.2, 22), Offset(w * 0.44, 30), edge);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 钣金折弯：V 槽 + 板材 + 中性层（K 因子位置）。
class _SheetBendPainter extends CustomPainter {
  const _SheetBendPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final part = Paint()..color = Colors.blueGrey.shade300;
    final edge = Paint()
      ..color = Colors.blueGrey.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final neutral = Paint()
      ..color = const Color(0xFF3D7EFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final die = Paint()
      ..color = Colors.grey.shade500
      ..style = PaintingStyle.fill;

    // 下模 V 槽（三角形）
    final vPath = Path()
      ..moveTo(w * 0.32, h * 0.62)
      ..lineTo(w * 0.5, h * 0.92)
      ..lineTo(w * 0.68, h * 0.62)
      ..close();
    canvas.drawPath(vPath, die);
    // 上模冲头
    canvas.drawRect(
        Rect.fromLTWH(w * 0.47, h * 0.05, w * 0.06, h * 0.4), die);
    // 折弯板材（L 形，内外圆角）
    final t = h * 0.10; // 板厚
    final outer = Path()
      ..moveTo(w * 0.08, h * 0.62)
      ..lineTo(w * 0.48, h * 0.62)
      ..arcToPoint(Offset(w * 0.62, h * 0.48),
          radius: Radius.circular(t + 4), clockwise: false)
      ..lineTo(w * 0.62, h * 0.12)
      ..lineTo(w * 0.62 - t, h * 0.12)
      ..lineTo(w * 0.62 - t, h * 0.48)
      ..arcToPoint(Offset(w * 0.48, h * 0.62 - t),
          radius: const Radius.circular(4), clockwise: false)
      ..lineTo(w * 0.08, h * 0.62 - t)
      ..close();
    canvas.drawPath(outer, part);
    canvas.drawPath(outer, edge);
    // 中性层（K 因子所在）
    final nl = Path()
      ..moveTo(w * 0.08, h * 0.62 - t / 2)
      ..lineTo(w * 0.49, h * 0.62 - t / 2)
      ..arcToPoint(Offset(w * 0.62 - t / 2, h * 0.49),
          radius: Radius.circular(t / 2 + 2), clockwise: false)
      ..lineTo(w * 0.62 - t / 2, h * 0.12);
    canvas.drawPath(nl, neutral);
    _label(canvas, '中性层（K·t）', Offset(w * 0.08, h * 0.62 - t - 12), 9);
    _label(canvas, '板厚 t', Offset(w * 0.66, h * 0.3), 9);
    _label(canvas, '内 R ≥ t', Offset(w * 0.5, h - 14), 9);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 孔组位置度：基准系 + 理论位置（十字）+ 实际孔 + Øt 圆柱带。
class _PosHolePainter extends CustomPainter {
  const _PosHolePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final plate = Paint()..color = Colors.blueGrey.shade300;
    final edge = Paint()
      ..color = Colors.blueGrey.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final zone = Paint()
      ..color = const Color(0xFF3D7EFF).withOpacity(0.22);
    final zoneEdge = Paint()
      ..color = const Color(0xFF3D7EFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final cross = Paint()
      ..color = Colors.grey.shade700
      ..strokeWidth = 1.0;
    final datum = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 2.0;

    // 板
    canvas.drawRect(Rect.fromLTRB(w * 0.12, 6, w - 6, h - 14), plate);
    canvas.drawRect(Rect.fromLTRB(w * 0.12, 6, w - 6, h - 14), edge);
    // 基准 A（底边）/B（左边）
    canvas.drawLine(Offset(w * 0.12, h - 8), Offset(w - 6, h - 8), datum);
    canvas.drawLine(Offset(w * 0.06, 6), Offset(w * 0.06, h - 14), datum);
    _label(canvas, 'A', Offset(w - 16, h - 24));
    _label(canvas, 'B', Offset(w * 0.02, 4));

    // 4 孔网格
    final cols = [w * 0.32, w * 0.68];
    final rows = [h * 0.3, h * 0.66];
    for (final x in cols) {
      for (final y in rows) {
        // 理论位置十字
        canvas.drawLine(Offset(x - 6, y), Offset(x + 6, y), cross);
        canvas.drawLine(Offset(x, y - 6), Offset(x, y + 6), cross);
        // 公差带圆 Øt
        canvas.drawCircle(Offset(x, y), 13, zone);
        canvas.drawCircle(Offset(x, y), 13, zoneEdge);
        // 实际孔（偏置示例，仅一处偏）
        final dx = (x == w * 0.68 && y == h * 0.3) ? 5.0 : 0.0;
        final dy = (x == w * 0.68 && y == h * 0.3) ? -4.0 : 0.0;
        canvas.drawCircle(Offset(x + dx, y + dy), 5, zoneEdge);
      }
    }
    _label(canvas, '实际孔（带偏差）', Offset(w * 0.7, h * 0.12), 9);
    _label(canvas, 'Øt 圆柱带', Offset(w * 0.2, h * 0.8), 9);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 尺寸链：三组成环 + 封闭环标注。
class _DimChainPainter extends CustomPainter {
  const _DimChainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final y = h * 0.42;
    final arrow = Paint()
      ..color = const Color(0xFF1B3B6F)
      ..strokeWidth = 1.4;

    void dimLine(double x1, double x2, double yy, String label) {
      canvas.drawLine(Offset(x1, yy), Offset(x2, yy), arrow);
      canvas.drawLine(Offset(x1, yy - 5), Offset(x1, yy + 5), arrow);
      canvas.drawLine(Offset(x2, yy - 5), Offset(x2, yy + 5), arrow);
      _label(canvas, label, Offset((x1 + x2) / 2 - 14, yy - 18));
    }

    // 轮廓（简化台阶轴侧视）
    final part = Paint()..color = Colors.blueGrey.shade300;
    final edge = Paint()
      ..color = Colors.blueGrey.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRect(Rect.fromLTRB(10, y - 16, w * 0.4, y + 16), part);
    canvas.drawRect(Rect.fromLTRB(w * 0.4, y - 10, w - 10, y + 10), part);
    canvas.drawRect(Rect.fromLTRB(10, y - 16, w * 0.4, y + 16), edge);
    canvas.drawRect(Rect.fromLTRB(w * 0.4, y - 10, w - 10, y + 10), edge);

    dimLine(10, w * 0.4, h * 0.75, 'A₁');
    dimLine(w * 0.4, w - 10, h * 0.75, 'A₂');
    dimLine(10, w - 10, h * 0.18, 'N（封闭环）');
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}