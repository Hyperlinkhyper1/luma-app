import 'package:flutter/widgets.dart';

/// Builds each page on its first visit and retains its state for later visits.
/// A null index suspends all pages without starting an unvisited page.
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({super.key, this.index = 0, required this.children})
    : assert(index == null || (index >= 0 && index < children.length));

  final int? index;
  final List<Widget> children;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  final Set<int> _visited = {};

  @override
  Widget build(BuildContext context) {
    final selected = widget.index;
    if (selected != null) _visited.add(selected);
    return IndexedStack(
      index: selected,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          TickerMode(
            enabled: i == selected,
            child: _visited.contains(i)
                ? RepaintBoundary(child: widget.children[i])
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}
