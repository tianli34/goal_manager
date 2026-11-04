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

/// 「期限」输入框支持的时长单位。
enum DurationUnit {
  day('天'),
  week('周'),
  month('个月'),
  year('年');

  const DurationUnit(this.label);

  final String label;

  /// 备份里的单位名非法时回落到默认单位「个月」。
  static DurationUnit parse(String? value) => values.firstWhere(
    (e) => e.name == value,
    orElse: () => DurationUnit.month,
  );
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 按日历单位加时长。月 / 年按自然月推进，并对月末做夹紧：
/// 1 月 31 日 + 1 个月 = 2 月 28 日（闰年 29 日）。
DateTime addCalendarDuration(DateTime start, int amount, DurationUnit unit) {
  final day = dateOnly(start);
  return switch (unit) {
    DurationUnit.day => DateTime(day.year, day.month, day.day + amount),
    DurationUnit.week => DateTime(day.year, day.month, day.day + amount * 7),
    DurationUnit.month => _addMonths(day, amount),
    DurationUnit.year => _addMonths(day, amount * 12),
  };
}

DateTime _addMonths(DateTime day, int months) {
  final total = day.year * 12 + day.month - 1 + months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day.day > lastDay ? lastDay : day.day);
}

/// 把已有的日期区间反推成可编辑的时长，保证再次推导后结束日期完全一致。
/// 结束日期不晚于开始日期时无法用正时长表示，返回 null（此时退回日期选择）。
({int amount, DurationUnit unit})? inferCalendarDuration(
  DateTime start,
  DateTime end,
) {
  final from = dateOnly(start);
  final to = dateOnly(end);
  final days = to.difference(from).inDays;
  if (days <= 0) return null;
  for (final unit in const <DurationUnit>[
    DurationUnit.year,
    DurationUnit.month,
    DurationUnit.week,
  ]) {
    final guess = switch (unit) {
      DurationUnit.year => to.year - from.year,
      DurationUnit.month => (to.year - from.year) * 12 + to.month - from.month,
      DurationUnit.week => days ~/ 7,
      _ => days,
    };
    for (var amount = guess - 1; amount <= guess + 1; amount++) {
      if (amount > 0 && sameDay(addCalendarDuration(from, amount, unit), to)) {
        return (amount: amount, unit: unit);
      }
    }
  }
  return (amount: days, unit: DurationUnit.day);
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
