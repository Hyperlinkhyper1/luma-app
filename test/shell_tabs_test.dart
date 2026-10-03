import 'package:flutter_test/flutter_test.dart';
import 'package:luma/app/shell_tabs.dart';

void main() {
  test(
    'new tabs open dashboard and plugin navigation fills the active slot',
    () {
      final tabs = ShellTabs();
      tabs.openPlugin('ai-usage');
      final first = tabs.active;
      tabs.add();
      final second = tabs.active;
      expect(second.index, 0);
      expect(second.pluginId, isNull);
      tabs.openPlugin('calculator');
      expect(tabs.tabs.length, 2);
      expect(first.pluginId, 'ai-usage');
      expect(second.pluginId, 'calculator');
      tabs.select(first.id);
      expect(tabs.active.pluginId, 'ai-usage');
      tabs.select(second.id);
      expect(tabs.active.pluginId, 'calculator');
    },
  );

  test('closing selects a neighbour and the last tab returns to dashboard', () {
    final tabs = ShellTabs();
    final first = tabs.active;
    tabs.add();
    final second = tabs.active;
    tabs.add();
    final third = tabs.active;
    tabs.close(second.id);
    expect(tabs.active, third);
    tabs.close(third.id);
    expect(tabs.active, first);
    tabs.close(first.id);
    expect(tabs.tabs, hasLength(1));
    expect(tabs.active.index, 0);
    expect(tabs.active.pluginId, isNull);
  });

  test('visiting a fixed section retains the mounted plugin in its tab', () {
    final tabs = ShellTabs();
    tabs.openPlugin('ai-usage');
    tabs.active.index = 6;
    tabs.active.pluginId = null;
    expect(tabs.active.mountedPluginId, 'ai-usage');
    tabs.openPlugin('calculator');
    expect(tabs.tabs, hasLength(1));
    expect(tabs.active.mountedPluginId, 'calculator');
  });
}
