import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/utils/format.dart';
import '../../domain/models/tolerance_models.dart';

/// 公差带图色板：全部从 Theme colorScheme 派生，深浅色自动适配。
class TolerancePalette {
  const TolerancePalette({
    required this.zeroLine,
    required this.holeFill,
    required this.holeBorder,
    required this.shaftFill,
    required this.shaftBorder,
    required this.guide,
    required this.arrow,
    required this.label,
  });

  final Color zeroLine;
  final Color holeFill;
  final Color holeBorder;
  final Color shaftFill;
  final Color shaftBorder;
  final Color guide;
  final Color arrow;
  final Color label;

  factory TolerancePalette.of(ColorScheme s) => TolerancePalette(
        zeroLine: s.onSurface,
        holeFill: s.primary.withOpacity(0.22),
        holeBorder: s.primary,
        shaftFill: s.tertiary.withOpacity(0.22),
        shaftBorder: s.tertiary,
        guide: s.outlineVariant,
        arrow: s.onSurface,
        label: s.onSurfaceVariant,
      );
}

/// 图数据（μm，带符号）。约定：向上为正偏差，零线 = 基本尺寸。
class ZoneChartData {
  const ZoneChartData({
    this.holeUpper,
    this.holeLower,
    this.shaftUpper,
    this.shaftLower,
    required this.holeLabel,
    this.shaftLabel,
    this.pair1Label = '',
    this.pair2Label = '',
  });

  final double? holeUpper; // ES
  final double? holeLower; // EI
  final double? shaftUpper; // es
  final double? shaftLower; // ei
  final String holeLabel;
  final String? shaftLabel;
  final String pair1Label; // 孔上偏差↔轴下偏差之间：Xmax / Ymin
  final String pair2Label; // 孔下偏差↔轴上偏差之间：Xmin / Ymax

  factory ZoneChartData.of(FitQueryResult r) {
    String p1 = '';
    String p2 = '';
    final type = r.fitType;
    if (type == FitType.clearance) {
      p1 = 'Xmax';
      p2 = 'Xmin';
    } else if (type == FitType.transition) {
      p1 = 'Xmax';
      p2 = 'Ymax';
    } else if (type == FitType.interference) {
      p1 = 'Ymin';
      p2 = 'Ymax';
    }
    return ZoneChartData(
      holeUpper: r.hole.upperUm.toDouble(),
      holeLower: r.hole.lowerUm.toDouble(),
      shaftUpper: r.shaft?.upperUm.toDouble(),
      shaftLower: r.shaft?.lowerUm.toDouble(),
      holeLabel: '孔 ${r.input.hole.code}',
      shaftLabel: r.shaft == null ? null : '轴 ${r.input.shaft!.code}',
      pair1Label: p1,
      pair2Label: p2,
    );
  }
}

class ToleranceZoneChart extends StatelessWidget {
  const ToleranceZoneChart({super.key, required this.result});

  final FitQueryResult result;

  @override
  Widget build(BuildContext context) {
    final palette = TolerancePalette.of(Theme.of(context).colorScheme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 300,
          width: double.infinity,
          child: CustomPaint(
            painter: ToleranceZonePainter(data: ZoneChartData.of(result), palette: palette),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final t in result.fitTerms)
              Chip(
                label: Text(
                  '${t.label} = ${t.isInterference ? formatUmMagnitude(t.um) : formatUmSigned(t.um)} mm',
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// 2D 公差带图：零线水平；孔带与轴带水平并排共享同一纵轴刻度；
/// 中部以双向箭头标出间隙/过盈极限区间。正偏差在零线上方，负偏差在下方。
class ToleranceZonePainter extends CustomPainter {
  ToleranceZonePainter({required this.data, required this.palette});

  final ZoneChartData data;
  final TolerancePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 12.0, rightPad = 12.0, topPad = 30.0, bottomPad = 34.0;
    final plotW = math.max(0.0, size.width - leftPad - rightPad);
    final plotH = math.max(0.0, size.height - topPad - bottomPad);

    final vals = <double>[0];
    if (data.holeUpper != null) vals.addAll([data.holeUpper!, data.holeLower!]);
    if (data.shaftUpper != null) vals.addAll([data.shaftUpper!, data.shaftLower!]);
    var lo = vals.reduce(math.min);
    var hi = vals.reduce(math.max);
    final span = math.max(1.0, hi - lo);
    lo -= span * 0.18;
    hi += span * 0.18;

    double y(double v) => topPad + (hi - v) / (hi - lo) * plotH;
    const x0 = leftPad;
    final x1 = leftPad + plotW;
    final yc = y(0);

    // 零线
    final zeroPaint = Paint()
      ..color = palette.zeroLine
      ..strokeWidth = 2.4;
    canvas.drawLine(Offset(x0, yc), Offset(x1, yc), zeroPaint);
    _label(canvas, '零线（基本尺寸）', Offset(x0, yc + 5), size.width - 24, palette.label, 10);

    final bandW = plotW * 0.26;
    final holeL = x0 + plotW * 0.10;
    final holeR = holeL + bandW;
    final shaftR = x1 - plotW * 0.10;
    final shaftL = shaftR - bandW;

    // 孔公差带
    if (data.holeUpper != null) {
      final rect = Rect.fromLTRB(holeL, y(data.holeUpper!), holeR, y(data.holeLower!));
      canvas.drawRect(rect, Paint()..color = palette.holeFill);
      canvas.drawRect(
        rect,
        Paint()
          ..color = palette.holeBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
      _label(canvas, 'ES ${formatUmSigned(data.holeUpper!.round())}',
          Offset(holeL, math.max(2.0, y(data.holeUpper!) - 16)), bandW + 80, palette.label, 10.5);
      _label(canvas, 'EI ${formatUmSigned(data.holeLower!.round())}',
          Offset(holeL, y(data.holeLower!) + 4), bandW + 80, palette.label, 10.5);
      _label(canvas, data.holeLabel, Offset(holeL, 6), bandW + 40, palette.zeroLine, 12);
    }

    // 轴公差带
    if (data.shaftUpper != null) {
      final rect = Rect.fromLTRB(shaftL, y(data.shaftUpper!), shaftR, y(data.shaftLower!));
      canvas.drawRect(rect, Paint()..color = palette.shaftFill);
      canvas.drawRect(
        rect,
        Paint()
          ..color = palette.shaftBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
      _label(canvas, 'es ${formatUmSigned(data.shaftUpper!.round())}',
          Offset(shaftL, math.max(2.0, y(data.shaftUpper!) - 16)), bandW + 80, palette.label, 10.5);
      _label(canvas, 'ei ${formatUmSigned(data.shaftLower!.round())}',
          Offset(shaftL, y(data.shaftLower!) + 4), bandW + 80, palette.label, 10.5);
      _label(canvas, data.shaftLabel ?? '轴', Offset(shaftL, 6), bandW + 40, palette.zeroLine, 12);
    }

    // 配合极限箭头与引出线
    if (data.shaftUpper != null && data.holeUpper != null) {
      final xc = (holeR + shaftL) / 2;
      final guide = Paint()
        ..color = palette.guide
        ..strokeWidth = 1;
      _dashedH(canvas, Offset(holeR, y(data.holeUpper!)), Offset(xc - 10, y(data.holeUpper!)), guide);
      _dashedH(canvas, Offset(holeR, y(data.holeLower!)), Offset(xc - 10, y(data.holeLower!)), guide);
      _dashedH(canvas, Offset(xc + 10, y(data.shaftUpper!)), Offset(shaftL, y(data.shaftUpper!)), guide);
      _dashedH(canvas, Offset(xc + 10, y(data.shaftLower!)), Offset(shaftL, y(data.shaftLower!)), guide);

      _arrow(canvas, Offset(xc, y(data.shaftLower!)), Offset(xc, y(data.holeUpper!)),
          data.pair1Label, palette);
      _arrow(canvas, Offset(xc, y(data.holeLower!)), Offset(xc, y(data.shaftUpper!)),
          data.pair2Label, palette);
    } else {
      _label(canvas, '未输入轴公差带：仅显示孔公差带', Offset(x0, size.height - bottomPad + 8),
          plotW, palette.label, 11);
    }
  }

  void _arrow(Canvas canvas, Offset a, Offset b, String label, TolerancePalette palette) {
    if ((a.dy - b.dy).abs() < 2) return;
    final p = Paint()
      ..color = palette.arrow
      ..strokeWidth = 1.6;
    canvas.drawLine(a, b, p);
    _arrowHead(canvas, a, b, p);
    _arrowHead(canvas, b, a, p);
    if (label.isNotEmpty) {
      _label(canvas, label, Offset(a.dx + 6, (a.dy + b.dy) / 2 - 7), 60, palette.arrow, 10);
    }
  }

  void _arrowHead(Canvas canvas, Offset tip, Offset from, Paint p) {
    final delta = tip - from;
    final d = delta.distance;
    if (d == 0) return;
    final dir = delta / d;
    final perp = Offset(-dir.dy, dir.dx);
    canvas.drawLine(tip, tip - dir * 8 + perp * 3.5, p);
    canvas.drawLine(tip, tip - dir * 8 - perp * 3.5, p);
  }

  void _dashedH(Canvas canvas, Offset a, Offset b, Paint p) {
    if ((b.dx - a.dx).abs() < 2) return;
    const dash = 4.0, gap = 3.0;
    final start = math.min(a.dx, b.dx);
    final end = math.max(a.dx, b.dx);
    final yy = a.dy;
    var x = start;
    while (x < end) {
      canvas.drawLine(Offset(x, yy), Offset(math.min(x + dash, end), yy), p);
      x += dash + gap;
    }
  }

  void _label(Canvas canvas, String text, Offset at, double maxWidth, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    tp.layout(maxWidth: maxWidth);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant ToleranceZonePainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.palette != palette;
}
