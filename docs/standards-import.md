# 标准库导入接口说明

App 的全部标准数值来自 `assets/data/*.json`，启动时由 `SeedImporter` 校验后事务式导入 SQLite。
当前内置数据为**演示库**（`dataset_mode=demo`，查询页顶部横幅有标识）。你可以按以下两种方式升级为**标准库**。

## 方式 A：直接替换种子 JSON（推荐给单人使用）

1. 编辑对应 JSON 文件（UTF-8，列-行数组格式）：

| 数据 | 文件 | 结构 |
|---|---|---|
| 标准公差 IT1~IT18 | `assets/data/it_tolerance_values.json` | `[standard_code, step_id, grade_id, value_um(μm,数值可含小数,导入时四舍五入), source_ref, verified]` |
| 基本偏差 | `assets/data/fundamental_deviation_values.json` | `[standard_code, step_id, dev_id, defined_side(es/ei), deviation_um, opposite_um, source_ref, verified]` |
| 优先配合 | `assets/data/preferred_fits.json` | 组合与用途，数值由上两表推导 |
| 未注公差 | `assets/data/general_tolerances.json` | 按标准/等级/类型 |

2. 每核对完一个文件，把对应行的 `verified` 置为 `true`，`source_ref` 写明标准原文出处（如 "GB/T 1800.1-2020 表 1"）。
3. 修改 `assets/data/app_settings.json`：`["dataset_mode","standard"]`（App 顶部横幅会变为"标准库"标识）。
4. 重新打开 App：checksum 变化会触发自动重导入；或重新安装 APK。

## 方式 B：从外部文件导入（接口约定）

`SeedImporter.seedIfNeeded(Map<String, String> files)` 是唯一导入入口，接受"文件名 → JSON 字符串"的映射，与资产来源解耦。外部数据源的接入约定：

1. **数据格式**：与方式 A 完全相同的 JSON 结构（`table` + `columns` + `rows`）。
2. **调用点**：在 `lib/main.dart` 中，将外部来源（如 SD 卡文件、用户通过系统分享传入的 JSON）读为字符串后并入 `files` 映射再调用 `seedIfNeeded` 即可，无需改动数据层。
3. **校验**：导入器自动做引用完整性校验（尺寸段/等级/偏差代号/标准必须存在），非法数据会抛 `StateError` 并阻止入库——因此外部文件必须引用已注册的 `step_id`（ISO_MAIN_000_003 … ISO_MAIN_400_500）与 `grade_id`（IT1~IT18）。
4. **幂等**：`seed_meta.checksum` 未变化时跳过导入；外部数据变更后 checksum 随之变化，自动重导。

## 数据规模现状（演示库）

- IT 表：IT1~IT18 × 13 尺寸段 = 234 行（结构完整，数值待逐项核对）
- 轴基本偏差：c/d/e/f/g/h/k/n/p/r/s/u（部分覆盖至 120/50 mm）
- 孔基本偏差：H（EI=0）
- 优先配合：11 组；未注公差：m/c 级

> 未能保证 100% 准确的数值均已标注 `verified=false` 与"待核对"，正式工程使用前请按标准原文核对。
