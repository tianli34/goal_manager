String two(int value) => value.toString().padLeft(2, '0');

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime weekStart(DateTime value) {
  final day = dateOnly(value);
  return day.subtract(Duration(days: day.weekday - 1));
}

DateTime weekEnd(DateTime value) =>
    weekStart(value).add(const Duration(days: 7));

String formatDate(DateTime? value) {
  if (value == null) return '未设置';
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}

String formatDateTime(DateTime value) =>
    '${formatDate(value)} ${two(value.hour)}:${two(value.minute)}';

String formatMonthDay(DateTime value) => '${value.month}月${value.day}日';

String formatRelative(DateTime now, DateTime value) {
  final diff = now.difference(value);
  if (diff.isNegative) {
    final ahead = value.difference(now);
    if (ahead.inMinutes < 1) return '即将';
    if (ahead.inHours < 1) return '${ahead.inMinutes} 分钟后';
    if (ahead.inDays < 1) return '${ahead.inHours} 小时后';
    return '${ahead.inDays} 天后';
  }
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
  if (diff.inDays < 1) return '${diff.inHours} 小时前';
  if (diff.inDays < 30) return '${diff.inDays} 天前';
  return formatDate(value);
}

String formatDurationDays(int days) {
  final value = days.abs();
  if (value >= 365) {
    final years = value ~/ 365;
    final rest = value % 365;
    return rest == 0 ? '$years 年' : '$years 年 $rest 天';
  }
  if (value >= 30) {
    final months = value ~/ 30;
    final rest = value % 30;
    return rest == 0 ? '$months 个月' : '$months 个月 $rest 天';
  }
  return '$value 天';
}

String remainingText(DateTime? due, DateTime now) {
  if (due == null) return '未设置截止日期';
  final days = dateOnly(due).difference(dateOnly(now)).inDays;
  if (days > 0) return '还剩 ${formatDurationDays(days)}';
  if (days == 0) return '今天到期';
  return '已逾期 ${formatDurationDays(-days)}';
}

String dayRangeText(DateTime start, DateTime end) =>
    '${formatMonthDay(start)} - ${formatMonthDay(end)}';
