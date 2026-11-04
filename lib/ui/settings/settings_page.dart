import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/date_utils.dart';
import '../../core/enums.dart';
import '../../data/storage.dart';
import '../scope.dart';
import '../widgets/common.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late int _staleDays;
  late int _riskDays;
  late int _metricMinObservations;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final settings = RepositoryScope.read(context).settings;
    _staleDays = settings.staleDays;
    _riskDays = settings.riskDays;
    _metricMinObservations = settings.metricMinObservations;
    _initialized = true;
  }

  void _syncThresholds() {
    final settings = RepositoryScope.read(context).settings;
    setState(() {
      _staleDays = settings.staleDays;
      _riskDays = settings.riskDays;
      _metricMinObservations = settings.metricMinObservations;
    });
  }

  void _commitThresholds() {
    final repo = RepositoryScope.read(context);
    repo.updateSettings(
      repo.settings.copyWith(
        staleDays: _staleDays,
        riskDays: _riskDays,
        metricMinObservations: _metricMinObservations,
      ),
    );
  }

  void _setDueFieldMode(DueFieldMode mode) {
    final repo = RepositoryScope.read(context);
    if (repo.settings.dueFieldMode == mode) return;
    repo.updateSettings(repo.settings.copyWith(dueFieldMode: mode));
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          '数据保存在本地，核心读写不依赖网络。',
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
        if (repo.loadError != null) ...[
          const SizedBox(height: 12),
          _Banner(
            icon: Icons.error_outline,
            text: repo.loadError!,
            color: scheme.error,
          ),
        ],
        if (repo.saveError != null) ...[
          const SizedBox(height: 12),
          _Banner(
            icon: Icons.warning_amber_rounded,
            text: repo.saveError!,
            color: scheme.error,
          ),
        ],
        const SectionHeader(title: '数据概览', subtitle: '导出与恢复都基于这些原始数据'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatPill(label: '目标', value: '${repo.goals.length}'),
                    StatPill(label: '记录', value: '${repo.records.length}'),
                    StatPill(label: '承诺', value: '${repo.commitments.length}'),
                    StatPill(label: '复盘', value: '${repo.reviews.length}'),
                    StatPill(label: '收集箱', value: '${repo.inbox.length}'),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '存储位置：${repo.storageDescription}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SectionHeader(
          title: '备份与导出',
          subtitle: 'JSON 可完整恢复；Markdown 便于阅读和存档',
        ),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.data_object),
                title: const Text('导出完整备份（JSON）'),
                subtitle: const Text('包含目标、记录、承诺、复盘与收集箱'),
                onTap: () => _export(json: true),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('导出可读报告（Markdown）'),
                subtitle: const Text('按目标层级整理，适合阅读与打印'),
                onTap: () => _export(json: false),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.restore_page_outlined),
                title: const Text('从 JSON 恢复'),
                subtitle: const Text('粘贴备份内容，替换当前全部数据'),
                onTap: _restore,
              ),
            ],
          ),
        ),
        const SectionHeader(title: '关注信号阈值', subtitle: '调整后立即影响「当下」页的提醒'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
            child: Column(
              children: [
                _ThresholdSlider(
                  label: '许久未记录',
                  suffix: '天',
                  value: _staleDays,
                  min: 3,
                  max: 60,
                  onChanged: (value) => setState(() => _staleDays = value),
                  onChangeEnd: _commitThresholds,
                ),
                _ThresholdSlider(
                  label: '日期风险提前量',
                  suffix: '天',
                  value: _riskDays,
                  min: 1,
                  max: 30,
                  onChanged: (value) => setState(() => _riskDays = value),
                  onChangeEnd: _commitThresholds,
                ),
                _ThresholdSlider(
                  label: '指标最少读数',
                  suffix: '次',
                  value: _metricMinObservations,
                  min: 1,
                  max: 10,
                  onChanged: (value) =>
                      setState(() => _metricMinObservations = value),
                  onChangeEnd: _commitThresholds,
                ),
              ],
            ),
          ),
        ),
        const SectionHeader(
          title: '目标表单',
          subtitle: '新建与编辑目标时，结束时间用哪种方式填写；期限只从开始日期起算',
        ),
        Card(
          child: Column(
            children: [
              _DueModeTile(
                mode: DueFieldMode.duration,
                selected: repo.settings.dueFieldMode == DueFieldMode.duration,
                onTap: () => _setDueFieldMode(DueFieldMode.duration),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _DueModeTile(
                mode: DueFieldMode.deadline,
                selected: repo.settings.dueFieldMode == DueFieldMode.deadline,
                onTap: () => _setDueFieldMode(DueFieldMode.deadline),
              ),
            ],
          ),
        ),
        const SectionHeader(title: '数据管理'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: const Text('载入示例数据'),
                subtitle: const Text('用一份完整示例体验五种机制'),
                onTap: _loadSample,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: scheme.error,
                ),
                title: Text('清空所有数据', style: TextStyle(color: scheme.error)),
                subtitle: const Text('不可撤销，建议先导出备份'),
                onTap: _clearAll,
              ),
            ],
          ),
        ),
        const SectionHeader(title: '关于'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Text(
              '北极星 · 首版 MVP\n\n'
              '五种机制：完成型、累积型、指标型、主观型、里程碑型。\n'
              '进度是派生值，完成判定与生命周期分别记录；原始读数始终保留。\n'
              '承诺不改变目标状态，复盘只产出决定。',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _export({required bool json}) async {
    final repo = RepositoryScope.read(context);
    final now = DateTime.now();
    final stamp =
        '${formatDate(now).replaceAll('-', '')}_${two(now.hour)}${two(now.minute)}';
    final content = json ? repo.exportJson() : repo.exportMarkdown();
    final fileName = json
        ? 'goal_manager_backup_$stamp.json'
        : 'goal_manager_report_$stamp.md';
    String? path;
    String? error;
    try {
      path = await writeBackupFile(fileName, content);
    } catch (e) {
      error = '$e';
    }
    var copied = true;
    try {
      await Clipboard.setData(ClipboardData(text: content));
    } catch (_) {
      copied = false;
    }
    if (!mounted) return;
    final message = error == null
        ? (copied ? '文件已保存，并已复制到剪贴板。' : '文件已保存，但剪贴板不可用。')
        : (copied ? '内容已复制到剪贴板，但写入文件失败。' : '写入文件和剪贴板都失败了。');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(json ? '完整备份已导出' : '可读报告已导出'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (path != null) ...[
              const SizedBox(height: 10),
              SelectableText(path, style: const TextStyle(fontSize: 11.5)),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _restore() async {
    final raw = await promptText(
      context,
      title: '从 JSON 恢复',
      hint: '粘贴完整备份 JSON',
      confirmLabel: '下一步',
      maxLines: 10,
    );
    if (raw == null || raw.isEmpty) return;
    if (!mounted) return;
    final confirmed = await confirmAction(
      context,
      title: '替换当前数据？',
      message: '恢复会用备份内容替换当前全部目标、记录、承诺、复盘与收集箱。',
      confirmLabel: '替换',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      RepositoryScope.read(context).importJson(raw);
      _syncThresholds();
      if (mounted) showAppSnack(context, '数据已恢复');
    } catch (e) {
      if (mounted) showAppSnack(context, '恢复失败：$e', error: true);
    }
  }

  Future<void> _loadSample() async {
    final repo = RepositoryScope.read(context);
    if (repo.hasData) {
      final confirmed = await confirmAction(
        context,
        title: '载入示例数据？',
        message: '当前数据会被示例数据替换。建议先导出备份。',
        confirmLabel: '载入',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }
    repo.loadSample();
    _syncThresholds();
    if (mounted) showAppSnack(context, '已载入示例数据');
  }

  Future<void> _clearAll() async {
    final confirmed = await confirmAction(
      context,
      title: '清空所有数据？',
      message: '这会删除全部目标、记录、承诺、复盘与收集箱，且不可撤销。',
      confirmLabel: '清空',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    RepositoryScope.read(context).clearAll();
    _syncThresholds();
    if (mounted) showAppSnack(context, '数据已清空');
  }
}

class _DueModeTile extends StatelessWidget {
  const _DueModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final DueFieldMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        size: 20,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(mode.label, style: const TextStyle(fontSize: 14)),
      subtitle: Text(mode.description, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }
}

class _ThresholdSlider extends StatelessWidget {
  const _ThresholdSlider({
    required this.label,
    required this.suffix,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final String suffix;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final VoidCallback onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: '$value $suffix',
            onChanged: (v) => onChanged(v.round()),
            onChangeEnd: (_) => onChangeEnd(),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '$value $suffix',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: color, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
