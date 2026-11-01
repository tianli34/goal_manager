import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'data/repository.dart';
import 'data/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = GoalRepository(createDefaultStorage());
  await repository.init();
  Timer.periodic(
    const Duration(hours: 1),
    (_) => repository.activateScheduledGoals(),
  );
  runApp(GoalManagerApp(repository: repository));
}
