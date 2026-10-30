import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goal_manager/app.dart';
import 'package:goal_manager/data/repository.dart';
import 'package:goal_manager/data/storage.dart';

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

  testWidgets('全局 FAB 打开快速记录', (tester) async {
    final repo = GoalRepository(MemoryAppStorage());
    await repo.init();

    await tester.pumpWidget(GoalManagerApp(repository: repo));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('捕获一个想法'), findsOneWidget);
    expect(find.text('新建目标'), findsOneWidget);
    expect(find.text('更新已有目标'), findsOneWidget);
  });
}
