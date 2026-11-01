import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goal_manager/app.dart';
import 'package:goal_manager/data/repository.dart';
import 'package:goal_manager/data/storage.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = GoalRepository(MemoryAppStorage());
    await repo.init();
    repo.loadSample();
    await tester.pumpWidget(GoalManagerApp(repository: repo));
    await tester.pumpAndSettle();
  }

  testWidgets('从更深的目标详情页一键回到主页', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('目标'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成三个案例'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('属于 发布个人作品集'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('回到主页'), findsOneWidget);
    await tester.tap(find.byTooltip('回到主页'));
    await tester.pumpAndSettle();

    expect(find.text('把注意力放在少数重要的事上'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('从目标编辑页一键回到主页', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('目标'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建'));
    await tester.pumpAndSettle();

    expect(find.text('创建目标'), findsOneWidget);
    await tester.tap(find.byTooltip('回到主页'));
    await tester.pumpAndSettle();

    expect(find.text('把注意力放在少数重要的事上'), findsOneWidget);
    expect(find.text('创建目标'), findsNothing);
  });

  testWidgets('从复盘编辑页一键回到主页', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('回顾'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建'));
    await tester.pumpAndSettle();

    expect(find.text('保存复盘'), findsOneWidget);
    await tester.tap(find.byTooltip('回到主页'));
    await tester.pumpAndSettle();

    expect(find.text('把注意力放在少数重要的事上'), findsOneWidget);
    expect(find.text('保存复盘'), findsNothing);
  });
}
