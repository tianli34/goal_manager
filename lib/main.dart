import 'package:flutter/material.dart';

import 'app.dart';
import 'data/repository.dart';
import 'data/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = GoalRepository(createDefaultStorage());
  await repository.init();
  runApp(GoalManagerApp(repository: repository));
}
