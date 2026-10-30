import 'dart:math';

final Random _random = Random.secure();

String newId() {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final noise = _random.nextInt(1 << 30).toRadixString(36);
  return '$time$noise';
}
