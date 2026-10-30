import 'package:flutter/material.dart';

import '../../core/date_utils.dart';
import '../goals/goal_editor_page.dart';
import '../scope.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('收集箱'),
        actions: [
          IconButton(
            tooltip: '添加想法',
            icon: const Icon(Icons.add),
            onPressed: () => _add(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _add(context),
        child: const Icon(Icons.add),
      ),
      body: repo.inbox.isEmpty
          ? const EmptyState(
              icon: Icons.inbox_outlined,
              title: '收集箱是空的',
              message: '没想清楚的事情先放进来，不要求机制和日期。',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '收集箱不参与任何统计。处理完之后，它就不留在这里。',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...repo.inbox.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        title: Text(
                          item.text,
                          style: const TextStyle(fontSize: 13.5),
                        ),
                        subtitle: Text(
                          formatRelative(DateTime.now(), item.createdAt),
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: '处理',
                          icon: const Icon(Icons.more_horiz, size: 18),
                          onSelected: (action) =>
                              _handle(context, item.id, item.text, action),
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'goal', child: Text('转为目标')),
                            PopupMenuItem(value: 'discard', child: Text('舍弃')),
                          ],
                        ),
                        onTap: () =>
                            _handle(context, item.id, item.text, 'goal'),
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final text = await captureIdeaDialog(context);
    if (text == null || text.trim().isEmpty) return;
    if (!context.mounted) return;
    RepositoryScope.read(context).addInbox(text);
    if (context.mounted) showAppSnack(context, '已放入收集箱');
  }

  Future<void> _handle(
    BuildContext context,
    String id,
    String text,
    String action,
  ) async {
    final repo = RepositoryScope.read(context);
    if (action == 'discard') {
      final confirmed = await confirmAction(
        context,
        title: '舍弃这条想法？',
        message: '它会从收集箱移除，不会留下记录。',
        confirmLabel: '舍弃',
        destructive: true,
      );
      if (confirmed) {
        repo.removeInbox(id);
        if (context.mounted) showAppSnack(context, '已舍弃');
      }
      return;
    }
    final goalId = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => GoalEditorPage(initialTitle: text)),
    );
    if (goalId != null) {
      repo.removeInbox(id);
      if (context.mounted) showAppSnack(context, '已转为目标');
    }
  }
}
