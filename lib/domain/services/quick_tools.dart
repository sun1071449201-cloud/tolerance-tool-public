import 'dart:math';

/// 小工具的纯计算逻辑（便于单元测试）。
class QuickTools {
  QuickTools._();

  /// 常用材料密度 (g/cm³)【典型值，供重量估算】。
  static const materials = <String, double>{
    '钢 / 铁': 7.85,
    '不锈钢': 7.9,
    '铜': 8.9,
    '黄铜': 8.5,
    '铝': 2.7,
    '钛': 4.5,
    'POM': 1.41,
    'PEEK': 1.3,
  };

  /// 重量（g）。shape: block(长宽高) / cylinder(直径×长) / tube(外径×内径×长)，尺寸单位 mm。
  static double weightGrams({
    required double densityGcm3,
    required String shape,
    required List<double> dims,
  }) {
    final v = volumeMm3(shape, dims);
    return v / 1000 * densityGcm3;
  }

  /// 体积 mm³。
  static double volumeMm3(String shape, List<double> dims) {
    switch (shape) {
      case 'block':
        return dims[0] * dims[1] * dims[2];
      case 'cylinder':
        return pi * pow(dims[0] / 2, 2) * dims[1];
      case 'tube':
        return pi * (pow(dims[0] / 2, 2) - pow(dims[1] / 2, 2)) * dims[2];
      default:
        return 0;
    }
  }

  /// MPa → kgf/cm²。
  static double mpaToKgfCm2(double mpa) => mpa * 10.1972;

  static double kgfCm2ToMpa(double v) => v / 10.1972;

  /// 英寸 → 毫米。
  static double inchToMm(double inch) => inch * 25.4;

  static double mmToInch(double mm) => mm / 25.4;

  /// N·m → kgf·m。
  static double nmToKgfM(double nm) => nm / 9.80665;

  static double kgfMToNm(double v) => v * 9.80665;

  /// 螺纹公称直径 → 应力截面积 As (mm²)【典型值，供扭矩估算】。
  static const boltSpecs = <String, double>{
    'M4': 8.78,
    'M5': 14.2,
    'M6': 20.1,
    'M8': 36.6,
    'M10': 58.0,
    'M12': 84.3,
    'M14': 115.0,
    'M16': 157.0,
    'M20': 245.0,
  };

  /// 性能等级 → 屈服强度 (MPa)。
  static const boltGrades = <String, double>{
    '8.8': 640,
    '10.9': 940,
    '12.9': 1100,
  };

  /// 螺栓拧紧扭矩估算：T = K × F × d，F = 预紧比 × σy × As。
  /// k 为扭矩系数：润滑 ~0.15，一般 ~0.18，干燥/镀锌 ~0.2。
  static double boltTorqueNm({
    required String spec,
    required String grade,
    required double k,
    double preloadRatio = 0.7,
  }) {
    final as = boltSpecs[spec]!;
    final sy = boltGrades[grade]!;
    final preloadN = preloadRatio * sy * as; // N
    final dM = double.parse(spec.substring(1)) / 1000; // m
    return k * preloadN * dM;
  }

  /// 对应预紧力 (kN)。
  static double boltPreloadKn({
    required String spec,
    required String grade,
    double preloadRatio = 0.7,
  }) {
    final as = boltSpecs[spec]!;
    final sy = boltGrades[grade]!;
    return preloadRatio * sy * as / 1000;
  }

  // ---- 热膨胀 ----

  /// 热膨胀变形量 ΔL = α × L(m) × ΔT，返回 μm（α 单位 μm/(m·°C)）。
  static double thermalExpansionUm({
    required double alphaUmPerMC,
    required double lengthMm,
    required double deltaT,
  }) {
    return alphaUmPerMC * (lengthMm / 1000) * deltaT;
  }

  /// 常用材料线膨胀系数 μm/(m·°C)【典型值】。
  static const expansionCoefficients = <String, double>{
    '碳钢/合金钢': 11.5,
    '不锈钢 (奥氏体)': 16.5,
    '铝合金': 23,
    '铜合金': 17,
    '钛合金': 8.6,
    'PEEK': 47,
    'POM': 85,
  };

  // ---- 粗糙度 Ra/Rz 对照 ----

  /// Ra → Rz 对照（经验关系 Rz ≈ (4~7)×Ra，对照常用标准系列）【待核对】。
  /// 记录列表而非 const Map（double 不能作 const Map 键）。
  static const raRzPairs = <(double, double)>[
    (0.025, 0.25),
    (0.05, 0.4),
    (0.1, 0.8),
    (0.2, 1.6),
    (0.4, 3.2),
    (0.8, 6.3),
    (1.6, 12.5),
    (3.2, 25),
    (6.3, 50),
    (12.5, 100),
  ];

  /// Ra → 对应 Rz 参考值（就近取标准档）。
  static double raToRz(double ra) {
    var best = raRzPairs.first.$2;
    var bestDiff = double.maxFinite;
    for (final p in raRzPairs) {
      final d = (p.$1 - ra).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = p.$2;
      }
    }
    return best;
  }

  /// Rz → 对应 Ra 参考值。
  static double rzToRa(double rz) {
    var best = raRzPairs.first.$1;
    var bestDiff = double.maxFinite;
    for (final p in raRzPairs) {
      final d = (p.$2 - rz).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = p.$1;
      }
    }
    return best;
  }

  // ---- 截面特性 ----

  /// 矩形截面：b×h。返回 (I_zz mm⁴, W_zz mm³)。
  static (double, double) rectSection(double b, double h) {
    final i = b * h * h * h / 12;
    return (i, i / (h / 2));
  }

  /// 圆截面：Ød。
  static (double, double) circleSection(double d) {
    final i = 3.14159265 * d * d * d * d / 64;
    return (i, i / (d / 2));
  }

  /// 圆管：外径 D 内径 d。
  static (double, double) tubeSection(double outer, double inner) {
    final i = 3.14159265 * (pow(outer, 4) - pow(inner, 4)) / 64;
    return (i.toDouble(), i / (outer / 2));
  }

  // ---- 梁挠度 ----

  /// 悬臂梁端部集中力：δ = FL³/3EI。返回 mm。
  static double cantileverTipLoad({
    required double forceN,
    required double lengthMm,
    required double eGPa,
    required double iMm4,
  }) {
    return forceN * pow(lengthMm, 3) /
        (3 * eGPa * 1000 * iMm4);
  }

  /// 简支梁中点集中力：δ = FL³/48EI。返回 mm。
  static double simplySupportedCenterLoad({
    required double forceN,
    required double lengthMm,
    required double eGPa,
    required double iMm4,
  }) {
    return forceN * pow(lengthMm, 3) /
        (48 * eGPa * 1000 * iMm4);
  }

  /// 常用材料弹性模量 E (GPa)【典型值待核对】。
  static const elasticModuli = <String, double>{
    '钢': 207,
    '不锈钢': 193,
    '铝': 69,
    '铜': 117,
    '钛': 114,
  };

  // ---- 功率/扭矩/转速 ----

  /// 功率 kW = T(N·m) × n(rpm) / 9550。
  static double torqueToPowerKw(double torqueNm, double rpm) =>
      torqueNm * rpm / 9550;

  /// 扭矩 N·m = P(kW) × 9550 / n(rpm)。
  static double powerToTorqueNm(double powerKw, double rpm) =>
      powerKw * 9550 / rpm;

  /// 转速 rpm = P(kW) × 9550 / T(N·m)。
  static double powerToRpm(double powerKw, double torqueNm) =>
      powerKw * 9550 / torqueNm;

  // ---- 齿轮参数 ----

  /// 分度圆直径 d = m × z (mm)。m=模数, z=齿数。
  static double gearPitchDia(double module, double teeth) =>
      module * teeth;

  /// 中心距 a = m × (z₁ + z₂) / 2 (mm)。
  static double gearCenterDistance(
      double module, double teeth1, double teeth2) =>
      module * (teeth1 + teeth2) / 2;

  /// 齿顶圆直径 da = m × (z + 2) (mm)，正常齿。
  static double gearAddendumDia(double module, double teeth) =>
      module * (teeth + 2);

  /// 齿根圆直径 df = m × (z − 2.5) (mm)，正常齿。
  static double gearDedendumDia(double module, double teeth) =>
      module * (teeth - 2.5);

  /// 周节（齿距）p = π × m (mm)。
  static double gearCircularPitch(double module) => 3.14159265 * module;

  // ---- 弹簧 ----

  /// 圆柱螺旋压缩弹簧刚度 k = G·d⁴ / (8·D³·n) (N/mm)。
  /// G=切变模量(MPa)，d=线径(mm)，D=中径(mm)，n=有效圈数。
  static double springRate({
    required double gMPa,
    required double wireDia,
    required double meanDia,
    required double activeCoils,
  }) {
    return gMPa * pow(wireDia, 4) /
        (8 * pow(meanDia, 3) * activeCoils);
  }

  /// 常用弹簧材料切变模量 G (GPa)【典型值待核对】。
  static const springModuli = <String, double>{
    '琴钢丝/不锈钢': 79.3,
    '油淬火弹簧钢': 78.5,
    '铍铜': 43.0,
  };

  // ---- 压配合 ----

  /// 压配合结合面压力 p = (δ/2) / (d × (1/E₁ + 1/E₂)) × 10⁻³ (MPa)。
  /// δ=过盈量(μm)，d=配合直径(mm)，E₁/E₂=GPa。
  static double pressFitPressure({
    required double interferenceUm,
    required double diaMm,
    required double e1GPa,
    required double e2GPa,
  }) {
    // Lame 公式简化（薄壁近似）：p = δ / (d × (1/E₁ + 1/E₂))
    return interferenceUm / 1000 /
        (diaMm * (1 / (e1GPa * 1000) + 1 / (e2GPa * 1000)));
  }

  // ---- 轴承 L10 寿命 ----

  /// L10 寿命（10⁶ 转）：球轴承 L10=(C/P)³，滚子轴承 L10=(C/P)^(10/3)。
  /// C：基本额定动载荷 kN；P：当量动载荷 kN。
  static double bearingL10MillionRevs({
    required double cKn,
    required double pKn,
    bool roller = false,
  }) {
    final ratio = cKn / pKn;
    return roller ? pow(ratio, 10 / 3).toDouble() : pow(ratio, 3).toDouble();
  }

  /// L10h 小时寿命 = L10 × 10⁶ / (60 × n rpm)。
  static double bearingL10Hours({
    required double l10Million,
    required double rpm,
  }) {
    return l10Million * 1e6 / (60 * rpm);
  }

  /// 伺服选型：加速扭矩 = J × α，α = (2πn/60) / t_a。
  static double accelTorque({
    required double inertiaKgM2,
    required double maxSpeedRpm,
    required double accelTimeS,
  }) {
    final omega = maxSpeedRpm * 2 * pi / 60; // rad/s
    final alpha = omega / accelTimeS; // rad/s²
    return inertiaKgM2 * alpha;
  }

  /// 峰值扭矩 = 负载扭矩 + 加速扭矩（匀加速段最恶劣工况）。
  static double peakTorque({
    required double loadTorqueNm,
    required double inertiaKgM2,
    required double maxSpeedRpm,
    required double accelTimeS,
  }) {
    return loadTorqueNm +
        accelTorque(
            inertiaKgM2: inertiaKgM2,
            maxSpeedRpm: maxSpeedRpm,
            accelTimeS: accelTimeS);
  }

  /// 功率 kW = T × n / 9550。
  static double powerKw({required double torqueNm, required double rpm}) {
    return torqueNm * rpm / 9550;
  }

  /// 惯量比 = 负载惯量 / 电机转子惯量。伺服经验：≤3 理想，≤10 可用【经验法则】。
  static double inertiaRatio({
    required double loadInertiaKgM2,
    required double rotorInertiaKgM2,
  }) {
    return loadInertiaKgM2 / rotorInertiaKgM2;
  }

  /// 三段工况 RMS 等效扭矩 = √(ΣT²t / Σt)。电机温升按 RMS 校核。
  static double rmsTorque({
    required List<double> torques,
    required List<double> durationsS,
  }) {
    var sum = 0.0, total = 0.0;
    for (var i = 0; i < torques.length && i < durationsS.length; i++) {
      sum += torques[i] * torques[i] * durationsS[i];
      total += durationsS[i];
    }
    if (total <= 0) return 0;
    return sqrt(sum / total);
  }

  /// 滚珠丝杠驱动扭矩 = F·Ph / (2π·η)。F(N)、Ph(mm) → N·m。
  static double ballscrewTorque({
    required double axialForceN,
    required double leadMm,
    required double efficiency,
  }) {
    return axialForceN * leadMm / (2 * pi * efficiency) / 1000;
  }

  /// 滚珠丝杠寿命 L10 = (Ca/P)^3（百万转）→ 小时 = ×1e6/(60·rpm)。
  static double ballscrewL10Hours({
    required double dynamicLoadKN,
    required double axialLoadKN,
    required double rpm,
  }) {
    final revs = pow(dynamicLoadKN / axialLoadKN, 3).toDouble(); // 百万转
    return revs * 1e6 / (60 * rpm);
  }

  /// 直线导轨额定寿命 L = (C/P)^3 × 50 km（ISO 14728-1）。
  static double guideLifeKm({
    required double dynamicLoadKN,
    required double equivalentLoadKN,
  }) {
    return pow(dynamicLoadKN / equivalentLoadKN, 3).toDouble() * 50;
  }

  /// 直线导轨寿命小时：每分钟行程 2×stroke×cycles(mm) → L(km)×1e6/(mm 每小时)。
  static double guideLifeHours({
    required double lifeKm,
    required double strokeMm,
    required double cyclesPerMin,
  }) {
    final mmPerHour = 2 * strokeMm * cyclesPerMin * 60;
    return lifeKm * 1e6 / mmPerHour;
  }

  /// 直线导轨所需动载荷 C_req = P × (L目标/50)^(1/3) (kN)。
  static double guideRequiredLoad({
    required double equivalentLoadKN,
    required double targetLifeKm,
  }) {
    return equivalentLoadKN * pow(targetLifeKm / 50, 1 / 3).toDouble();
  }

  // ==================== 非标选型（气缸 / 丝杠 / 同步带） ====================

  /// 气缸理论推力（无杆腔）= π/4 × D² × p。D(mm)·p(MPa) → N。
  static double cylinderPush({
    required double boreMm,
    required double pressureMPa,
  }) {
    return 0.7853981634 * boreMm * boreMm * pressureMPa;
  }

  /// 气缸理论拉力（有杆腔）= π/4 × (D² − d²) × p。
  static double cylinderPull({
    required double boreMm,
    required double rodMm,
    required double pressureMPa,
  }) {
    return 0.7853981634 * (boreMm * boreMm - rodMm * rodMm) * pressureMPa;
  }

  /// 气缸选型缸径 = √(4F / (η负载率 × p × π))，返回理论最小缸径 mm。
  static double cylinderBore({
    required double loadN,
    required double pressureMPa,
    required double loadFactor,
  }) {
    final required = loadN / loadFactor; // 需要的理论推力
    return sqrt(4 * required / (3.1415926535897932 * pressureMPa));
  }

  /// 标准缸径系列向上取整。
  static double standardBore(double minBoreMm) {
    const series = <double>[
      6, 10, 12, 16, 20, 25, 32, 40, 50, 63, 80, 100, 125, 160, 200, 250
    ];
    for (final s in series) {
      if (s >= minBoreMm) return s;
    }
    return 250.0;
  }

  /// 丝杠最小导程 = V×60/n_max（V mm/s、n rpm → Ph mm）。
  static double ballscrewMinLead({
    required double speedMmS,
    required double maxRpm,
  }) {
    return speedMmS * 60 / maxRpm;
  }

  /// 丝杠轴向力 = m·a + μ·m·g（水平安装，N）。accel 单位 m/s²。
  static double ballscrewAxialForce({
    required double massKg,
    required double accelMss,
    required double frictionCoef,
  }) {
    return massKg * accelMss + frictionCoef * massKg * 9.81;
  }

  /// 丝杠折算惯量 J = m·(Ph/2π)²（kg·m²）。
  static double ballscrewInertia({
    required double massKg,
    required double leadMm,
  }) {
    final r = leadMm / 1000 / (2 * pi); // m
    return massKg * r * r;
  }

  /// 同步带轮节圆直径 = z × Pb / π。
  static double beltPitchDia({
    required double teeth,
    required double pitchMm,
  }) {
    return teeth * pitchMm / 3.1415926535897932;
  }

  /// 同步带长度（近似）L = 2a + π/2(d1+d2) + (d2−d1)²/(4a)。
  static double beltLength({
    required double dia1,
    required double dia2,
    required double centerMm,
  }) {
    final big = dia1 > dia2 ? dia1 : dia2;
    final small = dia1 > dia2 ? dia2 : dia1;
    return 2 * centerMm +
        3.1415926535897932 / 2 * (dia1 + dia2) +
        (big - small) * (big - small) / (4 * centerMm);
  }

  // ==================== 计量检测（CPK / 正弦规 / 三针 / 锥度） ====================

  /// 样本标准差 s = √(Σ(x−x̄)²/(n−1))。n<2 返回 0。
  static double sampleStdev(List<double> xs) {
    final n = xs.length;
    if (n < 2) return 0;
    final mean = xs.reduce((a, b) => a + b) / n;
    var ss = 0.0;
    for (final x in xs) {
      ss += (x - mean) * (x - mean);
    }
    return sqrt(ss / (n - 1));
  }

  /// Cp = (USL−LSL)/(6s)。
  static double cp({
    required double usl,
    required double lsl,
    required double stdev,
  }) {
    if (stdev <= 0) return 0;
    return (usl - lsl) / (6 * stdev);
  }

  /// Cpk = min(USL−μ, μ−LSL)/(3s)。
  static double cpk({
    required double usl,
    required double lsl,
    required double mean,
    required double stdev,
  }) {
    if (stdev <= 0) return 0;
    final upper = usl - mean;
    final lower = mean - lsl;
    return (upper < lower ? upper : lower) / (3 * stdev);
  }

  /// Ca = (μ − 规格中心)/((USL−LSL)/2)，偏心度。
  static double ca({
    required double usl,
    required double lsl,
    required double mean,
  }) {
    final mid = (usl + lsl) / 2;
    final half = (usl - lsl) / 2;
    if (half <= 0) return 0;
    return (mean - mid) / half;
  }

  /// 正弦规量块高度 H = L·sin(θ)（θ 为需垫角度；锥体测量时=锥角之半）。
  static double sineGaugeHeight({
    required double rollDistanceMm,
    required double angleDeg,
  }) {
    return rollDistanceMm * sin(angleDeg * pi / 180);
  }

  /// 由量块高度反求角度（度）。
  static double angleFromSineHeight({
    required double rollDistanceMm,
    required double heightMm,
  }) {
    if (rollDistanceMm <= 0) return 0;
    final r = (heightMm / rollDistanceMm).clamp(-1.0, 1.0);
    return asin(r) * 180 / pi;
  }

  /// 公制螺纹基本中径 d₂ = d − 0.649519·P（60° 牙型角）。
  static double metricBasicPitchDia({
    required double nominalDiaMm,
    required double pitchMm,
  }) {
    return nominalDiaMm - 0.649519 * pitchMm;
  }

  /// 公制螺纹三针测量基本 M 值 = d₂ + 3·D − 0.866025·P，D 为量针直径。
  /// 最佳量针 D = 0.57735·P（与牙侧面中径线接触）。
  static double threadMeasureOverPins({
    required double nominalDiaMm,
    required double pitchMm,
    double? wireDiaMm,
  }) {
    final d2 = metricBasicPitchDia(
        nominalDiaMm: nominalDiaMm, pitchMm: pitchMm);
    final wire = wireDiaMm ?? 0.577350 * pitchMm;
    return d2 + 3 * wire - 0.866025 * pitchMm;
  }

  /// 锥度：返回 [锥度 1:K, 半角°, 全角°]。K = L/(D−d)。
  static List<double> taperInfo({
    required double bigDiaMm,
    required double smallDiaMm,
    required double lengthMm,
  }) {
    final diff = bigDiaMm - smallDiaMm;
    if (diff <= 0 || lengthMm <= 0) return [0, 0, 0];
    final k = lengthMm / diff;
    final half = atan(diff / (2 * lengthMm)) * 180 / pi;
    return [k, half, half * 2];
  }
}
