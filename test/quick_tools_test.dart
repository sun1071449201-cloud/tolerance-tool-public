import 'package:flutter_test/flutter_test.dart';
import 'package:tolerance_tool/domain/services/quick_tools.dart';

void main() {
  group('重量计算器', () {
    test('长方体钢件 100×50×20 mm = 785 g', () {
      final g = QuickTools.weightGrams(
          densityGcm3: 7.85, shape: 'block', dims: [100, 50, 20]);
      expect(g, closeTo(785, 0.1));
    });

    test('圆柱铝件 Ø100×100 mm ≈ 2120.6 g', () {
      final g = QuickTools.weightGrams(
          densityGcm3: 2.7, shape: 'cylinder', dims: [100, 100]);
      expect(g, closeTo(2120.6, 0.5));
    });

    test('圆管（外径 40 内径 30 长 100，钢）≈ 48.3 g', () {
      final g = QuickTools.weightGrams(
          densityGcm3: 7.85, shape: 'tube', dims: [40, 30, 100]);
      // π*(20²-15²)*100 = 54977.9 mm³ ≈ 54.98 cm³ * 7.85 ≈ 431.6 g
      expect(g, closeTo(431.6, 0.5));
    });
  });

  group('单位换算', () {
    test('MPa → kgf/cm²', () {
      expect(QuickTools.mpaToKgfCm2(100), closeTo(1019.72, 0.01));
      expect(QuickTools.kgfCm2ToMpa(101.972), closeTo(10, 0.001));
    });

    test('英寸 ↔ 毫米', () {
      expect(QuickTools.inchToMm(1), 25.4);
      expect(QuickTools.mmToInch(25.4), 1.0);
    });

    test('N·m ↔ kgf·m', () {
      expect(QuickTools.nmToKgfM(9.80665), closeTo(1, 0.0001));
      expect(QuickTools.kgfMToNm(1), closeTo(9.80665, 0.0001));
    });
  });

  group('螺栓扭矩计算器', () {
    test('M8 / 8.8 级 / 一般摩擦 ≈ 23.6 N·m（落在标准表 22~26 区间）', () {
      final t = QuickTools.boltTorqueNm(spec: 'M8', grade: '8.8', k: 0.18);
      expect(t, closeTo(23.6, 0.5));
      expect(t, inExclusiveRange(22, 26));
    });

    test('预紧力 8.8 / M8 ≈ 16.4 kN', () {
      expect(QuickTools.boltPreloadKn(spec: 'M8', grade: '8.8'),
          closeTo(16.4, 0.2));
    });

    test('润滑（K=0.15）扭矩低于干燥（K=0.2）', () {
      final wet = QuickTools.boltTorqueNm(spec: 'M10', grade: '8.8', k: 0.15);
      final dry = QuickTools.boltTorqueNm(spec: 'M10', grade: '8.8', k: 0.2);
      expect(wet, lessThan(dry));
    });

    test('12.9 级扭矩高于 8.8 级（同规格同摩擦）', () {
      final high = QuickTools.boltTorqueNm(spec: 'M10', grade: '12.9', k: 0.18);
      final low = QuickTools.boltTorqueNm(spec: 'M10', grade: '8.8', k: 0.18);
      expect(high, greaterThan(low));
    });
  });

  group('热膨胀计算器', () {
    test('100mm 铝件温升 10℃ ≈ 23 μm', () {
      final dl = QuickTools.thermalExpansionUm(
          alphaUmPerMC: 23, lengthMm: 100, deltaT: 10);
      expect(dl, closeTo(23, 0.01));
    });

    test('负温差为缩短（负值）', () {
      final dl = QuickTools.thermalExpansionUm(
          alphaUmPerMC: 11.5, lengthMm: 100, deltaT: -8);
      expect(dl, closeTo(-9.2, 0.01));
    });
  });

  group('Ra/Rz 转换', () {
    test('Ra 1.6 → Rz 12.5 档位', () {
      expect(QuickTools.raToRz(1.6), 12.5);
    });

    test('Rz 6.3 → Ra 0.8 档位', () {
      expect(QuickTools.rzToRa(6.3), 0.8);
    });

    test('就近取档（Ra 0.75 → 按 0.8 档 → Rz 6.3）', () {
      expect(QuickTools.raToRz(0.75), 6.3);
    });
  });

  group('轴承 L10 寿命', () {
    test('球轴承 C/P=5 → L10=125 百万转', () {
      final l = QuickTools.bearingL10MillionRevs(cKn: 25, pKn: 5);
      expect(l, closeTo(125, 0.01));
    });

    test('L10h 换算：125 百万转 @1500rpm ≈ 1389 小时', () {
      final h = QuickTools.bearingL10Hours(l10Million: 125, rpm: 1500);
      expect(h, closeTo(1388.9, 1));
    });

    test('滚子轴承指数 10/3 高于球轴承（C/P>1 时）', () {
      final ball = QuickTools.bearingL10MillionRevs(cKn: 25, pKn: 5, roller: false);
      final roller = QuickTools.bearingL10MillionRevs(cKn: 25, pKn: 5, roller: true);
      expect(roller, greaterThan(ball));
    });
  });

  group('截面特性', () {
    test('矩形 b=20 h=40：I = 106667 mm⁴', () {
      final (i, w) = QuickTools.rectSection(20, 40);
      expect(i, closeTo(106666.67, 1));
      expect(w, closeTo(5333.33, 1));
    });

    test('实心圆 Ø30：I = 39761 mm⁴', () {
      final (i, _) = QuickTools.circleSection(30);
      expect(i, closeTo(39760.78, 1));
    });

    test('圆管 D=40 d=20：I > 实心圆 Ø20', () {
      final (tube, _) = QuickTools.tubeSection(40, 20);
      final (solid, _) = QuickTools.circleSection(20);
      expect(tube, greaterThan(solid));
    });
  });

  group('梁挠度', () {
    test('悬臂梁 F=100N L=200mm 钢 I=106667 → δ≈0.0121 mm', () {
      final d = QuickTools.cantileverTipLoad(
          forceN: 100, lengthMm: 200, eGPa: 207, iMm4: 106666.67);
      expect(d, closeTo(0.0121, 0.001));
    });

    test('简支梁同参数 → 挠度为悬臂的 1/16', () {
      final cant = QuickTools.cantileverTipLoad(
          forceN: 100, lengthMm: 200, eGPa: 207, iMm4: 106666.67);
      final simp = QuickTools.simplySupportedCenterLoad(
          forceN: 100, lengthMm: 200, eGPa: 207, iMm4: 106666.67);
      expect(cant / simp, closeTo(16, 0.1));
    });
  });

  group('功率/扭矩/转速', () {
    test('T=24 N·m, n=1500 rpm → P≈3.77 kW', () {
      expect(QuickTools.torqueToPowerKw(24, 1500), closeTo(3.77, 0.01));
    });
    test('P=3.77 kW, n=1500 → T≈24 N·m', () {
      expect(QuickTools.powerToTorqueNm(3.77, 1500), closeTo(24, 0.1));
    });
  });

  group('齿轮参数', () {
    test('m=2, z=20 → d=40, da=44, df=35', () {
      expect(QuickTools.gearPitchDia(2, 20), 40);
      expect(QuickTools.gearAddendumDia(2, 20), 44);
      expect(QuickTools.gearDedendumDia(2, 20), 35);
    });
    test('m=2, z1=20, z2=40 → a=60, i=2', () {
      expect(QuickTools.gearCenterDistance(2, 20, 40), 60);
      expect(40 / 20, 2);
    });
  });

  group('弹簧刚度', () {
    test('d=2, D=12, n=8, G=79300 → k≈11.47 N/mm', () {
      final k = QuickTools.springRate(
          gMPa: 79300, wireDia: 2, meanDia: 12, activeCoils: 8);
      expect(k, closeTo(11.47, 0.1));
    });
  });

  group('伺服电机选型', () {
    test('J=0.001 kg·m², n=3000, t_a=0.1s → 加速扭矩 ≈ 3.142 N·m', () {
      final t = QuickTools.accelTorque(
          inertiaKgM2: 0.001, maxSpeedRpm: 3000, accelTimeS: 0.1);
      expect(t, closeTo(3.1416, 0.01));
    });

    test('负载 1 N·m + 上述加速 → 峰值 ≈ 4.142 N·m，功率 ≈ 1.30 kW', () {
      final peak = QuickTools.peakTorque(
          loadTorqueNm: 1,
          inertiaKgM2: 0.001,
          maxSpeedRpm: 3000,
          accelTimeS: 0.1);
      expect(peak, closeTo(4.1416, 0.01));
      final p = QuickTools.powerKw(torqueNm: peak, rpm: 3000);
      expect(p, closeTo(1.301, 0.01));
    });

    test('惯量比 10/1 = 10', () {
      final r = QuickTools.inertiaRatio(
          loadInertiaKgM2: 10e-4, rotorInertiaKgM2: 1e-4);
      expect(r, closeTo(10, 0.001));
    });

    test('RMS：三段 [4,1,3]×[0.1,1,0.1] → √(3.5/1.2) ≈ 1.708', () {
      final rms = QuickTools.rmsTorque(
          torques: [4, 1, 3], durationsS: [0.1, 1.0, 0.1]);
      expect(rms, closeTo(1.708, 0.01));
    });
  });

  group('直线传动选型', () {
    test('丝杠 F=2000N, Ph=10mm, η=0.9 → T≈3.54 N·m', () {
      final t = QuickTools.ballscrewTorque(
          axialForceN: 2000, leadMm: 10, efficiency: 0.9);
      expect(t, closeTo(3.538, 0.01));
    });

    test('丝杠寿命 Ca=20, P=5, rpm=1500 → L10h ≈ 711 h', () {
      final h = QuickTools.ballscrewL10Hours(
          dynamicLoadKN: 20, axialLoadKN: 5, rpm: 1500);
      expect(h, closeTo(711.1, 1));
    });

    test('导轨寿命 C=20, P=5 → (4)³×50 = 3200 km', () {
      final km = QuickTools.guideLifeKm(
          dynamicLoadKN: 20, equivalentLoadKN: 5);
      expect(km, closeTo(3200, 1));
    });

    test('导轨 3200km、行程 600mm、10 次/分 → ≈ 4444 h', () {
      final h = QuickTools.guideLifeHours(
          lifeKm: 3200, strokeMm: 600, cyclesPerMin: 10);
      expect(h, closeTo(4444.4, 5));
    });

    test('导轨目标 20000km、P=5kN → C_req = 5×(400)^(1/3) ≈ 36.84 kN', () {
      final c = QuickTools.guideRequiredLoad(
          equivalentLoadKN: 5, targetLifeKm: 20000);
      expect(c, closeTo(36.84, 0.1));
    });
  });

  group('非标选型', () {
    test('气缸推力 Ø40 @0.5MPa → 628.3 N', () {
      final f = QuickTools.cylinderPush(boreMm: 40, pressureMPa: 0.5);
      expect(f, closeTo(628.3, 0.1));
    });

    test('气缸拉力 Ø40 杆16 @0.5MPa → 527.8 N', () {
      final f = QuickTools.cylinderPull(
          boreMm: 40, rodMm: 16, pressureMPa: 0.5);
      expect(f, closeTo(527.8, 0.1));
    });

    test('气缸选型：负载 200N、p=0.5、η=0.5 → 理论缸径 31.9 → Ø32', () {
      final d = QuickTools.cylinderBore(
          loadN: 200, pressureMPa: 0.5, loadFactor: 0.5);
      expect(d, closeTo(31.91, 0.05));
      expect(QuickTools.standardBore(d), 32);
    });

    test('丝杠最小导程 V=300mm/s、n=3000 → 6 mm', () {
      expect(
          QuickTools.ballscrewMinLead(speedMmS: 300, maxRpm: 3000),
          closeTo(6, 0.01));
    });

    test('丝杠轴向力 20kg、a=3 m/s²、μ=0.1 → 79.6 N', () {
      final f = QuickTools.ballscrewAxialForce(
          massKg: 20, accelMss: 3, frictionCoef: 0.1);
      expect(f, closeTo(20 * 3 + 0.1 * 20 * 9.81, 0.01));
    });

    test('丝杠折算惯量 m=10、Ph=10mm → 2.533×10⁻⁵ kg·m²', () {
      final j = QuickTools.ballscrewInertia(massKg: 10, leadMm: 10);
      expect(j, closeTo(2.533e-5, 1e-7));
    });

    test('同步带轮 HTD8M z=20 → 节径 50.93 mm', () {
      final d = QuickTools.beltPitchDia(teeth: 20, pitchMm: 8);
      expect(d, closeTo(50.93, 0.01));
    });

    test('带长 d1=d2=50.93、a=500 → ≈ 1160 mm', () {
      final l = QuickTools.beltLength(
          dia1: 50.93, dia2: 50.93, centerMm: 500);
      expect(l, closeTo(1160.0, 0.5));
    });
  });

  group('计量检测', () {
    test('样本标准差 [10.02,10.04,9.98,10.00,9.96] → 0.03162', () {
      final s = QuickTools
          .sampleStdev([10.02, 10.04, 9.98, 10.00, 9.96]);
      expect(s, closeTo(0.03162, 0.0001));
    });

    test('CPK：USL10.1 LSL9.9、上述样本 → Cp=Cpk≈1.054, Ca=0', () {
      final s = QuickTools
          .sampleStdev([10.02, 10.04, 9.98, 10.00, 9.96]);
      final cp = QuickTools.cp(usl: 10.1, lsl: 9.9, stdev: s);
      final cpk = QuickTools.cpk(
          usl: 10.1, lsl: 9.9, mean: 10.0, stdev: s);
      final ca = QuickTools.ca(usl: 10.1, lsl: 9.9, mean: 10.0);
      expect(cp, closeTo(1.054, 0.01));
      expect(cpk, closeTo(1.054, 0.01));
      expect(ca, closeTo(0, 0.0001));
    });

    test('正弦规 L=100、θ=15° → H=25.882；H=50、L=100 → θ=30°', () {
      final h = QuickTools.sineGaugeHeight(
          rollDistanceMm: 100, angleDeg: 15);
      expect(h, closeTo(25.882, 0.01));
      final a = QuickTools.angleFromSineHeight(
          rollDistanceMm: 100, heightMm: 50);
      expect(a, closeTo(30, 0.001));
    });

    test('三针 M6×1 → 基本中径 5.3505、最佳针 0.577、M=6.2165', () {
      final d2 = QuickTools.metricBasicPitchDia(
          nominalDiaMm: 6, pitchMm: 1);
      expect(d2, closeTo(5.350481, 0.0001));
      final m = QuickTools.threadMeasureOverPins(
          nominalDiaMm: 6, pitchMm: 1);
      expect(m, closeTo(6.216507, 0.001));
    });

    test('锥度 D20 d18 L40 → 1:20、半角 1.4321°、全角 2.8642°', () {
      final t = QuickTools.taperInfo(
          bigDiaMm: 20, smallDiaMm: 18, lengthMm: 40);
      expect(t[0], closeTo(20, 0.01));
      expect(t[1], closeTo(1.4321, 0.001));
      expect(t[2], closeTo(2.8642, 0.002));
    });
  });
}
