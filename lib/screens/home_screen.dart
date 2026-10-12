import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/constants/app_colors.dart';
import '../core/navigation/app_navigator.dart';
import '../models/shift.dart';
import '../models/shop_item.dart';
import '../providers/roster_provider.dart';
import '../providers/shop_provider.dart';
import '../widgets/ad_banner_slot.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_ui.dart';
import '../widgets/coin_balance_chip.dart';
import 'cycle_screen.dart';
import 'day_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  DateTime _anchor = startOfWeek(DateTime.now());
  var _month = false;
  var _awake = false;
  final _shareKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (context.read<ShopProvider>().featureOn(ShopCatalog.featAwake)) {
        _awake = true;
        await WakelockPlus.enable();
      }
    });
  }

  @override
  void dispose() {
    if (_awake) WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roster = context.watch<RosterProvider>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _Schedule(
                    anchor: _anchor,
                    month: _month,
                    shareKey: _shareKey,
                    onWeek: (next) => setState(() => _anchor = next),
                    onMonth: (value) => setState(() => _month = value),
                  ),
                  const _Compare(),
                  const _More(),
                ],
              ),
            ),
            const AdBannerSlot(),
            _Nav(
              index: _tab,
              onSelect: (index) => setState(() => _tab = index),
              onShare: roster.selected == null ? null : () => _share(roster.selected!),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(Schedule schedule) async {
    if (_tab != 0 || _month) {
      setState(() {
        _tab = 0;
        _month = false;
      });
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    final boundary = _shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      AppToast.show(context, title: 'Open the week, then share');
      return;
    }
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (!mounted || data == null) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/shiftlens-week.png');
    await file.writeAsBytes(data.buffer.asUint8List());
    await Share.shareXFiles([XFile(file.path)], text: '${schedule.name} · ${cycleTitle(schedule.steps)}');
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Container(width: 8, height: 18, decoration: BoxDecoration(color: AppColors.day, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Container(width: 8, height: 18, decoration: BoxDecoration(color: AppColors.night, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text('ShiftLens', style: AppTypography.title(size: 22, context: context)),
          const Spacer(),
          const CoinBalanceChip(variant: CoinChipVariant.header),
          const IconButton(visualDensity: VisualDensity.compact, onPressed: AppTabs.goSettings, icon: Icon(Icons.settings_outlined)),
        ],
      ),
    );
  }
}

class _Schedule extends StatelessWidget {
  const _Schedule({required this.anchor, required this.month, required this.shareKey, required this.onWeek, required this.onMonth});

  final DateTime anchor;
  final bool month;
  final GlobalKey shareKey;
  final ValueChanged<DateTime> onWeek;
  final ValueChanged<bool> onMonth;

  @override
  Widget build(BuildContext context) {
    final roster = context.watch<RosterProvider>();
    final schedule = roster.selected;
    if (schedule == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('No cycle yet.', style: AppTypography.archivo(size: 34, weight: FontWeight.w800, color: AppColors.inkOf(context))),
          const SizedBox(height: 8),
          Text('Set the rotation once. ShiftLens fills the months, and you only edit the days that change.', style: AppTypography.body(size: 15, context: context)),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => _edit(context), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: const Text('Create a cycle')),
        ],
      );
    }
    final today = dateOnly(DateTime.now());
    final days = [for (var i = 0; i < 7; i++) anchor.add(Duration(days: i))];
    final ink = AppColors.inkOf(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${today.day}', style: AppTypography.archivo(size: 54, weight: FontWeight.w800, height: 0.85, color: ink)),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${monthShort[today.month - 1]}\n${today.year}', style: TextStyle(fontWeight: FontWeight.w800, height: 1.05, color: ink)),
            ),
            const Spacer(),
            DecoratedBox(
              decoration: BoxDecoration(color: const Color(0xFFF4F6FA), borderRadius: BorderRadius.circular(14)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(visualDensity: VisualDensity.compact, onPressed: () => onWeek(anchor.subtract(const Duration(days: 7))), icon: const Icon(Icons.chevron_left)),
                  IconButton(visualDensity: VisualDensity.compact, onPressed: () => onWeek(anchor.add(const Duration(days: 7))), icon: const Icon(Icons.chevron_right)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(_range(days), style: AppTypography.body(size: 13, context: context)),
            const Spacer(),
            _Mode(label: 'Week', on: !month, onTap: () => onMonth(false)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('/', style: TextStyle(color: AppColors.mutedInk(context)))),
            _Mode(label: 'Month', on: month, onTap: () => onMonth(true)),
          ],
        ),
        const _Legend(),
        const SizedBox(height: 8),
        if (!month)
          RepaintBoundary(
            key: shareKey,
            child: ColoredBox(
              color: AppColors.canvasOf(context),
              child: Column(
                children: [
                  for (final day in days) _DayRow(schedule: schedule, day: day),
                ],
              ),
            ),
          )
        else
          for (var i = 0; i < 120; i++) _StripRow(schedule: schedule, day: anchor.add(Duration(days: i))),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.loop, size: 18, color: AppColors.mutedInk(context)),
            const SizedBox(width: 6),
            Expanded(child: Text('Repeats every ${schedule.steps.length} days', style: AppTypography.body(size: 13, context: context))),
            TextButton(onPressed: () => _edit(context, schedule.id), child: const Text('Edit cycle  ›')),
          ],
        ),
      ],
    );
  }

  String _range(List<DateTime> days) {
    final first = days.first;
    final last = days.last;
    if (first.month == last.month) return '${first.day} – ${last.day} ${monthShort[last.month - 1]}';
    return '${first.day} ${monthShort[first.month - 1]} – ${last.day} ${monthShort[last.month - 1]}';
  }
}

class _Mode extends StatelessWidget {
  const _Mode({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = on ? AppColors.inkOf(context) : AppColors.mutedInk(context);
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: on ? ink : Colors.transparent, width: 2))),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(label, style: TextStyle(fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: ink)),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _Dot(color: AppColors.day, label: 'D  Day'),
        SizedBox(width: 12),
        _Dot(color: AppColors.night, label: 'N  Night'),
        SizedBox(width: 12),
        _Dot(color: AppColors.offFill, label: 'O  Off', hatch: true),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.label, this.hatch = false});

  final Color color;
  final String label;
  final bool hatch;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            width: 12,
            height: 12,
            child: CustomPaint(
              painter: hatch ? const _HatchPainter() : null,
              child: DecoratedBox(decoration: BoxDecoration(color: hatch ? color.withValues(alpha: 0.35) : color, border: Border.all(color: const Color(0xFFD5DCE8)), borderRadius: BorderRadius.circular(3))),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.schedule, required this.day});

  final Schedule schedule;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final slot = slotOn(schedule, day);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: slot.before ? null : () => openDayChange(context, schedule, day),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(weekDays[day.weekday - 1], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  Text('${day.day}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1)),
                ],
              ),
            ),
            Expanded(child: _ShiftCard(slot: slot, caption: slotCaption(schedule, day))),
          ],
        ),
      ),
    );
  }
}

class _StripRow extends StatelessWidget {
  const _StripRow({required this.schedule, required this.day});

  final Schedule schedule;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final slot = slotOn(schedule, day);
    return InkWell(
      onTap: slot.before ? null : () => openDayChange(context, schedule, day),
      child: _ShiftCard(slot: slot, compact: true, label: '${weekDays[day.weekday - 1]} ${day.day}', caption: slotCaption(schedule, day)),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.slot, this.compact = false, this.label, this.caption = ''});

  final ShiftSlot slot;
  final bool compact;
  final String? label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final bg = switch (slot.kind) {
      ShiftKind.day => AppColors.day,
      ShiftKind.night => AppColors.night,
      ShiftKind.off => AppColors.offFill,
    };
    final ink = slot.kind == ShiftKind.day ? Colors.white : (slot.kind == ShiftKind.night ? AppColors.nightInk : const Color(0xFF5C6B80));
    final text = slot.before ? 'Before the cycle' : kindLabel(slot.kind);
    final detail = slot.before ? '' : caption;
    final hatched = slot.kind == ShiftKind.off && !slot.before;
    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 0 : 12),
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: bg)),
          if (hatched) const Positioned.fill(child: CustomPaint(painter: _HatchPainter())),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 7 : 12),
            child: Row(
              children: [
                if (label != null) ...[
                  SizedBox(width: 64, child: Text(label!, style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 12))),
                ],
                Text(slot.before ? '–' : kindLetter(slot.kind), style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: compact ? 14 : 18)),
                const SizedBox(width: 8),
                Expanded(child: Text(text, style: TextStyle(color: ink, fontWeight: FontWeight.w800))),
                if (slot.exception) ...[
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                ],
                if (detail.isNotEmpty) Flexible(child: Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink, fontSize: 12))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  const _HatchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC3CBD6)
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Compare extends StatelessWidget {
  const _Compare();

  @override
  Widget build(BuildContext context) {
    final roster = context.watch<RosterProvider>();
    if (roster.schedules.length < 2) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Compare', style: AppTypography.archivo(size: 32, weight: FontWeight.w800, color: AppColors.inkOf(context))),
          const SizedBox(height: 8),
          Text('Add a second schedule on this phone to see the days you both have off.', style: AppTypography.body(size: 15, context: context)),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => _edit(context), child: const Text('Add a schedule')),
        ],
      );
    }
    return const _CompareBody();
  }
}

class _CompareBody extends StatefulWidget {
  const _CompareBody();

  @override
  State<_CompareBody> createState() => _CompareBodyState();
}

class _CompareBodyState extends State<_CompareBody> {
  String? _a;
  String? _b;

  @override
  Widget build(BuildContext context) {
    final roster = context.watch<RosterProvider>();
    final ids = roster.schedules.map((item) => item.id).toList();
    _a ??= ids.first;
    _b ??= ids.length > 1 ? ids[1] : ids.first;
    if (!ids.contains(_a)) _a = ids.first;
    if (!ids.contains(_b)) _b = ids.last;
    final left = roster.find(_a!)!;
    final right = roster.find(_b!)!;
    final shared = sharedOffDays(left, right, DateTime.now(), 60);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Text('Days off together', style: AppTypography.archivo(size: 28, weight: FontWeight.w800, color: AppColors.inkOf(context))),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _Picker(value: _a!, schedules: roster.schedules, onChanged: (id) => setState(() => _a = id))),
            const SizedBox(width: 8),
            Expanded(child: _Picker(value: _b!, schedules: roster.schedules, onChanged: (id) => setState(() => _b = id))),
          ],
        ),
        const SizedBox(height: 12),
        if (left.id != right.id) _PairWeek(left: left, right: right),
        if (left.id == right.id)
          Text('Pick two different schedules.', style: AppTypography.body(size: 14, context: context))
        else if (shared.isEmpty)
          Text('No shared day off in the next 60 days.', style: AppTypography.body(size: 14, context: context))
        else
          for (final day in shared)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available),
              title: Text('${weekDays[day.weekday - 1]} ${day.day} ${monthShort[day.month - 1]}'),
              subtitle: const Text('Both off'),
            ),
      ],
    );
  }
}

class _PairWeek extends StatelessWidget {
  const _PairWeek({required this.left, required this.right});

  final Schedule left;
  final Schedule right;

  @override
  Widget build(BuildContext context) {
    final start = startOfWeek(DateTime.now());
    return Column(
      children: [
        for (var i = 0; i < 7; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(width: 42, child: Text('${weekDays[start.add(Duration(days: i)).weekday - 1]}\n${start.add(Duration(days: i)).day}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, height: 1.1))),
                Expanded(child: _ShiftCard(slot: slotOn(left, start.add(Duration(days: i))), compact: true, caption: left.name)),
                const SizedBox(width: 6),
                Expanded(child: _ShiftCard(slot: slotOn(right, start.add(Duration(days: i))), compact: true, caption: right.name)),
              ],
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({required this.value, required this.schedules, required this.onChanged});

  final String value;
  final List<Schedule> schedules;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      isExpanded: true,
      value: value,
      items: [for (final schedule in schedules) DropdownMenuItem(value: schedule.id, child: Text(schedule.name))],
      onChanged: (id) { if (id != null) onChanged(id); },
    );
  }
}

class _More extends StatelessWidget {
  const _More();

  @override
  Widget build(BuildContext context) {
    final roster = context.watch<RosterProvider>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Text('Schedules', style: AppTypography.archivo(size: 32, weight: FontWeight.w800, color: AppColors.inkOf(context))),
        const SizedBox(height: 8),
        for (final schedule in roster.schedules)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(schedule.name),
            subtitle: Text('${cycleTitle(schedule.steps)} · reminds ${_remind(schedule.remindMinutes)}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Delete ${schedule.name}?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok == true) await roster.delete(schedule.id);
              },
            ),
            onTap: () {
              roster.select(schedule.id);
              _edit(context, schedule.id);
            },
          ),
        FilledButton(onPressed: () => _edit(context), child: const Text('Add a schedule')),
        const SizedBox(height: 8),
        Text('Reminders stay on this phone. ShiftLens does not upload the rota.', style: AppTypography.body(size: 13, context: context)),
      ],
    );
  }

  String _remind(int minutes) {
    if (minutes <= 0) return 'off';
    if (minutes < 60) return '$minutes min before';
    return '${minutes ~/ 60} h before';
  }
}

class _Nav extends StatelessWidget {
  const _Nav({required this.index, required this.onSelect, required this.onShare});

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    const labels = ['Schedule', 'Compare', 'More'];
    const icons = [Icons.calendar_month, Icons.compare_arrows, Icons.more_horiz];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 6),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onSelect(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icons[i], color: index == i ? AppColors.primary : AppColors.mutedInk(context)),
                      Text(labels[i], style: TextStyle(fontSize: 12, fontWeight: index == i ? FontWeight.w800 : FontWeight.w600, color: index == i ? AppColors.primary : AppColors.mutedInk(context))),
                    ],
                  ),
                ),
              ),
            Container(width: 1, height: 28, color: const Color(0xFFD5DCE8)),
            InkWell(
              onTap: onShare,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.ios_share, color: onShare == null ? AppColors.mutedInk(context) : AppColors.inkOf(context)),
                    Text('Share', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: onShare == null ? AppColors.mutedInk(context) : AppColors.inkOf(context))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _edit(BuildContext context, [String? id]) {
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => CycleScreen(scheduleId: id)));
}
