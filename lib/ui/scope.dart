import 'package:flutter/widgets.dart';

import '../data/repository.dart';

class RepositoryScope extends InheritedNotifier<GoalRepository> {
  const RepositoryScope({
    super.key,
    required GoalRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static GoalRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RepositoryScope>();
    assert(scope != null, 'RepositoryScope 未找到');
    return scope!.notifier!;
  }

  static GoalRepository read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<RepositoryScope>();
    assert(scope != null, 'RepositoryScope 未找到');
    return scope!.notifier!;
  }
}
