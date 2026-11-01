import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/numbers.dart';
import '../theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: compact ? 16 : 36,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: compact ? 28 : 38,
            color: scheme.primary.withValues(alpha: 0.55),
          ),
          SizedBox(height: compact ? 8 : 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

class MechanismChip extends StatelessWidget {
  const MechanismChip(this.mechanism, {super.key, this.compact = false});

  final Mechanism mechanism;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = mechanismColor(mechanism);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        mechanism.label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class LifecycleChip extends StatelessWidget {
  const LifecycleChip(this.lifecycle, {super.key});

  final Lifecycle lifecycle;

  @override
  Widget build(BuildContext context) {
    final color = lifecycleColor(lifecycle);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        lifecycle.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class TagPill extends StatelessWidget {
  const TagPill(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: scheme.onSurfaceVariant),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressTrack extends StatelessWidget {
  const ProgressTrack({
    super.key,
    required this.ratio,
    this.color,
    this.height = 8,
  });

  final double? ratio;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = (ratio ?? 0).clamp(0, 1).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        valueColor: AlwaysStoppedAnimation(color ?? scheme.primary),
      ),
    );
  }
}

class InfoLine extends StatelessWidget {
  const InfoLine({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 80,
  });

  final String label;
  final String value;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = color ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: tone,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class MiniProgress extends StatelessWidget {
  const MiniProgress({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final double? value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              ProgressTrack(ratio: value, color: color, height: 6),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value == null ? '—' : formatPercent(value!),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

void showAppSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? hint,
  String initialValue = '',
  String confirmLabel = '确定',
  int maxLines = 1,
  bool allowEmpty = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _PromptTextDialog(
      title: title,
      hint: hint,
      initialValue: initialValue,
      confirmLabel: confirmLabel,
      maxLines: maxLines,
      allowEmpty: allowEmpty,
    ),
  );
}

class _PromptTextDialog extends StatefulWidget {
  const _PromptTextDialog({
    required this.title,
    required this.hint,
    required this.initialValue,
    required this.confirmLabel,
    required this.maxLines,
    required this.allowEmpty,
  });

  final String title;
  final String? hint;
  final String initialValue;
  final String confirmLabel;
  final int maxLines;
  final bool allowEmpty;

  @override
  State<_PromptTextDialog> createState() => _PromptTextDialogState();
}

class _PromptTextDialogState extends State<_PromptTextDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.maxLines,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (!widget.allowEmpty && text.isEmpty) return;
            Navigator.pop(context, text);
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

String weekdayName(DateTime date) {
  const names = ['一', '二', '三', '四', '五', '六', '日'];
  return '周${names[date.weekday - 1]}';
}
