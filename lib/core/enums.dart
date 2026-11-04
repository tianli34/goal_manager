enum Mechanism {
  completion('完成型', '做完即达成，无中间进度'),
  cumulative('累积型', '往目标总量上累加，可增可减'),
  metric('指标型', '读数从起点走向目标，会波动回退'),
  subjective('主观型', '以时间线记录为主，进度由自己判断'),
  milestone('里程碑型', '由子项组成，进度从子项上卷');

  const Mechanism(this.label, this.description);

  final String label;
  final String description;

  static Mechanism parse(String? value) => values.firstWhere(
    (e) => e.name == value,
    orElse: () => Mechanism.completion,
  );
}

enum Lifecycle {
  pending('未激活'),
  active('进行中'),
  paused('暂停'),
  completed('已完成'),
  terminated('已终止');

  const Lifecycle(this.label);

  final String label;

  bool get isFinished => this == completed || this == terminated;

  static Lifecycle parse(String? value) =>
      values.firstWhere((e) => e.name == value, orElse: () => Lifecycle.active);
}

enum AttentionSignal {
  noRecentUpdate('许久未记录', '更新 / 确认无变化'),
  possibleStall('可能停滞', '写说明 / 检查计划'),
  dateRisk('日期风险', '调整范围 / 日期 / 承诺'),
  insufficientData('数据不足', '记录读数');

  const AttentionSignal(this.label, this.action);

  final String label;
  final String action;
}

enum ReviewDecision {
  continuePlan('继续'),
  adjust('调整'),
  pause('暂停'),
  end('结束');

  const ReviewDecision(this.label);

  final String label;

  static ReviewDecision parse(String? value) => values.firstWhere(
    (e) => e.name == value,
    orElse: () => ReviewDecision.continuePlan,
  );
}

enum RecordType {
  progress('推进'),
  configChange('配置变更'),
  reopen('重新打开'),
  lifecycleChange('状态变更');

  const RecordType(this.label);

  final String label;

  static RecordType parse(String? value) => values.firstWhere(
    (e) => e.name == value,
    orElse: () => RecordType.progress,
  );
}

enum ExecutionMode {
  parallel('并列'),
  sequential('串行');

  const ExecutionMode(this.label);

  final String label;

  static ExecutionMode parse(String? value) => values.firstWhere(
    (e) => e.name == value,
    orElse: () => ExecutionMode.parallel,
  );
}

/// 新建 / 编辑目标时，「结束时间」用哪种方式填写。
/// duration 是时间跨度（如三个月），deadline 是时间点（某个日期）。
enum DueFieldMode {
  duration('期限', '填一段时长；有开始日期时推算结束日期，没有则先保留规则'),
  deadline('截止日期', '直接选择一个结束日期');

  const DueFieldMode(this.label, this.description);

  final String label;
  final String description;

  /// 旧备份没有该字段、或字段值非法时，一律回落到默认的「期限」。
  static DueFieldMode parse(String? value) => values.firstWhere(
    (e) => e.name == value,
    orElse: () => DueFieldMode.duration,
  );
}

enum CommitmentStatus {
  active('进行中'),
  fulfilled('已兑现'),
  adjusted('已调整'),
  cancelled('已取消');

  const CommitmentStatus(this.label);

  final String label;

  static CommitmentStatus parse(String? value) => values.firstWhere(
    (e) => e.name == value,
    orElse: () => CommitmentStatus.active,
  );
}
