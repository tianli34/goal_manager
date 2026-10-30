import '../core/date_utils.dart';
import '../core/enums.dart';
import '../core/ids.dart';
import '../models/app_data.dart';
import '../models/commitment.dart';
import '../models/goal.dart';
import '../models/inbox_item.dart';
import '../models/review.dart';
import '../models/update_record.dart';

AppData buildSampleData({DateTime? baseTime}) {
  final now = baseTime ?? DateTime.now();
  final thisWeek = weekStart(now);
  final nextWeek = thisWeek.add(const Duration(days: 7));
  final lastWeek = thisWeek.subtract(const Duration(days: 7));

  final bookId = newId();
  final notesId = newId();
  final savingsId = newId();
  final weightId = newId();
  final writingId = newId();
  final portfolioId = newId();
  final frameworkChildId = newId();
  final casesChildId = newId();
  final launchChildId = newId();

  final goals = <Goal>[
    Goal(
      id: bookId,
      title: '读完《深度工作》',
      why: '想找回长时间专注的能力',
      successCriteria: '读完并写一页摘录',
      mechanism: Mechanism.completion,
      lifecycle: Lifecycle.active,
      startDate: now.subtract(const Duration(days: 6)),
      dueDate: now.add(const Duration(days: 5)),
      domain: '学习',
      tags: const ['阅读'],
      createdAt: now.subtract(const Duration(days: 6)),
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
    Goal(
      id: notesId,
      title: '整理旧读书笔记',
      why: '让过去的输入可以重新被用起来',
      mechanism: Mechanism.completion,
      lifecycle: Lifecycle.active,
      startDate: now.subtract(const Duration(days: 25)),
      dueDate: now.add(const Duration(days: 20)),
      domain: '学习',
      tags: const ['整理'],
      createdAt: now.subtract(const Duration(days: 25)),
      updatedAt: now.subtract(const Duration(days: 25)),
    ),
    Goal(
      id: savingsId,
      title: '今年存下 5 万元',
      why: '给自己留出可以选择的余地',
      successCriteria: '账户累计存入 50000 元',
      mechanism: Mechanism.cumulative,
      lifecycle: Lifecycle.active,
      startDate: now.subtract(const Duration(days: 60)),
      dueDate: now.add(const Duration(days: 120)),
      domain: '财务',
      tags: const ['储蓄'],
      unit: '元',
      startValue: 0,
      targetValue: 50000,
      currentValue: 12600,
      createdAt: now.subtract(const Duration(days: 60)),
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
    Goal(
      id: weightId,
      title: '体重从 78kg 到 72kg',
      why: '想恢复更轻松的体能状态',
      mechanism: Mechanism.metric,
      lifecycle: Lifecycle.active,
      startDate: now.subtract(const Duration(days: 30)),
      dueDate: now.add(const Duration(days: 90)),
      domain: '健康',
      tags: const ['体重'],
      unit: 'kg',
      startValue: 78,
      targetValue: 72,
      currentValue: 76.2,
      stableWindow: 3,
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now.subtract(const Duration(days: 3)),
    ),
    Goal(
      id: writingId,
      title: '养成晨间写作',
      why: '想把模糊的想法写清楚',
      mechanism: Mechanism.subjective,
      lifecycle: Lifecycle.active,
      domain: '创作',
      tags: const ['习惯'],
      subjectivePercent: 35,
      createdAt: now.subtract(const Duration(days: 20)),
      updatedAt: now.subtract(const Duration(days: 3)),
    ),
    Goal(
      id: portfolioId,
      title: '发布个人作品集',
      why: '让机会能找到我',
      successCriteria: '三个案例上线，网站可访问',
      mechanism: Mechanism.milestone,
      lifecycle: Lifecycle.active,
      executionMode: ExecutionMode.sequential,
      startDate: now.subtract(const Duration(days: 40)),
      dueDate: now.add(const Duration(days: 30)),
      domain: '事业',
      tags: const ['作品集'],
      createdAt: now.subtract(const Duration(days: 40)),
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
    Goal(
      id: frameworkChildId,
      title: '设计作品集框架',
      mechanism: Mechanism.completion,
      lifecycle: Lifecycle.completed,
      parentGoalId: portfolioId,
      dueDate: now.subtract(const Duration(days: 20)),
      createdAt: now.subtract(const Duration(days: 40)),
      updatedAt: now.subtract(const Duration(days: 20)),
      completedAt: now.subtract(const Duration(days: 20)),
    ),
    Goal(
      id: casesChildId,
      title: '完成三个案例',
      mechanism: Mechanism.completion,
      lifecycle: Lifecycle.active,
      parentGoalId: portfolioId,
      dueDate: now.add(const Duration(days: 10)),
      createdAt: now.subtract(const Duration(days: 20)),
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
    Goal(
      id: launchChildId,
      title: '发布上线',
      mechanism: Mechanism.completion,
      lifecycle: Lifecycle.pending,
      parentGoalId: portfolioId,
      dueDate: now.add(const Duration(days: 30)),
      createdAt: now.subtract(const Duration(days: 20)),
      updatedAt: now.subtract(const Duration(days: 20)),
    ),
  ];

  final records = <UpdateRecord>[
    UpdateRecord(
      id: newId(),
      goalId: bookId,
      type: RecordType.progress,
      timestamp: now.subtract(const Duration(days: 2)),
      note: '读到第三章，做了两页摘录',
    ),
    UpdateRecord(
      id: newId(),
      goalId: savingsId,
      type: RecordType.progress,
      timestamp: now.subtract(const Duration(days: 55)),
      delta: 4000,
      valueAfter: 4000,
      note: '季度奖金存入',
    ),
    UpdateRecord(
      id: newId(),
      goalId: savingsId,
      type: RecordType.progress,
      timestamp: now.subtract(const Duration(days: 30)),
      delta: 5000,
      valueAfter: 9000,
      note: '月度结余',
    ),
    UpdateRecord(
      id: newId(),
      goalId: savingsId,
      type: RecordType.progress,
      timestamp: now.subtract(const Duration(days: 7)),
      delta: 3000,
      valueAfter: 12000,
      note: '减少订阅支出',
    ),
    UpdateRecord(
      id: newId(),
      goalId: savingsId,
      type: RecordType.progress,
      timestamp: now.subtract(const Duration(days: 2)),
      delta: 600,
      valueAfter: 12600,
      note: '本周结余',
    ),
    UpdateRecord(
      id: newId(),
      goalId: weightId,
      type: RecordType.progress,
      timestamp: now.subtract(const Duration(days: 21)),
      reading: 77.4,
      valueAfter: 77.4,
      note: '早起空腹',
    ),
    UpdateRecord(
      id: newId(),
      goalId: weightId,
      type: RecordType.progress,
      timestamp: now.subtract(const Duration(days: 12)),
      reading: 76.9,
      valueAfter: 76.9,
      note: '开始每周三次快走',
    ),
    UpdateRecord(
      id: newId(),
      goalId: weightId,
      type: RecordType.progress,
      timestamp: now.subtract(const Duration(days: 3)),
      reading: 76.2,
      valueAfter: 76.2,
      note: '早起空腹',
    ),
    UpdateRecord(
      id: newId(),
      goalId: writingId,
      type: RecordType.progress,
      timestamp: now.subtract(const Duration(days: 18)),
      subjectivePercent: 15,
      note: '连续写了三天',
    ),
    UpdateRecord(
      id: newId(),
      goalId: writingId,
      type: RecordType.progress,
      timestamp: now.subtract(const Duration(days: 10)),
      subjectivePercent: 25,
      note: '找到固定的写作角落',
    ),
    UpdateRecord(
      id: newId(),
      goalId: writingId,
      type: RecordType.progress,
      timestamp: now.subtract(const Duration(days: 3)),
      subjectivePercent: 35,
      note: '开始能写满 500 字',
    ),
    UpdateRecord(
      id: newId(),
      goalId: frameworkChildId,
      type: RecordType.lifecycleChange,
      timestamp: now.subtract(const Duration(days: 20)),
      note: '标记完成',
    ),
    UpdateRecord(
      id: newId(),
      goalId: casesChildId,
      type: RecordType.progress,
      timestamp: now.subtract(const Duration(days: 2)),
      note: '完成案例一初稿',
    ),
  ];

  final commitments = <Commitment>[
    Commitment(
      id: newId(),
      goalId: savingsId,
      start: thisWeek,
      end: nextWeek,
      plannedAmount: 1000,
      baselineValue: 12000,
      note: '本周继续存 1000 元',
    ),
    Commitment(
      id: newId(),
      goalId: writingId,
      start: thisWeek,
      end: nextWeek,
      plannedAmount: 10,
      baselineValue: 35,
      note: '本周自评推进 10 个点',
    ),
    Commitment(
      id: newId(),
      goalId: portfolioId,
      start: thisWeek,
      end: nextWeek,
      targetChildId: casesChildId,
      note: '本周完成案例一',
    ),
  ];

  final reviews = <Review>[
    Review(
      id: newId(),
      start: lastWeek,
      end: thisWeek,
      goalIds: [savingsId, writingId],
      whatHappened: '存钱节奏稳定，但写作在周中中断了两天。',
      stillWorthPlan: true,
      planReflection: '目标仍然值得，写作需要更小的启动动作。',
      decision: ReviewDecision.adjust,
      nextStep: '把晨间写作改成每天 15 分钟起步。',
      createdAt: thisWeek.subtract(const Duration(hours: 2)),
    ),
  ];

  final inbox = <InboxItem>[
    InboxItem(
      id: newId(),
      text: '研究一下季度复盘模板',
      createdAt: now.subtract(const Duration(days: 1)),
    ),
    InboxItem(
      id: newId(),
      text: '想学做面包',
      createdAt: now.subtract(const Duration(days: 4)),
    ),
  ];

  return AppData(
    goals: goals,
    records: records,
    commitments: commitments,
    reviews: reviews,
    inbox: inbox,
  );
}
