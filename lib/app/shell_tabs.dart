class ShellTab {
  ShellTab(this.id, {this.index});

  final String id;
  int? index;
  String? _pluginId;
  String? get pluginId => _pluginId;
  set pluginId(String? value) {
    _pluginId = value;
    if (value != null) mountedPluginId = value;
  }

  /// Keep the plugin alive while this tab visits a fixed section.
  String? mountedPluginId;
}

/// Navigation slots shared by the rail, dashboard and plugin catalog.
class ShellTabs {
  ShellTabs() {
    active = ShellTab('tab-${_nextId++}');
    tabs.add(active);
  }

  final List<ShellTab> tabs = [];
  late ShellTab active;
  int _nextId = 0;

  void add() {
    active = ShellTab('tab-${_nextId++}', index: 0);
    tabs.add(active);
  }

  void select(String id) {
    active = tabs.firstWhere((tab) => tab.id == id);
  }

  void openPlugin(String id) {
    active.pluginId = id;
  }

  void close(String id) {
    final index = tabs.indexWhere((tab) => tab.id == id);
    if (index < 0) return;
    final removed = tabs.removeAt(index);
    if (tabs.isEmpty) {
      add();
    } else if (identical(active, removed)) {
      active = tabs[index.clamp(0, tabs.length - 1)];
    }
  }
}
