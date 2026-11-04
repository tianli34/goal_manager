import 'package:flutter/material.dart';

import 'app_shell.dart';

class HomeDepthObserver extends NavigatorObserver {
  static final HomeDepthObserver instance = HomeDepthObserver();

  final Map<Route<dynamic>, int> _depths = {};

  int depthOf(Route<dynamic>? route) => route == null ? 0 : _depths[route] ?? 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) _depths.clear();
    _depths[route] = previousRoute == null ? 0 : depthOf(previousRoute) + 1;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _depths.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _depths.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute == null) return;
    _depths[newRoute] = depthOf(oldRoute);
    if (oldRoute != null) _depths.remove(oldRoute);
  }
}

int stepsToHome(BuildContext context) {
  final depth = HomeDepthObserver.instance.depthOf(ModalRoute.of(context));
  final tabIndex = AppShell.homeKey.currentState?.selectedIndex ?? 0;
  return depth + (tabIndex == 0 ? 0 : 1);
}

/// 键盘弹出时不显示悬浮主页按钮：Scaffold 会把 FAB 顶到键盘上方，
/// 挡住输入框和底部表单按钮。
bool shouldShowHomeButton(BuildContext context) =>
    MediaQuery.viewInsetsOf(context).bottom == 0 && stepsToHome(context) >= 2;

void goHome(BuildContext context) {
  Navigator.of(context).popUntil((route) => route.isFirst);
  AppShell.homeKey.currentState?.selectHomeTab();
}

class HomeFloatingButton extends StatelessWidget {
  const HomeFloatingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      tooltip: '回到主页',
      onPressed: () => goHome(context),
      icon: const Icon(Icons.home_outlined),
      label: const Text('主页'),
    );
  }
}
