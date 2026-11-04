import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goal_manager/app.dart';
import 'package:goal_manager/core/date_utils.dart';
import 'package:goal_manager/core/enums.dart';
import 'package:goal_manager/data/repository.dart';
import 'package:goal_manager/data/storage.dart';
import 'package:goal_manager/models/goal.dart';
import 'package:goal_manager/ui/goals/goal_editor_page.dart';
import 'package:goal_manager/ui/scope.dart';

void main() {
  testWidgets('空数据时显示引导，并可切换主页面', (tester) async {
    final repo = GoalRepository(MemoryAppStorage());
    await repo.init();

    await tester.pumpWidget(GoalManagerApp(repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('从第一个目标开始'), findsOneWidget);

    await tester.tap(find.text('目标'));
    await tester.pumpAndSettle();
    expect(find.text('还没有目标'), findsOneWidget);

    await tester.tap(find.text('回顾'));
    await tester.pumpAndSettle();
    expect(find.text('本周期变化'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('数据概览'), findsOneWidget);
  });

  testWidgets('捕获按钮只在当下标签显示，点击直接捕获想法', (tester) async {
    final repo = GoalRepository(MemoryAppStorage());
    await repo.init();

    await tester.pumpWidget(GoalManagerApp(repository: repo));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('捕获'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('捕获一个想法'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '记一个想法');
    await tester.tap(find.text('放入收集箱'));
    await tester.pumpAndSettle();

    expect(repo.inbox.length, 1);

    await tester.tap(find.text('目标'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('新建目标使用定时启动，选今日后按钮变为启动目标并激活', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = GoalRepository(MemoryAppStorage());
    await repo.init();

    await tester.pumpWidget(GoalManagerApp(repository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('目标'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建目标').last);
    await tester.pumpAndSettle();

    expect(find.text('定时启动'), findsOneWidget);
    expect(find.text('创建目标'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '定时目标');
    await tester.tap(find.text('未设置').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('启动目标'), findsOneWidget);

    await tester.tap(find.text('启动目标'));
    await tester.pumpAndSettle();

    expect(repo.goals.single.lifecycle, Lifecycle.active);
  });

  testWidgets('未设置开始日期时，期限只保存规则、不推算结束日期', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = GoalRepository(MemoryAppStorage());
    await repo.init();

    await tester.pumpWidget(GoalManagerApp(repository: repo));
    await tester.pumpAndSettle();

    final nav = find.byType(NavigationBar);
    await tester.tap(find.descendant(of: nav, matching: find.text('目标')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建目标').last);
    await tester.pumpAndSettle();

    final editor = find.byType(GoalEditorPage);
    expect(
      find.descendant(of: editor, matching: find.text('期限')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: editor, matching: find.text('截止日期')),
      findsNothing,
    );

    await tester.enterText(find.byType(TextField).first, '时长目标');
    await tester.enterText(find.byKey(const Key('duration-field')), '3');
    await tester.pumpAndSettle();

    expect(find.textContaining('从开始日期起算'), findsOneWidget);
    expect(find.textContaining('暂不计算结束日期'), findsOneWidget);
    expect(find.textContaining('从今天'), findsNothing);
    expect(find.textContaining('结束于'), findsNothing);

    await tester.tap(find.descendant(of: editor, matching: find.text('创建目标')));
    await tester.pumpAndSettle();

    final goal = repo.goals.single;
    expect(goal.durationLabel, '3 个月');
    expect(goal.startDate, isNull);
    expect(goal.dueDate, isNull);
  });

  testWidgets('设置开始日期后，期限从该日期起算并写入结束日期', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = GoalRepository(MemoryAppStorage());
    await repo.init();

    await tester.pumpWidget(GoalManagerApp(repository: repo));
    await tester.pumpAndSettle();

    final nav = find.byType(NavigationBar);
    await tester.tap(find.descendant(of: nav, matching: find.text('目标')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建目标').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '定时时长目标');
    await tester.enterText(find.byKey(const Key('duration-field')), '3');
    await tester.pumpAndSettle();

    await tester.tap(find.text('未设置').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.textContaining('结束于'), findsOneWidget);
    expect(find.text('启动目标'), findsOneWidget);

    await tester.tap(find.text('启动目标'));
    await tester.pumpAndSettle();

    final goal = repo.goals.single;
    expect(goal.startDate, isNotNull);
    expect(goal.durationLabel, '3 个月');
    expect(
      goal.dueDate,
      addCalendarDuration(dateOnly(DateTime.now()), 3, DurationUnit.month),
    );
  });

  testWidgets('编辑目标时回填已保存的期限规则', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = GoalRepository(MemoryAppStorage());
    await repo.init();
    final existing = Goal(
      id: 'g',
      title: '带期限的目标',
      lifecycle: Lifecycle.pending,
      durationAmount: 3,
      durationUnit: DurationUnit.month,
    );
    repo.addGoal(existing);

    await tester.pumpWidget(
      RepositoryScope(
        repository: repo,
        child: MaterialApp(home: GoalEditorPage(goal: existing)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('期限'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('duration-field')))
          .controller
          ?.text,
      '3',
    );
    expect(find.textContaining('从开始日期起算'), findsOneWidget);
    expect(find.textContaining('结束于'), findsNothing);
    expect(find.textContaining('从今天'), findsNothing);
  });

  testWidgets('设置里切换为「截止日期」后，目标表单改用日期选择', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = GoalRepository(MemoryAppStorage());
    await repo.init();

    await tester.pumpWidget(GoalManagerApp(repository: repo));
    await tester.pumpAndSettle();

    final nav = find.byType(NavigationBar);
    await tester.tap(find.descendant(of: nav, matching: find.text('设置')));
    await tester.pumpAndSettle();
    expect(find.text('目标表单'), findsOneWidget);

    await tester.tap(find.text('截止日期'));
    await tester.pumpAndSettle();
    expect(repo.settings.dueFieldMode, DueFieldMode.deadline);

    await tester.tap(find.descendant(of: nav, matching: find.text('目标')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建目标').last);
    await tester.pumpAndSettle();

    final editor = find.byType(GoalEditorPage);
    expect(
      find.descendant(of: editor, matching: find.text('截止日期')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: editor, matching: find.text('期限')),
      findsNothing,
    );
  });

  testWidgets('窄屏下「期限」输入不溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = GoalRepository(MemoryAppStorage());
    await repo.init();

    await tester.pumpWidget(GoalManagerApp(repository: repo));
    await tester.pumpAndSettle();

    final nav = find.byType(NavigationBar);
    await tester.tap(find.descendant(of: nav, matching: find.text('目标')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建目标').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('duration-field')), '3');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('duration-field')), findsOneWidget);
  });

  testWidgets('目标列表展示最底层子目标，并可从子目标进入父目标', (tester) async {
    final repo = GoalRepository(MemoryAppStorage());
    await repo.init();
    repo.loadSample();

    await tester.pumpWidget(GoalManagerApp(repository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('目标'));
    await tester.pumpAndSettle();

    expect(find.text('发布个人作品集'), findsNothing);
    expect(find.text('完成三个案例'), findsOneWidget);

    await tester.tap(find.text('完成三个案例'));
    await tester.pumpAndSettle();
    expect(find.text('属于 发布个人作品集'), findsOneWidget);

    await tester.tap(find.text('属于 发布个人作品集'));
    await tester.pumpAndSettle();
    expect(find.text('发布个人作品集'), findsWidgets);
  });
}
