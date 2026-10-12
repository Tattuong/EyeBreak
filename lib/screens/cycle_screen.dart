import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../core/navigation/app_navigator.dart';
import '../models/shift.dart';
import '../providers/roster_provider.dart';
import '../providers/shop_provider.dart';
import '../widgets/app_toast.dart';

class CycleScreen extends StatefulWidget {
  const CycleScreen({super.key, this.scheduleId});

  final String? scheduleId;

  @override
  State<CycleScreen> createState() => _CycleScreenState();
}

class _CycleScreenState extends State<CycleScreen> {
  final _name = TextEditingController(text: 'Mine');
  final _steps = <CycleStep>[];
  DateTime _start = dateOnly(DateTime.now());
  int _remind = 60;
  var _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final roster = context.read<RosterProvider>();
    final existing = widget.scheduleId == null ? null : roster.find(widget.scheduleId!);
    if (existing == null) {
      _steps.addAll(roster.templateSteps());
      return;
    }
    _name.text = existing.name;
    _start = dateOnly(existing.cycleStart);
    _remind = existing.remindMinutes;
    _steps.addAll(existing.steps.map((step) => CycleStep(id: step.id, kind: step.kind, start: step.start, end: step.end, nextDay: step.nextDay)));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.editor,
      appBar: AppBar(
        backgroundColor: AppColors.editor,
        foregroundColor: Colors.white,
        title: const Text('CYCLE EDITOR', style: TextStyle(fontSize: 13, letterSpacing: 1.1)),
        actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                TextField(
                  controller: _name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(cycleTitle(_steps), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1.05)),
                const SizedBox(height: 16),
                for (var i = 0; i < _steps.length; i++) _step(i),
                TextButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Add a step', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.loop, color: Colors.white54, size: 18),
                    SizedBox(width: 8),
                    Text('Repeat', style: TextStyle(color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cycle starts', style: TextStyle(color: Colors.white70)),
                  trailing: Text(_long(_start), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  onTap: _pickStart,
                ),
                const Text('Remind me', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final item in const [(0, 'Off'), (30, '30 min'), (60, '1 hour'), (180, '3 hours')])
                      ChoiceChip(
                        label: Text(item.$2, style: TextStyle(color: _remind == item.$1 ? AppColors.editor : Colors.white, fontWeight: FontWeight.w700)),
                        selected: _remind == item.$1,
                        selectedColor: Colors.white,
                        backgroundColor: const Color(0xFF1A2C44),
                        side: BorderSide.none,
                        onSelected: (_) => setState(() => _remind = item.$1),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
                const Spacer(),
                FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.editor, minimumSize: const Size(140, 48)),
                  child: const Text('Save cycle', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(int index) {
    final step = _steps[index];
    final color = switch (step.kind) {
      ShiftKind.day => AppColors.day,
      ShiftKind.night => AppColors.night,
      ShiftKind.off => const Color(0xFF24344A),
    };
    final ink = step.kind == ShiftKind.night ? AppColors.nightInk : Colors.white;
    final last = index == _steps.length - 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Text('${index + 1}'.padLeft(2, '0'), style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w800)),
                Container(width: 2, height: last ? 18 : 46, color: Colors.white24),
              ],
            ),
          ),
          Expanded(
            child: Material(
              color: color,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _edit(index),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                  child: Row(
                    children: [
                      Text(kindLetter(step.kind), style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(kindLabel(step.kind), style: TextStyle(color: ink, fontWeight: FontWeight.w800)),
                            Text(step.kind == ShiftKind.off ? 'No shift starts' : '${step.start} – ${step.end}${step.nextDay ? '  (+1 day)' : ''}', style: TextStyle(color: ink.withValues(alpha: 0.8), fontSize: 12)),
                          ],
                        ),
                      ),
                      _Nudge(icon: Icons.arrow_upward, color: ink, onTap: index == 0 ? null : () => setState(() { final item = _steps.removeAt(index); _steps.insert(index - 1, item); })),
                      _Nudge(icon: Icons.arrow_downward, color: ink, onTap: last ? null : () => setState(() { final item = _steps.removeAt(index); _steps.insert(index + 1, item); })),
                      _Nudge(icon: Icons.edit_outlined, color: ink, onTap: () => _edit(index)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _add() async {
    final kind = await showModalBottomSheet<ShiftKind>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final kind in ShiftKind.values)
              ListTile(title: Text(kindLabel(kind)), onTap: () => Navigator.pop(context, kind)),
          ],
        ),
      ),
    );
    if (kind == null) return;
    setState(() => _steps.add(CycleStep.standard(const Uuid().v4(), kind)));
  }

  Future<void> _edit(int index) async {
    final next = await showDialog<CycleStep>(
      context: context,
      builder: (_) => _StepDialog(
        step: _steps[index],
        onDelete: _steps.length < 2
            ? null
            : () => Navigator.pop(context, CycleStep(id: '', kind: ShiftKind.off)),
      ),
    );
    if (next == null) return;
    if (next.id.isEmpty) {
      setState(() => _steps.removeAt(index));
      return;
    }
    setState(() => _steps[index] = next);
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(context: context, initialDate: _start, firstDate: DateTime(2020), lastDate: DateTime(2035));
    if (picked == null) return;
    setState(() => _start = dateOnly(picked));
  }

  Future<void> _save() async {
    final roster = context.read<RosterProvider>();
    final existing = widget.scheduleId == null ? null : roster.find(widget.scheduleId!);
    if (existing == null) {
      final created = await roster.create(name: _name.text, cycleStart: _start, steps: [..._steps], remindMinutes: _remind);
      if (!mounted) return;
      if (created == null) {
        final shop = context.read<ShopProvider>();
        AppToast.show(context, title: _name.text.trim().isEmpty || _steps.isEmpty ? 'Add a name and one step' : AppStrings.t(context, 'needProFlows', {'n': '${shop.maxArchive}'}), actionLabel: 'Shop', onAction: AppTabs.goShop);
        return;
      }
    } else {
      existing.name = _name.text.trim().isEmpty ? existing.name : _name.text.trim();
      existing.cycleStart = _start;
      existing.remindMinutes = _remind;
      existing.steps
        ..clear()
        ..addAll(_steps);
      await roster.update(existing);
    }
    if (mounted) Navigator.pop(context);
  }

  String _long(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[date.weekday - 1]}, ${date.day} ${monthShort[date.month - 1]} ${date.year}';
  }
}

class _Nudge extends StatelessWidget {
  const _Nudge({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 16,
      child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, color: onTap == null ? color.withValues(alpha: 0.25) : color, size: 18)),
    );
  }
}

class _StepDialog extends StatefulWidget {
  const _StepDialog({required this.step, this.onDelete});

  final CycleStep step;
  final VoidCallback? onDelete;

  @override
  State<_StepDialog> createState() => _StepDialogState();
}

class _StepDialogState extends State<_StepDialog> {
  late ShiftKind _kind = widget.step.kind;
  late final _start = TextEditingController(text: widget.step.start);
  late final _end = TextEditingController(text: widget.step.end);
  late bool _nextDay = widget.step.nextDay;

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit step'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final kind in ShiftKind.values)
                ChoiceChip(label: Text(kindLabel(kind)), selected: _kind == kind, onSelected: (_) => setState(() => _applyKind(kind))),
            ],
          ),
          if (_kind != ShiftKind.off) ...[
            TextField(controller: _start, decoration: const InputDecoration(labelText: 'Starts'), keyboardType: TextInputType.datetime),
            TextField(controller: _end, decoration: const InputDecoration(labelText: 'Ends'), keyboardType: TextInputType.datetime),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Ends next day'), value: _nextDay, onChanged: (value) => setState(() => _nextDay = value)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: widget.onDelete, child: const Text('Delete')),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            CycleStep(
              id: widget.step.id,
              kind: _kind,
              start: _kind == ShiftKind.off ? '' : _clean(_start.text, '07:00'),
              end: _kind == ShiftKind.off ? '' : _clean(_end.text, '19:00'),
              nextDay: _kind == ShiftKind.off ? false : _nextDay,
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _applyKind(ShiftKind kind) {
    final sample = CycleStep.standard(widget.step.id, kind);
    _kind = kind;
    _start.text = sample.start;
    _end.text = sample.end;
    _nextDay = sample.nextDay;
  }

  String _clean(String raw, String fallback) {
    final parts = raw.trim().split(':');
    if (parts.length != 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}
