# 机械精度与几何公差 · 公开摘要版

一个给机械工程师、QC、非标设计用的 Android 离线工具：查公差、算配合、读手册、背单词、查速查。

> **完全离线**：业务代码不联网、不登录、不上传数据。  
> **公开版只含章节摘要/学习卡/来源链接，不含原书全文**；完整书稿请查阅原书或取得授权。  
> **当前版本**：0.2.0+42（公开摘要版）· Android arm64  
> **构建**：GitHub Actions · Flutter 3.24 · Drift/SQLite schema v14

[下载 APK](https://github.com/sun1071449201-cloud/tolerance-tool-public/releases) · [问题反馈](https://github.com/sun1071449201-cloud/tolerance-tool-public/issues) · [构建说明](docs/构建与安装指南.md)

---

## 能做什么

### 公差与配合
- 尺寸公差查询：IT5~IT12、孔/轴极限偏差、配合性质
- 反选求解：给目标间隙/过盈，反推配合组合
- 基本偏差 120~500 mm 常用字母 + r/s/u 子段
- 未注公差 ISO 2768 / GB 1804 f/m/c/v
- GD&T 公差带图解、检测方法
- 18 个小工具：尺寸链、CPK、重量、单位、螺栓扭矩、轴承、导轨、散热等

### 书与学习
- 5 本书、63 章摘要：QC 检验、质量人成长、机械综合、避坑、非标自动化
- 每章摘要：结论 / 边界 / 反例 / 检查清单（20 章有完整学习卡）
- 20 个核心章节带 3 题自测，答对 2/3 标“掌握”
- H2 自动知识卡，章节 ↔ 速查 ↔ 工具互跳
- 586 个机械英语词：断点背诵、间隔复习、拼写、已背恢复
- 50 条工程速查：看过/掌握状态

### 数据
- 全部内容离线内置
- 书稿中的【经验值】与标准值分开标注
- 关键数值带来源/复核日期；详见每章摘要
- 备份包含书签、阅读进度、背诵、速查、章节学习

---

## 安装

1. 到 [Releases](https://github.com/sun1071449201-cloud/tolerance-tool-public/releases) 下载 ToleranceTool_*_arm64.apk
2. 手机允许“安装未知来源应用”
3. 安装后打开即可，无需注册/联网

> 仅提供 Android arm64。iOS 未构建。  
> 如果安装过其他签名的同包名版本，需要先卸载；卸载会丢本地数据，先备份。

## 从源码构建

项目故意不提交 android/ 壳，由 CI 按 Flutter 版本现场生成，避免模板漂移。

~~~bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter create . --project-name tolerance_tool --org com.sunliangyu --platforms android
flutter analyze
flutter test
flutter build apk --release --split-per-abi
~~~



## 项目结构

~~~text
lib/                 Flutter 源码（Riverpod + Drift）
assets/books/        5 本书章节摘要
assets/data/         种子 JSON（公差、速查、词库、学习卡）
test/                单元/组件/迁移测试
tool/                内容校验、构建辅助脚本
docs/                构建、内容规范、变更说明
.github/workflows/   云端 APK 构建
~~~

## 数据与内容边界

- 本项目不是标准发布机构，**不是官方标准文本**。
- 书稿/表格是学习与现场速查整理，正式判定以 ISO/GB/ASME 原文、图纸、客户规范为准。
- 书中的【经验值】不是标准值。
- GD&T 没有像 IT 那样的通用数值等级表；本项目不编造“等级数值”。
- 标准文本可能受版权保护；本项目只做学习性摘录/换算，不替代购买标准。

## 隐私

- 不收集账号、位置、通讯录、设备标识。
- 不包含广告/统计 SDK。
- 备份通过系统剪贴板/文件选择器在本地完成。
- 详见 [PRIVACY.md](PRIVACY.md)。

## 许可证

- **代码**：MIT，见 [LICENSE](LICENSE)。
- **书稿/文档/学习卡**：CC BY-NC-SA 4.0，见 [LICENSE-CONTENT.md](LICENSE-CONTENT.md)。
- 第三方标准/网页来源与免责声明见 [NOTICE.md](NOTICE.md)。

## 参与

- 发现数据错误：请开 Issue，附标准号、版本、尺寸段和依据。
- 不允许把估算值直接标成“已核对”；数据改动必须带来源。
- 提交前请跑：

~~~bash
flutter analyze
flutter test
python3 tool/validate_book_content.py
~~~

---

如果这个工具对你有用，点个 Star 就是最大的支持。
