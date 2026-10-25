import 'package:flutter/material.dart';

/// GD&T 形位公差图形化面板：14 种几何特征的公差带形状示意图（CustomPaint 手绘）。
class GdntPanelPage extends StatelessWidget {
  const GdntPanelPage({super.key});

  static const _items = [
    ('直线度', ZoneKind.twoParallelLines, '两平行直线（给定平面内）', false, '刀口尺透光、二次元轮廓线'),
    ('平面度', ZoneKind.twoParallelPlanes, '两平行平面之间的区域', false, '平台打表、三次元网格点'),
    ('圆度', ZoneKind.twoConcentricCircles, '同一截面上两同心圆之间的区域', false, '圆度仪、三次元多点拟合'),
    ('圆柱度', ZoneKind.twoCoaxialCylinders, '两同轴圆柱面之间的区域', false, '圆度仪、三次元'),
    ('平行度', ZoneKind.parallelPlanes, '相对基准平行的两平行平面', true, '平台打表、三次元'),
    ('垂直度', ZoneKind.perpendicularPlanes, '相对基准垂直的两平行平面', true, '直角尺塞尺、三次元'),
    ('倾斜度', ZoneKind.angledPlanes, '相对基准成理论角度的两平行平面', true, '正弦规、三次元'),
    ('位置度', ZoneKind.cylindricalZone, '以理论位置为中心的圆柱形区域', false, '二次元坐标换算、三次元'),
    ('同轴度', ZoneKind.coaxialCylinders, '与基准轴线同轴的圆柱形区域', true, '三次元、V 块打表（近似）'),
    ('对称度', ZoneKind.symmetricPlanes, '相对基准中心面对称的两平行平面', true, '三次元'),
    ('圆跳动', ZoneKind.circumferentialRing, '单截面上两同心圆间的环形区域', true, 'V 块+百分表旋转一圈'),
    ('全跳动', ZoneKind.cylindricalSurface, '整个表面的两同轴圆柱间区域', true, 'V 块打表轴向移动'),
    ('线轮廓度', ZoneKind.uniformCurves, '包络两等距曲线之间的区域', false, '投影仪、三次元扫描'),
    ('面轮廓度', ZoneKind.uniformSurfaces, '包络两等距曲面之间的区域', false, '三次元扫描'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GD&T 公差带图解（14 项）')),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final (name, kind, desc, needsDatum, howTo) = _items[i];
          return _ZoneCard(
            name: name,
            kind: kind,
            desc: desc,
            needsDatum: needsDatum,
            howTo: howTo,
          );
        },
      ),
    );
  }
}

enum ZoneKind {
  twoParallelLines,
  twoParallelPlanes,
  twoConcentricCircles,
  twoCoaxialCylinders,
  parallelPlanes,
  perpendicularPlanes,
  angledPlanes,
  cylindricalZone,
  coaxialCylinders,
  symmetricPlanes,
  circumferentialRing,
  cylindricalSurface,
  uniformCurves,
  uniformSurfaces,
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({
    required this.name,
    required this.kind,
    required this.desc,
    required this.needsDatum,
    required this.howTo,
  });

  final String name;
  final ZoneKind kind;
  final String desc;
  final bool needsDatum;
  final String howTo;

  void _openDetail(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(name,
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Icon(
                    needsDatum ? Icons.anchor : Icons.circle_outlined,
                    size: 16,
                    color: needsDatum ? scheme.primary : scheme.outline,
                  ),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              SizedBox(
                height: 240,
                width: double.infinity,
                child: CustomPaint(painter: _ZonePainter(kind: kind)),
              ),
              const SizedBox(height: 8),
              Text(desc, style: Theme.of(ctx).textTheme.bodyMedium),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.straighten, size: 14, color: scheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('常用检测：$howTo',
                        style: Theme.of(ctx).textTheme.bodySmall),
                  ),
                ],
              ),
              if (needsDatum)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('锚形图标 = 需要基准',
                      style: Theme.of(ctx).textTheme.labelSmall),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  Icon(
                    needsDatum ? Icons.anchor : Icons.circle_outlined,
                    size: 13,
                    color: needsDatum ? scheme.primary : scheme.outline,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: CustomPaint(
                  painter: _ZonePainter(kind: kind),
                  size: Size.infinite,
                ),
              ),
              const SizedBox(height: 4),
              Text(desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 公差带示意图画笔：以简洁线条表达 14 种公差带形状。
/// v2：在关键项叠加“零件轮廓 + 半透明公差带”组合剖视图（用户要求的直观呈现）。
class _ZonePainter extends CustomPainter {
  _ZonePainter({required this.kind});

  final ZoneKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    final zone = Paint()
      ..color = const Color(0xFF3D7EFF).withOpacity(0.18)
      ..style = PaintingStyle.fill;
    final zoneStrong = Paint()
      ..color = const Color(0xFF3D7EFF).withOpacity(0.30)
      ..style = PaintingStyle.fill;
    final line = Paint()
      ..color = const Color(0xFF3D7EFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final part = Paint()
      ..color = Colors.blueGrey.shade300
      ..style = PaintingStyle.fill;
    final partEdge = Paint()
      ..color = Colors.blueGrey.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final datum = Paint()
      ..color = Colors.grey.shade600
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.square;
    final dash = Paint()
      ..color = Colors.grey.shade500
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    void dashedH(double y, double x1, double x2) {
      var x = x1;
      while (x < x2) {
        canvas.drawLine(Offset(x, y), Offset(x + 5, y), dash);
        x += 9;
      }
    }

    void dashedV(double x, double y1, double y2) {
      var y = y1;
      while (y < y2) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 5), dash);
        y += 9;
      }
    }

    void label(String t, Offset at) {
      final tp = TextPainter(
        text: TextSpan(
            text: t,
            style: const TextStyle(
                fontSize: 9, color: Color(0xFF1B3B6F))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at);
    }

    switch (kind) {
      case ZoneKind.twoParallelLines:
        canvas.drawRect(Rect.fromLTRB(6, cy - 10, w - 6, cy + 10), zone);
        canvas.drawLine(const Offset(6, 0), Offset(w - 6, 0), line);
        canvas.drawLine(Offset(6, h), Offset(w - 6, h), line);
      case ZoneKind.twoParallelPlanes:
        // 零件（矩形板）+ 半透明公差带夹在两平行平面之间
        canvas.drawRect(Rect.fromLTRB(10, cy - 8, w - 14, cy + 12), part);
        canvas.drawRect(Rect.fromLTRB(10, cy - 8, w - 14, cy + 12), partEdge);
        canvas.drawRect(Rect.fromLTRB(6, cy - 20, w - 6, cy + 24), zone);
        canvas.drawRect(Rect.fromLTRB(6, cy - 20, w - 6, cy + 24), line);
        label('公差带 t', Offset(cx - 22, cy - 32));
      case ZoneKind.twoConcentricCircles:
        canvas.drawCircle(Offset(cx, cy), h * 0.36, zone);
        canvas.drawCircle(Offset(cx, cy), h * 0.36, line);
        canvas.drawCircle(Offset(cx, cy), h * 0.2, line);
      case ZoneKind.twoCoaxialCylinders:
        // 轴（实体）+ 半透明同轴圆柱公差带包络
        canvas.drawRect(Rect.fromLTRB(6, cy - 14, w - 6, cy + 14), zone);
        canvas.drawRect(Rect.fromLTRB(6, cy - 14, w - 6, cy + 14), line);
        // 零件轴轮廓（蓝色实体感）
        canvas.drawRect(Rect.fromLTRB(12, cy - 9, w - 12, cy + 9), part);
        dashedV(cx - w * 0.22, cy - 14, cy + 14);
        dashedV(cx + w * 0.22, cy - 14, cy + 14);
        canvas.drawOval(Rect.fromCenter(
            center: Offset(cx, cy - 14), width: w * 0.44, height: 10), line);
        canvas.drawOval(Rect.fromCenter(
            center: Offset(cx, cy + 14), width: w * 0.44, height: 10), line);
        label('轴', Offset(cx - 6, cy - 5));
        label('同轴圆柱带 t', Offset(4, cy + 18));
      case ZoneKind.parallelPlanes:
        dashedH(h - 10, 4, w - 4); // 基准 A
        label('A', Offset(w - 18, h - 22));
        // 零件（被测面在上方）
        canvas.drawRect(Rect.fromLTRB(14, cy + 6, w - 6, cy + 16), part);
        canvas.drawRect(Rect.fromLTRB(14, cy + 6, w - 6, cy + 16), partEdge);
        canvas.drawRect(Rect.fromLTRB(6, cy - 20, w - 6, cy - 6), zone);
        canvas.drawRect(Rect.fromLTRB(6, cy - 20, w - 6, cy - 6), line);
        canvas.drawRect(Rect.fromLTRB(6, cy + 2, w - 6, cy + 16), line);
      case ZoneKind.perpendicularPlanes:
        canvas.drawLine(const Offset(10, 6), Offset(10, h - 6), datum);
        label('A', const Offset(2, 2));
        canvas.drawRect(Rect.fromLTRB(14, cy - 20, w - 6, cy - 6), zone);
        canvas.drawRect(Rect.fromLTRB(14, cy - 20, w - 6, cy - 6), line);
        canvas.drawRect(Rect.fromLTRB(14, cy + 2, w - 6, cy + 16), line);
      case ZoneKind.angledPlanes:
        canvas.drawLine(Offset(4, h - 8), Offset(w - 4, h - 8), datum);
        label('A', Offset(w - 18, h - 22));
        final path = Path()
          ..moveTo(10, cy - 18)
          ..lineTo(w - 16, cy - 4)
          ..lineTo(w - 6, cy - 18)
          ..close();
        canvas.drawPath(path, zone);
        canvas.drawPath(path, line);
        canvas.drawLine(Offset(10, cy + 2), Offset(w - 16, cy + 16), line);
        canvas.drawLine(Offset(w - 6, cy + 2), Offset(w - 16, cy + 16), line);
      case ZoneKind.cylindricalZone:
        canvas.drawCircle(Offset(cx, cy), h * 0.36, zone);
        canvas.drawCircle(Offset(cx, cy), h * 0.36, line);
        label('Øt', Offset(cx - 8, cy - 6));
        dashedH(cy, cx - h * 0.36, cx + h * 0.36);
        dashedV(cx, cy - h * 0.36, cy + h * 0.36);
      case ZoneKind.coaxialCylinders:
        // 两段轴 + 半透明同轴带
        canvas.drawRect(Rect.fromLTRB(8, cy - 16, w - 8, cy + 16), zoneStrong);
        canvas.drawRect(Rect.fromLTRB(8, cy - 16, w - 8, cy + 16), line);
        canvas.drawRect(Rect.fromLTRB(12, cy - 11, w * 0.4, cy + 11), part);
        canvas.drawRect(Rect.fromLTRB(12, cy - 11, w * 0.4, cy + 11), partEdge);
        canvas.drawRect(
            Rect.fromLTRB(w * 0.62, cy - 9, w - 12, cy + 9), part);
        canvas.drawRect(
            Rect.fromLTRB(w * 0.62, cy - 9, w - 12, cy + 9), partEdge);
        dashedH(cy, 6, w - 6); // 公共基准轴线
        label('基准轴线', Offset(w * 0.42, cy + 20));
      case ZoneKind.symmetricPlanes:
        dashedV(cx, 6, h - 6); // 基准中心面
        label('A', Offset(cx + 4, 2));
        canvas.drawRect(Rect.fromLTRB(cx - w * 0.32, cy - 14, cx - 4, cy + 14), zone);
        canvas.drawRect(Rect.fromLTRB(cx + 4, cy - 14, cx + w * 0.32, cy + 14), zone);
        canvas.drawRect(Rect.fromLTRB(cx - w * 0.32, cy - 14, cx - 4, cy + 14), line);
        canvas.drawRect(Rect.fromLTRB(cx + 4, cy - 14, cx + w * 0.32, cy + 14), line);
      case ZoneKind.circumferentialRing:
        dashedV(8, 6, h - 6); // 基准轴线
        label('A', const Offset(2, 2));
        final arcZone = Paint()
          ..color = const Color(0xFF3D7EFF).withOpacity(0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14;
        canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.6, cy), width: 44, height: 44),
            -1.1, 2.2, false, arcZone);
        canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.6, cy), width: 30, height: 30),
            -1.1, 2.2, false, line..strokeWidth = 1.2);
        canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.6, cy), width: 58, height: 58),
            -1.1, 2.2, false, line..strokeWidth = 1.2);
      case ZoneKind.cylindricalSurface:
        dashedV(8, 6, h - 6);
        label('A', const Offset(2, 2));
        canvas.drawRect(Rect.fromLTRB(16, cy - 14, w - 6, cy + 14), zone);
        canvas.drawRect(Rect.fromLTRB(16, cy - 14, w - 6, cy + 14), line);
        label('全表面', Offset(w * 0.4, cy - 8));
      case ZoneKind.uniformCurves:
        final outer = Path()
          ..moveTo(8, h - 10)
          ..quadraticBezierTo(cx - 10, 4, w - 10, cy);
        final inner = Path()
          ..moveTo(8, h - 10)
          ..quadraticBezierTo(cx - 24, 16, w - 24, cy);
        final area = Path.combine(PathOperation.difference, outer, inner);
        canvas.drawPath(area, zone);
        canvas.drawPath(outer, line);
        canvas.drawPath(inner, line);
      case ZoneKind.uniformSurfaces:
        final outer = Path()
          ..moveTo(6, h - 8)
          ..quadraticBezierTo(cx, 2, w - 8, h * 0.6)
          ..quadraticBezierTo(w - 30, h - 6, 6, h - 8);
        final inner = outer.shift(const Offset(10, 6));
        final area = Path.combine(PathOperation.difference, outer, inner);
        canvas.drawPath(area, zone);
        canvas.drawPath(outer, line);
        canvas.drawPath(inner, line);
    }
  }

  @override
  bool shouldRepaint(covariant _ZonePainter old) => old.kind != kind;
}
