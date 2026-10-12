enum ShiftKind { day, night, off }

class CycleStep {
  CycleStep({
    required this.id,
    required this.kind,
    this.start = '07:00',
    this.end = '19:00',
    this.nextDay = false,
  });

  final String id;
  ShiftKind kind;
  String start;
  String end;
  bool nextDay;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'start': start,
        'end': end,
        'nextDay': nextDay,
      };

  factory CycleStep.fromJson(Map<String, dynamic> json) => CycleStep(
        id: json['id'] as String? ?? '',
        kind: ShiftKind.values.byName(json['kind'] as String? ?? 'off'),
        start: json['start'] as String? ?? '07:00',
        end: json['end'] as String? ?? '19:00',
        nextDay: json['nextDay'] == true,
      );

  static CycleStep standard(String id, ShiftKind kind) => switch (kind) {
        ShiftKind.day => CycleStep(id: id, kind: kind, start: '07:00', end: '19:00'),
        ShiftKind.night => CycleStep(id: id, kind: kind, start: '19:00', end: '07:00', nextDay: true),
        ShiftKind.off => CycleStep(id: id, kind: kind, start: '', end: ''),
      };
}

class DayChange {
  DayChange({required this.date, required this.kind, this.note = ''});

  final String date;
  ShiftKind kind;
  String note;

  Map<String, dynamic> toJson() => {'date': date, 'kind': kind.name, 'note': note};

  factory DayChange.fromJson(Map<String, dynamic> json) => DayChange(
        date: json['date'] as String? ?? '',
        kind: ShiftKind.values.byName(json['kind'] as String? ?? 'off'),
        note: json['note'] as String? ?? '',
      );
}

class Schedule {
  Schedule({
    required this.id,
    required this.name,
    required this.cycleStart,
    this.remindMinutes = 60,
    List<CycleStep>? steps,
    List<DayChange>? changes,
  })  : steps = steps ?? [],
        changes = changes ?? [];

  final String id;
  String name;
  DateTime cycleStart;
  int remindMinutes;
  final List<CycleStep> steps;
  final List<DayChange> changes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'start': dateKey(cycleStart),
        'remind': remindMinutes,
        'steps': steps.map((step) => step.toJson()).toList(),
        'changes': changes.map((change) => change.toJson()).toList(),
      };

  factory Schedule.fromJson(Map<String, dynamic> json) => Schedule(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        cycleStart: dateFromKey(json['start'] as String? ?? '') ?? DateTime.now(),
        remindMinutes: (json['remind'] as num?)?.toInt() ?? 0,
        steps: (json['steps'] as List?)
                ?.whereType<Map>()
                .map((item) => CycleStep.fromJson(Map<String, dynamic>.from(item)))
                .where((step) => step.id.isNotEmpty)
                .toList() ??
            [],
        changes: (json['changes'] as List?)
                ?.whereType<Map>()
                .map((item) => DayChange.fromJson(Map<String, dynamic>.from(item)))
                .where((change) => change.date.isNotEmpty)
                .toList() ??
            [],
      );
}

class ShiftSlot {
  const ShiftSlot({
    required this.kind,
    required this.start,
    required this.end,
    required this.nextDay,
    required this.exception,
    required this.note,
    required this.before,
  });

  final ShiftKind kind;
  final String start;
  final String end;
  final bool nextDay;
  final bool exception;
  final String note;
  final bool before;

  bool get isOff => kind == ShiftKind.off;

  String get hours {
    if (isOff || start.isEmpty) return kind == ShiftKind.off ? 'No shift starts' : '';
    final extra = nextDay ? '  (+1 day)' : '';
    return '$start – $end$extra';
  }
}

String slotCaption(Schedule schedule, DateTime date) {
  final slot = slotOn(schedule, date);
  if (slot.before) return '';
  if (slot.note.trim().isNotEmpty) return slot.note.trim();
  if (slot.isOff) {
    final end = _nightSpillEnd(schedule, date);
    return end == null ? 'No shift starts' : 'Night shift ends $end';
  }
  return slot.hours;
}

String? _nightSpillEnd(Schedule schedule, DateTime date) {
  final previous = slotOn(schedule, date.subtract(const Duration(days: 1)));
  if (previous.before || previous.kind != ShiftKind.night || !previous.nextDay || previous.end.isEmpty) return null;
  return previous.end;
}

ShiftSlot slotWithKind(Schedule schedule, DateTime date, ShiftKind kind) {
  final slot = slotOn(schedule, date);
  if (slot.kind == kind) return slot;
  final times = _timesFor(schedule, kind);
  return ShiftSlot(
    kind: kind,
    start: times.$1,
    end: times.$2,
    nextDay: times.$3,
    exception: true,
    note: slot.note,
    before: false,
  );
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String dateKey(DateTime date) {
  final day = dateOnly(date);
  final month = day.month.toString().padLeft(2, '0');
  final dom = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$dom';
}

DateTime? dateFromKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

DateTime startOfWeek(DateTime date) {
  final day = dateOnly(date);
  return day.subtract(Duration(days: day.weekday - 1));
}

String cycleTitle(List<CycleStep> steps) {
  if (steps.isEmpty) return 'Empty cycle';
  final parts = <String>[];
  var count = 1;
  for (var i = 1; i <= steps.length; i++) {
    final same = i < steps.length && steps[i].kind == steps[i - 1].kind;
    if (same) {
      count++;
      continue;
    }
    final word = switch (steps[i - 1].kind) {
      ShiftKind.day => 'day',
      ShiftKind.night => 'night',
      ShiftKind.off => 'off',
    };
    parts.add('$count $word');
    count = 1;
  }
  return parts.join(' / ');
}

ShiftSlot slotOn(Schedule schedule, DateTime date) {
  final day = dateOnly(date);
  final key = dateKey(day);
  DayChange? change;
  for (final item in schedule.changes) {
    if (item.date == key) change = item;
  }
  if (change != null) {
    final times = _timesFor(schedule, change.kind);
    return ShiftSlot(
      kind: change.kind,
      start: times.$1,
      end: times.$2,
      nextDay: times.$3,
      exception: true,
      note: change.note,
      before: false,
    );
  }
  final index = day.difference(dateOnly(schedule.cycleStart)).inDays;
  if (schedule.steps.isEmpty || index < 0) {
    return const ShiftSlot(kind: ShiftKind.off, start: '', end: '', nextDay: false, exception: false, note: '', before: true);
  }
  final step = schedule.steps[index % schedule.steps.length];
  return ShiftSlot(
    kind: step.kind,
    start: step.start,
    end: step.end,
    nextDay: step.nextDay,
    exception: false,
    note: '',
    before: false,
  );
}

(String, String, bool) _timesFor(Schedule schedule, ShiftKind kind) {
  for (final step in schedule.steps) {
    if (step.kind == kind) return (step.start, step.end, step.nextDay);
  }
  final sample = CycleStep.standard('tmp', kind);
  return (sample.start, sample.end, sample.nextDay);
}

List<DateTime> sharedOffDays(Schedule a, Schedule b, DateTime from, int days) {
  final start = dateOnly(from);
  final found = <DateTime>[];
  for (var i = 0; i < days; i++) {
    final day = start.add(Duration(days: i));
    final left = slotOn(a, day);
    final right = slotOn(b, day);
    if (!left.before && !right.before && left.isOff && right.isOff) found.add(day);
  }
  return found;
}

const weekDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const monthShort = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
const monthLong = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

String kindLabel(ShiftKind kind) => switch (kind) {
      ShiftKind.day => 'DAY',
      ShiftKind.night => 'NIGHT',
      ShiftKind.off => 'OFF',
    };

String kindLetter(ShiftKind kind) => switch (kind) {
      ShiftKind.day => 'D',
      ShiftKind.night => 'N',
      ShiftKind.off => 'O',
    };
