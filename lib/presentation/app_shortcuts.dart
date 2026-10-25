import 'package:quick_actions/quick_actions.dart';

/// Android 桌面长按快捷菜单（App Shortcuts）。
/// 长按桌面图标 → 尺寸公差 / M6底孔速查 / 机械英语。
class AppShortcuts {
  /// shortcut type → 目标（tab:N = 切换 Tab；quickref:xx = 打开速查详情）。
  static const targets = {
    'action_tolerance': 'tab:0',
    'action_tapdrill': 'quickref:qr_std_tapdrill',
    'action_vocab': 'tab:1',
  };

  /// 初始化：注册快捷项 + 监听点击。
  static void init(void Function(String type) onAction) {
    const QuickActions().initialize(onAction);
    const QuickActions().setShortcutItems(const <ShortcutItem>[
      ShortcutItem(type: 'action_tolerance', localizedTitle: '尺寸公差'),
      ShortcutItem(type: 'action_tapdrill', localizedTitle: 'M6底孔速查'),
      ShortcutItem(type: 'action_vocab', localizedTitle: '机械英语'),
    ]);
  }
}
