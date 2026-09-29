import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/workforce_models.dart';

class ScheduleBoard extends StatelessWidget {
  const ScheduleBoard({
    super.key,
    required this.shifts,
    required this.staff,
    required this.assignments,
    required this.start,
    required this.days,
    required this.zone,
    required this.roleFirst,
    required this.canEdit,
    required this.onEdit,
    required this.onMove,
    required this.onAssign,
  });
  final List<WorkShift> shifts;
  final List<WorkStaff> staff;
  final List<ShiftAssignment> assignments;
  final DateTime start;
  final int days;
  final String zone;
  final bool roleFirst, canEdit;
  final void Function(WorkShift) onEdit;
  final void Function(WorkShift, DateTime) onMove;
  final void Function(WorkShift, WorkStaff) onAssign;
  @override
  Widget build(BuildContext context) {
    final location = tz.getLocation(zone);
    final groups = roleFirst
        ? shifts.map((s) => s.roleKey).toSet().toList()
        : ['open', ...staff.map((s) => s.id)];
    if (groups.isEmpty) groups.add('open');
    final roster = <String, String>{
      'open': 'Unassigned',
      for (final s in staff) s.id: s.displayName,
    };
    final width = MediaQuery.sizeOf(context).width < 600 ? 180.0 : 220.0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 180 + days * width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 180,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Roster / role'),
                  ),
                ),
                for (var day = 0; day < days; day++)
                  SizedBox(
                    width: width,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        DateFormat('EEE, MMM d')
                            .format(start.add(Duration(days: day))),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
              ],
            ),
            for (final group in groups)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 180,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _roster(
                          context,
                          group,
                          roleFirst ? group : roster[group] ?? group,
                        ),
                      ),
                    ),
                    for (var day = 0; day < days; day++)
                      SizedBox(
                        width: width,
                        child: _cell(
                          context,
                          group,
                          start.add(Duration(days: day)),
                          location,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _roster(BuildContext context, String id, String name) {
    final label = Text(
      name.replaceAll('_', ' '),
      style: Theme.of(context).textTheme.titleSmall,
    );
    final matching = staff.where((s) => s.id == id);
    if (!canEdit || roleFirst || matching.isEmpty) return label;
    return Draggable<WorkStaff>(
      data: matching.first,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        child: Padding(padding: const EdgeInsets.all(16), child: Text(name)),
      ),
      child: Semantics(
        label:
            '$name. Drag onto a shift to assign, or use the shift assignment button.',
        child: label,
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    String group,
    DateTime date,
    tz.Location location,
  ) {
    final dayStart = tz.TZDateTime(location, date.year, date.month, date.day);
    final dayEnd = tz.TZDateTime(location, date.year, date.month, date.day + 1);
    final visible = shifts.where((s) {
      if (!s.startsAt.isBefore(dayEnd) || !s.endsAt.isAfter(dayStart)) {
        return false;
      }
      if (roleFirst) return s.roleKey == group;
      final assigned = assignments.where(
        (a) => a.shiftId == s.id && a.status == 'assigned',
      );
      return group == 'open'
          ? assigned.isEmpty
          : assigned.any((a) => a.staffId == group);
    }).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return DragTarget<WorkShift>(
      onWillAcceptWithDetails: (details) =>
          canEdit &&
          (roleFirst
              ? details.data.roleKey == group
              : group == 'open'
              ? !assignments.any(
                  (a) => a.shiftId == details.data.id && a.status == 'assigned',
                )
              : assignments.any(
                  (a) =>
                      a.shiftId == details.data.id &&
                      a.staffId == group &&
                      a.status == 'assigned',
                )),
      onAcceptWithDetails: (details) => onMove(details.data, date),
      builder: (context, candidates, rejected) => Container(
        constraints: const BoxConstraints(minHeight: 90),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: candidates.isEmpty
              ? Theme.of(context).colorScheme.surfaceContainerLowest
              : Theme.of(context).colorScheme.primaryContainer,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final s in visible)
              _card(context, s, location, dayStart, dayEnd),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('—', textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context,
    WorkShift s,
    tz.Location location,
    DateTime dayStart,
    DateTime dayEnd,
  ) {
    final a = tz.TZDateTime.from(s.startsAt, location),
        b = tz.TZDateTime.from(s.endsAt, location);
    final names = assignments
        .where((x) => x.shiftId == s.id && x.status == 'assigned')
        .map(
          (x) =>
              staff.where((p) => p.id == x.staffId).firstOrNull?.displayName ??
              'Employee',
        )
        .join(', ');
    final card = Card(
      child: InkWell(
        onTap: () => onEdit(s),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.roleKey.replaceAll('_', ' '),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                '${DateFormat.jm().format(a)} – ${DateFormat.jm().format(b)}',
              ),
              if (s.startsAt.isBefore(dayStart))
                const Text('Continued from prior day'),
              if (s.endsAt.isAfter(dayEnd)) const Text('Continues overnight'),
              Text(
                '${s.status.toUpperCase()} · ${names.isEmpty ? 'Open' : names}',
              ),
              Text(
                '${assignments.where((x) => x.shiftId == s.id && x.status == 'assigned').length} / ${s.headcount} positions',
              ),
              if (s.instructions.isNotEmpty)
                Text(
                  s.instructions,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              TextButton(
                onPressed: () => onEdit(s),
                child: Text(canEdit ? 'Edit / assign' : 'Shift details'),
              ),
            ],
          ),
        ),
      ),
    );
    final target = DragTarget<WorkStaff>(
      onWillAcceptWithDetails: (_) => canEdit,
      onAcceptWithDetails: (details) => onAssign(s, details.data),
      builder: (context, candidates, rejected) => card,
    );
    if (!canEdit) return target;
    return LongPressDraggable<WorkShift>(
      data: s,
      delay: const Duration(milliseconds: 150),
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 200,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('${s.roleKey} · move shift'),
          ),
        ),
      ),
      child: Semantics(
        label:
            '${s.roleKey}, ${s.status}, ${DateFormat.jm().format(a)}. Drag to move or select Edit.',
        child: target,
      ),
    );
  }
}
