import 'package:flutter/material.dart';

import '../core/enums.dart';
import 'goals/goal_editor_page.dart';
import 'goals/goals_page.dart';
import 'goals/update_sheet.dart';
import 'now/now_page.dart';
import 'review/review_page.dart';
import 'scope.dart';
import 'settings/settings_page.dart';
import 'widgets/common.dart';
import 'widgets/pickers.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _titles = ['当下', '目标', '回顾', '设置'];

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(
        index: _index,
        children: [
          NowPage(onOpenGoals: () => setState(() => _index = 1)),
          const GoalsPage(),
          const ReviewPage(),
          const SettingsPage(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openQuickActions,
        tooltip: '快速记录',
        child: const Icon(Icons.add),
      ),
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

  Future<void> _openQuickActions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  '快速记录',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('先记下来，再决定如何处理'),
              ),
              ListTile(
                leading: const Icon(Icons.inbox_outlined),
                title: const Text('捕获一个想法'),
                subtitle: const Text('放入收集箱，不要求机制和日期'),
                onTap: () => Navigator.pop(context, 'inbox'),
              ),
              ListTile(
                leading: const Icon(Icons.add_task),
                title: const Text('新建目标'),
                subtitle: const Text('完整定义机制、达成条件与日期'),
                onTap: () => Navigator.pop(context, 'create'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('更新已有目标'),
                subtitle: const Text('记录增量、读数、自评或一条说明'),
                onTap: () => Navigator.pop(context, 'update'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case 'inbox':
        final text = await captureIdeaDialog(context);
        if (text == null || text.trim().isEmpty) return;
        if (!mounted) return;
        RepositoryScope.read(context).addInbox(text);
        if (mounted) showAppSnack(context, '已放入收集箱');
        break;
      case 'create':
        await Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => const GoalEditorPage()),
        );
        break;
      case 'update':
        final goals = RepositoryScope.read(context).goals
            .where(
              (g) =>
                  !g.isArchived &&
                  (g.lifecycle == Lifecycle.active ||
                      g.lifecycle == Lifecycle.pending ||
                      g.lifecycle == Lifecycle.paused),
            )
            .toList();
        if (goals.isEmpty) {
          if (mounted) showAppSnack(context, '还没有可以更新的目标');
          return;
        }
        final goal = await showGoalPicker(context, goals, title: '更新哪个目标？');
        if (goal == null || !mounted) return;
        await showUpdateSheet(context, goal.id);
        break;
    }
  }
}
