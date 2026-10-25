# 构建与安装指南（Windows → 安卓手机）

## 0. 当前环境结论

本机（2026-10-24 检查）**缺失**：Flutter SDK、Dart、git、Android SDK（`%LOCALAPPDATA%\Android` 不存在）、adb；已装的是 Oracle JDK 11，而 Android 构建需要 **JDK 17**。因此无法在本机直接产出 APK。

## 1. 一次性环境安装（最省事路线）

1. 安装 **Flutter SDK**（自带 Dart）：<https://docs.flutter.dev/get-started/install/windows>
   - 解压到如 `C:\dev\flutter`，把 `C:\dev\flutter\bin` 加入 PATH
2. 安装 **Android Studio**（会带上 Android SDK、平台工具，并可选装 JDK 17）：
   - 安装时勾选 Android SDK、Android SDK Platform-Tools、Android SDK Build-Tools
   - 首次启动 → More Actions → SDK Manager → 确认已装最新 Android SDK Platform
3. 打开新终端验证：

```bat
flutter doctor
```

`flutter doctor` 中 Android toolchain 一项带 ✓ 即可。若提示 licenses 未接受，运行：

```bat
flutter doctor --android-licenses
```

> 注意：如果工程路径包含中文/空格。绝大多数情况可直接构建；若 Gradle 报路径相关错误，把整个项目文件夹复制到纯英文路径（如 `C:\dev\tolerance_tool`）再构建。

## 2. 一键构建

在项目根目录（本 README 所在目录）用 PowerShell 执行：

```powershell
powershell -ExecutionPolicy Bypass -File setup_and_build.ps1
```

脚本依次做 6 件事（也可手动逐步执行）：

```powershell
flutter doctor -v                                        # 1. 体检
flutter create . --project-name tolerance_tool --platforms android   # 2. 生成 android/ 工程骨架（首次需要）
robocopy tool\source_backup\lib lib /MIR                 # 3. 恢复业务源码（防 create 覆盖）
robocopy tool\source_backup\test test /MIR
flutter pub get                                          # 4. 依赖
dart run build_runner build --delete-conflicting-outputs # 5. 生成 Drift 代码（app_database.g.dart）
flutter analyze && flutter test                          # 6. 静态检查 + 单元测试
flutter build apk --debug                                # 7. 产出 APK
```

成功后 APK 在：`build\app\outputs\flutter-apk\app-debug.apk`

## 3. 安装到安卓手机

1. 用数据线把 APK（`app-debug.apk`）拷到手机存储，或通过微信/网盘发送给自己
2. 手机上点击该 APK → 系统提示"未知来源应用" → 允许该来源安装 → 安装
3. 打开应用"机械精度与几何公差"，**建议开启飞行模式**验证完全离线可用

（手机连电脑时也可 `flutter install` 或 `adb install app-debug.apk`。）

## 4. 验收（里程碑 1）

断网打开应用，输入 `⌀50 H7/g6` → 应显示：孔/轴上下偏差、间隙配合、Xmax/Xmin、2D 公差带图、"默认独立原则"提示卡，页面顶部有黄色"占位数据"警示。5 条验收用例见 `docs/非技术版说明.md` 第 5 节。

## 5. 常见问题

| 现象 | 处理 |
|---|---|
| `flutter: command not found` | PATH 未加 flutter\bin，重开终端再试 |
| Gradle 报 JDK 版本 | 在 Android Studio Settings → Build Tools → Gradle 里选 JDK 17 |
| 构建时下载依赖慢 | 配置国内镜像（PUB_HOSTED_URL / FLUTTER_STORAGE_BASE_URL 环境变量） |
| 启动闪退 | 先跑 `flutter test` 确认种子校验通过；种子 JSON 被改坏时启动会报校验错误 |
| 改了 JSON 数值没生效 | 正常情况重启即生效（checksum 变化触发重导）；若异常可卸载重装 |

## 6. 在线云打包（本机零安装）

ZIP 包内已内置云端构建配置（`.github/workflows/build_apk.yml`），并**刻意不包含 android/ 目录**——由云端按其 Flutter 版本执行 `flutter create .` 自动生成，避免模板与 CI 环境版本不匹配。

### 方案 A：GitHub Actions（推荐，完全免费）
1. 注册/登录 [github.com](https://github.com) → 右上角 "+" → New repository（名字随意，可选 Private）
2. 在新仓库页点 **"uploading an existing file"**，把 ZIP 里的**全部文件和文件夹**拖进去（务必包含 `.github` 文件夹，那是构建配置），点 Commit changes（文件多时可装 GitHub Desktop 直接拖文件夹）
3. 仓库页 → **Actions** 标签 → 左侧 "Build Android APK" → **Run workflow** → 等待约 5~10 分钟（会自动跑单元测试，测试不通过会红叉并给出原因）
4. 该次运行页底部 **Artifacts** → 下载 `tolerance-tool-debug-apk` → 解压得 `app-debug.apk`

### 方案 B：Codemagic（Flutter 专业 CI，每月 500 分钟免费）
1. [codemagic.io](https://codemagic.io) 用 GitHub 账号注册
2. Add application → 选刚建的 GitHub 仓库 → 项目类型 Flutter App
3. 平台勾 **Android** → Start build（免费档共享机器，高峰期需排队）
4. 完成后在构建页 Artifacts 下载 app-debug.apk
   - 若用 Workflow Editor 自定义：在 Pre-build script 加 `flutter create . --project-name tolerance_tool --platforms android`

### 方案 C：Code2Native（支持直接上传 ZIP，无需 Git）
1. [code2native.com](https://code2native.com) 注册（有免费档位）
2. 上传本 ZIP → 选择 Flutter/Android 云构建 → 下载 APK
   - ⚠ 未经我验证它是否会自动补生成缺失的 `android/` 目录；若报"缺 Android 工程"类错误，请改用方案 A（已内置自动化，必定可跑）。

### 其他
- FlutLab.io：在线 Flutter IDE，支持导入 ZIP 并在浏览器构建 APK（免费额度有限，备选）。
- "PhilBuilder"：未检索到该平台的有效信息（可能已下线或名称有误），不建议使用。
