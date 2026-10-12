import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../models/shift.dart';
import '../models/shop_item.dart';
import '../providers/roster_provider.dart';
import '../providers/shop_provider.dart';

Future<void> openDayChange(BuildContext context, Schedule schedule, DateTime day) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _DaySheet(scheduleId: schedule.id, day: dateOnly(day)),
  );
}

class _DaySheet extends StatefulWidget {
  const _DaySheet({required this.scheduleId, required this.day});

  final String scheduleId;
  final DateTime day;

  @override
  State<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<_DaySheet> {
  late ShiftKind _kind;
  late final TextEditingController _note;
  var _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final schedule = context.read<RosterProvider>().find(widget.scheduleId);
    final slot = schedule == null ? null : slotOn(schedule, widget.day);
    _kind = slot?.kind ?? ShiftKind.off;
    _note = TextEditingController(text: slot?.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schedule = context.watch<RosterProvider>().find(widget.scheduleId);
    if (schedule == null) return const SizedBox.shrink();
    final planned = slotOn(
      Schedule(id: schedule.id, name: schedule.name, cycleStart: schedule.cycleStart, steps: schedule.steps),
      widget.day,
    );
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.day.day}', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800, height: 0.9)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(weekDays[widget.day.weekday - 1], style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                  Text('${monthLong[widget.day.month - 1].toUpperCase()} ${widget.day.year}', style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(border: Border.all(color: AppColors.error), borderRadius: BorderRadius.circular(8)),
                child: const Text('ONE-DAY CHANGE', style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Scheduled', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _Chip(kind: planned.kind, hours: planned.before ? 'Before the cycle starts' : planned.hours),
          const SizedBox(height: 12),
          const Text('Change to', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final kind in ShiftKind.values) ...[
                Expanded(child: _Pick(kind: kind, selected: _kind == kind, onTap: () => setState(() => _kind = kind))),
                if (kind != ShiftKind.off) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text('Only ${widget.day.day} ${monthShort[widget.day.month - 1]} changes. Your cycle stays the same.', style: const TextStyle(color: Color(0xFF5C6B80), fontSize: 13)),
          TextField(
            controller: _note,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.edit_note), hintText: 'Add a note'),
          ),
          const SizedBox(height: 8),
          const Text('Preview', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final offset in [-1, 0, 1])
                Expanded(child: Padding(padding: const EdgeInsets.only(right: 6), child: _Preview(day: widget.day.add(Duration(days: offset)), schedule: schedule, overrideKind: offset == 0 ? _kind : null, marked: offset == 0))),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const Spacer(),
              FilledButton(onPressed: () => _apply(schedule), child: Text('Apply to ${widget.day.day} ${monthShort[widget.day.month - 1]}')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _apply(Schedule schedule) async {
    final roster = context.read<RosterProvider>();
    final click = context.read<ShopProvider>().featureOn(ShopCatalog.featSound);
    if (click) await HapticFeedback.selectionClick();
    await roster.setChange(schedule.id, widget.day, _kind, _note.text);
    if (mounted) Navigator.pop(context);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.kind, required this.hours});

  final ShiftKind kind;
  final String hours;

  @override
  Widget build(BuildContext context) {
    final bg = switch (kind) {
      ShiftKind.day => AppColors.day,
      ShiftKind.night => AppColors.night,
      ShiftKind.off => AppColors.offFill,
    };
    final ink = kind == ShiftKind.day ? Colors.white : (kind == ShiftKind.night ? AppColors.nightInk : AppColors.ink);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text('${kindLetter(kind)}  ${kindLabel(kind)}   $hours', style: TextStyle(color: ink, fontWeight: FontWeight.w800)),
    );
  }
}

class _Pick extends StatelessWidget {
  const _Pick({required this.kind, required this.selected, required this.onTap});

  final ShiftKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: selected ? AppColors.primary : const Color(0xFFD5DCE8), width: selected ? 2 : 1)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(kindLetter(kind), style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(kindLabel(kind)[0] + kindLabel(kind).substring(1).toLowerCase(), style: const TextStyle(fontSize: 12)),
              if (selected) const Icon(Icons.check_circle, size: 14, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.day, required this.schedule, this.overrideKind, this.marked = false});

  final DateTime day;
  final Schedule schedule;
  final ShiftKind? overrideKind;
  final bool marked;

  @override
  Widget build(BuildContext context) {
    final slot = overrideKind == null ? slotOn(schedule, day) : slotWithKind(schedule, day, overrideKind!);
    final bg = switch (slot.kind) {
      ShiftKind.day => AppColors.day,
      ShiftKind.night => AppColors.night,
      ShiftKind.off => AppColors.offFill,
    };
    final ink = slot.kind == ShiftKind.day ? Colors.white : (slot.kind == ShiftKind.night ? AppColors.nightInk : AppColors.ink);
    final word = kindLabel(slot.kind)[0] + kindLabel(slot.kind).substring(1).toLowerCase();
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('${weekDays[day.weekday - 1]} ${day.day}', style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 11))),
              if (marked) const DecoratedBox(decoration: BoxDecoration(color: AppColors.error, shape: BoxShape.circle), child: SizedBox(width: 7, height: 7)),
            ],
          ),
          Text('${kindLetter(slot.kind)}  $word', style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 13)),
          Text(slot.before ? '' : slot.hours, style: TextStyle(color: ink, fontSize: 10)),
        ],
      ),
    );
  }
}
