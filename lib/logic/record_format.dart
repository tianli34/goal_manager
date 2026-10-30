import '../core/enums.dart';
import '../core/numbers.dart';
import '../models/goal.dart';
import '../models/update_record.dart';

String recordTitle(UpdateRecord record, Goal? goal) {
  final unit = goal?.unit ?? '';
  switch (record.type) {
    case RecordType.progress:
      if (record.delta != null) {
        final after = record.valueAfter == null
            ? ''
            : '（累计 ${formatNumber(record.valueAfter!)} $unit）';
        return '推进 ${formatNumberSigned(record.delta!)} $unit$after'.trim();
      }
      if (record.reading != null) {
        return '读数 ${formatNumber(record.reading!)} $unit'.trim();
      }
      if (record.subjectivePercent != null) {
        return '自评 ${record.subjectivePercent}%';
      }
      return '记录';
    case RecordType.configChange:
      return '配置变更';
    case RecordType.reopen:
      return '重新打开';
    case RecordType.lifecycleChange:
      return '状态变更';
  }
}

String recordBody(UpdateRecord record) {
  final parts = <String>[];
  if (record.note.isNotEmpty) parts.add(record.note);
  if (record.reason.isNotEmpty) parts.add('原因：${record.reason}');
  return parts.join(' · ');
}
