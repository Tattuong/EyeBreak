import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/services/shift_notify.dart';
import '../core/services/storage_service.dart';
import '../models/shift.dart';
import 'shop_provider.dart';

class RosterProvider extends ChangeNotifier {
  RosterProvider(this.shop);

  static const _key = 'sl_roster';

  final ShopProvider shop;
  final _uuid = const Uuid();
  final List<Schedule> _schedules = [];
  String? _selectedId;

  List<Schedule> get schedules => List.unmodifiable(_schedules);
  bool get canAdd => _schedules.length < shop.maxArchive;

  Schedule? get selected {
    final id = _selectedId;
    if (id != null) {
      final found = find(id);
      if (found != null) return found;
    }
    return _schedules.isEmpty ? null : _schedules.first;
  }

  Schedule? find(String id) {
    for (final schedule in _schedules) {
      if (schedule.id == id) return schedule;
    }
    return null;
  }

  Future<void> init() async {
    final raw = await StorageService.instance.getData(_key);
    _schedules.clear();
    if (raw != null) {
      final list = raw['schedules'];
      if (list is List) {
        _schedules.addAll(list.whereType<Map>().map((item) => Schedule.fromJson(Map<String, dynamic>.from(item))).where((item) => item.id.isNotEmpty && item.name.trim().isNotEmpty));
      }
      _selectedId = raw['selected'] as String?;
    }
    notifyListeners();
  }

  Future<void> select(String id) async {
    _selectedId = id;
    await _save();
    notifyListeners();
  }

  List<CycleStep> templateSteps() => [
        CycleStep.standard(_uuid.v4(), ShiftKind.day),
        CycleStep.standard(_uuid.v4(), ShiftKind.day),
        CycleStep.standard(_uuid.v4(), ShiftKind.night),
        CycleStep.standard(_uuid.v4(), ShiftKind.night),
        CycleStep.standard(_uuid.v4(), ShiftKind.off),
        CycleStep.standard(_uuid.v4(), ShiftKind.off),
      ];

  Future<Schedule?> create({
    required String name,
    required DateTime cycleStart,
    required List<CycleStep> steps,
    int remindMinutes = 60,
  }) async {
    final title = name.trim();
    if (title.isEmpty || steps.isEmpty || !canAdd) return null;
    final schedule = Schedule(
      id: _uuid.v4(),
      name: title,
      cycleStart: dateOnly(cycleStart),
      remindMinutes: remindMinutes,
      steps: steps,
    );
    _schedules.add(schedule);
    _selectedId = schedule.id;
    await shop.rewardForCycle();
    await _save();
    notifyListeners();
    await ShiftNotify.sync(_schedules);
    return schedule;
  }

  Future<void> update(Schedule schedule) async {
    await _save();
    notifyListeners();
    await ShiftNotify.sync(_schedules);
  }

  Future<bool> delete(String id) async {
    _schedules.removeWhere((schedule) => schedule.id == id);
    if (_selectedId == id) _selectedId = _schedules.isEmpty ? null : _schedules.first.id;
    await _save();
    notifyListeners();
    await ShiftNotify.sync(_schedules);
    return true;
  }

  Future<void> setChange(String scheduleId, DateTime date, ShiftKind kind, String note) async {
    final schedule = find(scheduleId);
    if (schedule == null) return;
    final key = dateKey(date);
    final cycle = slotOn(Schedule(
      id: schedule.id,
      name: schedule.name,
      cycleStart: schedule.cycleStart,
      steps: schedule.steps,
    ), date);
    schedule.changes.removeWhere((change) => change.date == key);
    if (kind != cycle.kind || note.trim().isNotEmpty) {
      schedule.changes.add(DayChange(date: key, kind: kind, note: note.trim()));
    }
    await _save();
    notifyListeners();
    await ShiftNotify.sync(_schedules);
  }

  Future<void> _save() async {
    await StorageService.instance.saveData(_key, {
      'selected': _selectedId,
      'schedules': _schedules.map((schedule) => schedule.toJson()).toList(),
    });
  }
}
