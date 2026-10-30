String formatNumber(double value) {
  if (value.isNaN) return '-';
  if (value == value.roundToDouble()) return value.toInt().toString();
  final fixed = value.toStringAsFixed(2);
  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String formatNumberSigned(double value) {
  if (value > 0) return '+${formatNumber(value)}';
  return formatNumber(value);
}

String formatPercent(double ratio) {
  if (ratio.isNaN) return '-';
  return '${(ratio * 100).toStringAsFixed(ratio.abs() < 10 ? 1 : 0).replaceFirst(RegExp(r'\.0$'), '')}%';
}

double? parseDouble(String? text) {
  if (text == null) return null;
  final normalized = text.trim().replaceAll('，', '').replaceAll(',', '');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}
