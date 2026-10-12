import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiftlens/core/constants/iap_constants.dart';
import 'package:shiftlens/core/services/hive_service.dart';
import 'package:shiftlens/core/services/storage_service.dart';
import 'package:shiftlens/models/shift.dart';
import 'package:shiftlens/providers/roster_provider.dart';
import 'package:shiftlens/providers/shop_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('sl_roster');
    await HiveService.init(path: dir.path, suffix: '_roster');
    await StorageService.instance.init();
  });

  setUp(() async {
    await HiveService.kv.clear();
  });

  test('a 2 day / 2 night / 2 off cycle fills the week and an exception stays local', () {
    final steps = [
      CycleStep.standard('a', ShiftKind.day),
      CycleStep.standard('b', ShiftKind.day),
      CycleStep.standard('c', ShiftKind.night),
      CycleStep.standard('d', ShiftKind.night),
      CycleStep.standard('e', ShiftKind.off),
      CycleStep.standard('f', ShiftKind.off),
    ];
    expect(cycleTitle(steps), '2 day / 2 night / 2 off');
    final schedule = Schedule(id: 'mine', name: 'Mine', cycleStart: DateTime(2026, 10, 12), steps: steps);
    expect(slotOn(schedule, DateTime(2026, 10, 12)).kind, ShiftKind.day);
    expect(slotOn(schedule, DateTime(2026, 10, 13)).kind, ShiftKind.day);
    expect(slotOn(schedule, DateTime(2026, 10, 14)).kind, ShiftKind.night);
    expect(slotOn(schedule, DateTime(2026, 10, 15)).kind, ShiftKind.night);
    expect(slotOn(schedule, DateTime(2026, 10, 16)).kind, ShiftKind.off);
    expect(slotCaption(schedule, DateTime(2026, 10, 16)), 'Night shift ends 07:00');
    expect(slotCaption(schedule, DateTime(2026, 10, 17)), 'No shift starts');
    expect(slotOn(schedule, DateTime(2026, 10, 18)).kind, ShiftKind.day);
    expect(slotOn(schedule, DateTime(2026, 10, 11)).before, isTrue);

    schedule.changes.add(DayChange(date: '2026-10-14', kind: ShiftKind.off));
    expect(slotOn(schedule, DateTime(2026, 10, 14)).kind, ShiftKind.off);
    expect(slotOn(schedule, DateTime(2026, 10, 14)).exception, isTrue);
    expect(slotOn(schedule, DateTime(2026, 10, 15)).kind, ShiftKind.night);
    expect(slotOn(schedule, DateTime(2026, 10, 20)).kind, ShiftKind.night);
  });

  test('two rotas show shared days off and the free cap holds', () async {
    final shop = ShopProvider();
    await shop.init(remote: false);
    final roster = RosterProvider(shop);
    await roster.init();
    final mine = await roster.create(
      name: 'Mine',
      cycleStart: DateTime(2026, 10, 12),
      steps: roster.templateSteps(),
    );
    final partner = await roster.create(
      name: 'Alex',
      cycleStart: DateTime(2026, 10, 14),
      steps: [
        CycleStep.standard('n1', ShiftKind.night),
        CycleStep.standard('n2', ShiftKind.night),
        CycleStep.standard('o1', ShiftKind.off),
        CycleStep.standard('o2', ShiftKind.off),
        CycleStep.standard('d1', ShiftKind.day),
        CycleStep.standard('d2', ShiftKind.day),
      ],
    );
    final shared = sharedOffDays(mine!, partner!, DateTime(2026, 10, 12), 6);
    expect(shared.map(dateKey), ['2026-10-16', '2026-10-17']);
    expect(shop.coins, IapConstants.testCompleteReward * 2);

    for (var i = 0; i < IapConstants.freeArchiveLimit - 2; i++) {
      expect(await roster.create(name: 'Extra $i', cycleStart: DateTime(2026, 10, 12), steps: roster.templateSteps()), isNotNull);
    }
    expect(await roster.create(name: 'Too many', cycleStart: DateTime(2026, 10, 12), steps: roster.templateSteps()), isNull);
    expect(shop.coins, IapConstants.testCompleteReward * IapConstants.maxDayRewards);
  });
}
