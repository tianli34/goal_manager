import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goal_manager/app.dart';
import 'package:goal_manager/data/repository.dart';
import 'package:goal_manager/data/storage.dart';
import 'package:goal_manager/models/goal.dart';

void main() {
  Future<GoalRepository> repoWithGoals(int count) async {
    final repo = GoalRepository(MemoryAppStorage());
    await repo.init();
    for (var i = 1; i <= count; i++) {
      repo.addGoal(Goal(id: 'g$i', title: '目标$i'));
    }
    return repo;
  }

  Future<void> pumpApp(WidgetTester tester, GoalRepository repo) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GoalManagerApp(repository: repo));
    await tester.pumpAndSettle();
  }

  Finder appBarCreateButton() => find.descendant(
    of: find.byType(AppBar),
    matching: find.widgetWithText(FilledButton, '新建'),
  );

  testWidgets('顶层目标不超过三个时，新建与更新并排在底部', (tester) async {
    final repo = await repoWithGoals(3);
    await pumpApp(tester, repo);

    await tester.tap(find.text('目标'));
    await tester.pumpAndSettle();

    final createButton = find.widgetWithText(FilledButton, '新建');
    final updateButton = find.widgetWithText(FilledButton, '更新');
    expect(createButton, findsOneWidget);
    expect(updateButton, findsOneWidget);
    expect(appBarCreateButton(), findsNothing);

    final createRect = tester.getRect(createButton);
    final updateRect = tester.getRect(updateButton);
    expect(createRect.top, updateRect.top);
    expect(createRect.left, lessThan(updateRect.left));

    await tester.tap(updateButton);
    await tester.pumpAndSettle();
    expect(find.text('更新哪个目标？'), findsOneWidget);
  });

  testWidgets('顶层目标首次超过三个时，新建移到标题栏并提示一次', (tester) async {
    final repo = await repoWithGoals(3);
    await pumpApp(tester, repo);

    await tester.tap(find.text('目标'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, '新建'), findsOneWidget);
    expect(appBarCreateButton(), findsNothing);

    repo.addGoal(Goal(id: 'g4', title: '目标4'));
    await tester.pumpAndSettle();

    expect(repo.settings.newGoalInAppBar, isTrue);
    expect(find.text('「新建」按钮已移到顶部标题栏'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '新建'), findsOneWidget);
    expect(appBarCreateButton(), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '更新'), findsOneWidget);

    await tester.tap(find.text('当下'));
    await tester.pumpAndSettle();
    expect(appBarCreateButton(), findsNothing);
  });

  testWidgets('标题栏的新建按钮可直接打开目标编辑页', (tester) async {
    final repo = await repoWithGoals(3);
    await pumpApp(tester, repo);

    await tester.tap(find.text('目标'));
    await tester.pumpAndSettle();

    repo.addGoal(Goal(id: 'g4', title: '目标4'));
    await tester.pumpAndSettle();
    await tester.tap(appBarCreateButton());
    await tester.pumpAndSettle();

    expect(find.text('创建目标'), findsOneWidget);
  });
}
