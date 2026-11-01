import 'package:flutter/material.dart';

import 'goals/goals_page.dart';
import 'now/now_page.dart';
import 'review/review_page.dart';
import 'scope.dart';
import 'settings/settings_page.dart';
import 'widgets/common.dart';
import 'widgets/pickers.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static final GlobalKey<AppShellState> homeKey = GlobalKey<AppShellState>();

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> with WidgetsBindingObserver {
  static const _titles = ['当下', '目标', '回顾', '设置'];

  final _goalsKey = GlobalKey<GoalsPageState>();
  int _index = 0;
  bool _promoteScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      RepositoryScope.read(context).activateScheduledGoals();
    }
  }

  void selectHomeTab() {
    if (_index == 0) return;
    setState(() => _index = 0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    if (!repo.settings.newGoalInAppBar && repo.topLevelGoalCount > 3) {
      _schedulePromoteCreateAction();
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (_index == 1 && repo.settings.newGoalInAppBar)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                widthFactor: 1,
                child: FilledButton.icon(
                  onPressed: _createGoalFromAppBar,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('新建'),
                ),
              ),
            ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          NowPage(onOpenGoals: () => setState(() => _index = 1)),
          GoalsPage(key: _goalsKey),
          const ReviewPage(),
          const SettingsPage(),
        ],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: _captureIdea,
              tooltip: '捕获',
              icon: const Icon(Icons.inbox_outlined),
              label: const Text('捕获'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny),
            label: '当下',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: '目标',
          ),
          NavigationDestination(
            icon: Icon(Icons.rate_review_outlined),
            selectedIcon: Icon(Icons.rate_review),
            label: '回顾',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }

  void _schedulePromoteCreateAction() {
    if (_promoteScheduled) return;
    _promoteScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promoteScheduled = false;
      if (!mounted) return;
      final repo = RepositoryScope.read(context);
      if (repo.settings.newGoalInAppBar || repo.topLevelGoalCount <= 3) return;
      repo.updateSettings(repo.settings.copyWith(newGoalInAppBar: true));
      showAppSnack(context, '「新建」按钮已移到顶部标题栏');
    });
  }

  void _createGoalFromAppBar() {
    _goalsKey.currentState?.createGoal();
  }

  Future<void> _captureIdea() async {
    final text = await captureIdeaDialog(context);
    if (text == null || text.trim().isEmpty || !mounted) return;
    RepositoryScope.read(context).addInbox(text);
    if (mounted) showAppSnack(context, '已放入收集箱');
  }
}
