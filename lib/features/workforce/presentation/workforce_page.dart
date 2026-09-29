import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/permissions/permission.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../core/widgets/hospitality_design.dart';
import '../../onboarding/application/tenant_controller.dart';
import '../../onboarding/application/workspace_controller.dart';
import '../../onboarding/domain/tenant_session.dart';
import '../data/workforce_repository.dart';
import '../data/workforce_notifications.dart';
import '../data/clock_location.dart';
import '../domain/workforce_models.dart';
import '../domain/workforce_time.dart';
import 'schedule_board.dart';
import 'workforce_forms.dart';

const _areas = [
  'Schedule Board',
  'My Schedule',
  'Open Shifts',
  'Shift Requests',
  'Availability',
  'Time Off',
  'Team Directory',
  'Shift Templates',
  'Labor & Coverage',
  'Time Clock',
  'Schedule Reports',
  'Scheduling Settings',
];
const _labels = {
  'departments': 'Departments',
  'venue_areas': 'Areas & outlets',
  'job_roles': 'Job roles',
  'staff_profiles': 'Employees',
  'staff_role_assignments': 'Role qualifications',
  'staff_qualifications': 'Skills',
  'staff_certifications': 'Certifications',
  'employee_wage_rates': 'Wage rates',
  'workforce_department_managers': 'Department managers',
  'staff_availability_rules': 'Weekly availability',
  'staff_availability_exceptions': 'Availability exceptions',
  'time_off_requests': 'Time off requests',
  'time_off_balances': 'Time off balances',
  'schedule_periods': 'Schedule periods',
  'shift_requirements': 'Staffing requirements',
  'shift_break_rules': 'Shift break rules',
  'shift_notes': 'Shift notes',
  'schedule_templates': 'Templates',
  'schedule_template_shifts': 'Template shifts',
  'labor_targets': 'Labor targets',
  'labor_forecasts': 'Sales forecasts',
  'workforce_settings': 'Scheduling rules',
};

class WorkforcePage extends ConsumerStatefulWidget {
  const WorkforcePage({super.key, this.initialShift});
  final String? initialShift;
  @override
  ConsumerState<WorkforcePage> createState() => _WorkforcePageState();
}

class _WorkforcePageState extends ConsumerState<WorkforcePage> {
  WorkforceSnapshot? _snapshot;
  List<WorkCommand> _drafts = [];
  RealtimeChannel? _realtime;
  Timer? _debounce;
  String? _org, _venue, _user, _zone, _error, _message;
  String _area = 'Schedule Board', _group = 'Employee';
  String? _department, _job, _outlet, _event, _employee;
  int _days = 7, _generation = 0;
  bool _busy = false, _offline = false;
  bool _locating = false;
  DateTime _start = DateTime.now();
  WorkforceRepository get _repo => ref.read(workforceRepositoryProvider);
  TenantSession? get _tenant => ref.read(tenantControllerProvider).value;
  WorkforceSnapshot get _data => _snapshot!;
  String? get _myStaff =>
      _data.staff.where((s) => s.userId == _user).firstOrNull?.id;
  bool _can(String p) => _org != null && (_tenant?.can(_org!, p) ?? false);
  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    if (_realtime != null) unawaited(_realtime!.unsubscribe());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final tenant = ref.watch(tenantControllerProvider).value;
    if (auth is! AuthSignedIn ||
        workspace.organizationId == null ||
        workspace.venueId == null) {
      return const Center(child: Text('Open a venue first.'));
    }
    final venue = tenant?.venues
        .where((v) => v.id == workspace.venueId)
        .firstOrNull;
    if (_org != workspace.organizationId ||
        _venue != workspace.venueId ||
        _user != auth.userId) {
      _org = workspace.organizationId;
      _venue = workspace.venueId;
      _user = auth.userId;
      _zone = venue?.timezone ?? 'UTC';
      _snapshot = null;
      _department = null;
      _job = null;
      _outlet = null;
      _event = null;
      _employee = null;
      final now = tz.TZDateTime.now(tz.getLocation(_zone!));
      _start = DateTime.utc(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_connect());
        }
      });
    }
    return ListView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
      children: [
        Row(
          children: [
            Expanded(
              child: WorkspaceHeading(
                title: 'People & scheduling',
                subtitle: '${venue?.name ?? 'Venue'} · ${_zone!}',
                icon: Icons.groups_outlined,
              ),
            ),
            IconButton(
              tooltip: 'Refresh schedule',
              onPressed: _busy ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _area,
          decoration: const InputDecoration(labelText: 'Scheduling workspace'),
          items: _areas
              .map((a) => DropdownMenuItem(value: a, child: Text(a)))
              .toList(),
          onChanged: (v) => setState(() => _area = v!),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) StatusBanner(message: _error!),
        if (_message != null)
          StatusBanner(message: _message!, tone: BannerTone.success),
        if (_offline)
          const StatusBanner(
            message: 'Offline snapshot. Drafts are saved on this device. Clock captures require manager review. Wages are available online only.',
          ),
        if (_drafts.isNotEmpty) _draftPanel(),
        const SizedBox(height: 16),
        if (_snapshot == null && !_busy)
          const Text('Refresh to load scheduling.'),
        if (_snapshot != null) ..._content(),
      ],
    );
  }

  Future<void> _connect() async {
    final generation = ++_generation;
    await _realtime?.unsubscribe();
    if (!mounted || generation != _generation) return;
    _realtime = Supabase.instance.client.channel('workforce-$_user-$_venue')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'shifts',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'venue_id',
          value: _venue!,
        ),
        callback: (_) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 500), () {
            if (mounted) unawaited(_refresh());
          });
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'recipient_id',
          value: _user!,
        ),
        callback: (_) {
          if (mounted && !_busy) unawaited(_refresh());
        },
      )
      ..subscribe();
    await _refresh();
  }

  Future<void> _refresh() async {
    if (_busy || _org == null || _venue == null) return;
    final org = _org!, venue = _venue!, generation = _generation;
    setState(() => _busy = true);
    try {
      final zone = tz.getLocation(_zone!);
      final from = tz.TZDateTime(
        zone,
        _start.year,
        _start.month,
        _start.day,
      ).toUtc();
      final to = tz.TZDateTime(
        zone,
        _start.year,
        _start.month,
        _start.day + _days + 1,
      ).toUtc();
      WorkforceSnapshot snapshot;
      var offline = false;
      try {
        snapshot = await _repo.load(org, venue, from, to);
      } on AppFailure {
        rethrow;
      } catch (error) {
        final cache = await _repo.cached(org, venue);
        if (cache == null) rethrow;
        snapshot = cache;
        offline = true;
      }
      final members = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (final m in _tenant?.membersFor(org) ?? []) {
        if (m.status == 'active' &&
            (m.venueId == null || m.venueId == venue) &&
            seen.add(m.userId)) {
          members.add({
            'id': m.userId,
            'display_name': m.displayName ?? m.email ?? 'Team member',
          });
        }
      }
      final locations = await _locations(org, venue, offline);
      snapshot = WorkforceSnapshot({
        ...snapshot.sections,
        'memberships': members,
        'storage_locations': locations,
      });
      final drafts = await _repo.pending(org, venue);
      if (!mounted ||
          generation != _generation ||
          _org != org ||
          _venue != venue) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _drafts = drafts;
        _offline = offline;
        _error = null;
      });
      if (!_offline) {
        final mine = snapshot.assignments
            .where((a) => a.status == 'assigned' && a.staffId == _myStaff)
            .map((a) => a.shiftId)
            .toSet();
        final settings = snapshot.rows('workforce_settings').firstOrNull;
        await ref
            .read(workforceNotificationsProvider)
            .reminders(
              snapshot.shifts
                  .where((s) => s.status == 'published' && mine.contains(s.id))
                  .toList(),
              settings?['reminder_minutes'] as int? ?? 60,
              _zone!,
            );
      }
      if (widget.initialShift != null) {
        final shift = snapshot.shifts
            .where((s) => s.id == widget.initialShift)
            .firstOrNull;
        if (shift != null && mounted) {
          _area = 'My Schedule';
        }
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = _errorText(error));
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<List<Map<String, dynamic>>> _locations(
    String org,
    String venue,
    bool offline,
  ) async {
    if (offline || !_can(Permission.staffManage)) return const [];
    return List<Map<String, dynamic>>.from(
      await Supabase.instance.client
          .from('storage_locations')
          .select('id,name')
          .eq('organization_id', org)
          .eq('venue_id', venue),
    );
  }

  String _errorText(Object error) => error is AppFailure
      ? error.message
      : error is PostgrestException
      ? error.message
      : 'Could not reach the server. Your saved drafts remain on this device.';
  Future<void> _act(
    String action,
    Map<String, dynamic> payload, {
    bool queueable = true,
  }) async {
    if (_busy) return;
    final org = _org!, venue = _venue!, generation = _generation;
    final command = _repo.command(org, venue, action, payload);
    // Store before sending so a crash or an ambiguous response cannot lose the command ID.
    await _repo.keep(command);
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      if (_offline) throw StateError('offline');
      await _repo.send(org, venue, command);
      await _repo.keep(command.copyWith(status: 'synced'));
      if (mounted && generation == _generation) {
        setState(() => _message = 'Saved.');
      }
    } on AppFailure catch (error) {
      await _repo.keep(
        command.copyWith(status: 'needs_review', error: error.message),
      );
      if (mounted && generation == _generation) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      await _repo.keep(
        command.copyWith(
          status: queueable ? 'pending' : 'needs_review',
          error: 'Server response unavailable. Review before retrying.',
        ),
      );
      if (mounted && generation == _generation) {
        setState(
          () => _message = queueable
              ? 'Draft saved on this device. Use Sync when connected.'
              : 'Saved for review. This action has not been confirmed.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
        await _refresh();
      }
    }
  }

  Future<bool> _confirm(String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm schedule change'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;
  Widget _draftPanel() => ExpansionTile(
    title: Text(
      'Device history · ${_drafts.where((d) => d.status == 'pending' || d.status == 'needs_review').length} awaiting sync or review',
    ),
    children: _drafts.reversed
        .take(30)
        .map(
          (draft) => ListTile(
            title: Text(
              '${draft.action.replaceAll('_', ' ')} · ${draft.status.replaceAll('_', ' ')}',
            ),
            subtitle: Text(
              draft.error ??
                  DateFormat.yMd().add_jm().format(draft.createdAt.toLocal()),
            ),
            trailing: draft.status == 'synced'
                ? const Icon(Icons.check_circle_outline)
                : Wrap(
                    children: [
                      if (draft.status == 'pending' ||
                          draft.status == 'needs_review')
                        TextButton(
                          onPressed: _busy ? null : () => _sync(draft),
                          child: const Text('Sync'),
                        ),
                      TextButton(
                        onPressed: _busy ? null : () => _reviewDraft(draft),
                        child: const Text('Review'),
                      ),
                    ],
                  ),
          ),
        )
        .toList(),
  );
  Future<void> _sync(WorkCommand draft) async {
    if (_offline) {
      setState(() => _error = 'Reconnect and refresh before syncing.');
      return;
    }
    final org = _org!, venue = _venue!, generation = _generation;
    setState(() => _busy = true);
    try {
      await _repo.send(org, venue, draft);
      await _repo.keep(draft.copyWith(status: 'synced', error: null));
    } on AppFailure catch (error) {
      await _repo.keep(
        draft.copyWith(status: 'needs_review', error: error.message),
      );
    } catch (error) {
      await _repo.keep(
        draft.copyWith(
          status: 'pending',
          error: 'Still awaiting a server response.',
        ),
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
        await _refresh();
      }
    }
  }

  Future<void> _reviewDraft(WorkCommand draft) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saved draft'),
        content: SingleChildScrollView(
          child: Text(
            '${draft.action.replaceAll('_', ' ')}\n${_draftSummary(draft)}\n\n${draft.error ?? ''}\n\nSync checks the original command. To resolve a stale edit, refresh and edit the current record. Your original draft remains in this history.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (draft.status != 'synced' && draft.status != 'rejected')
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard draft'),
            ),
        ],
      ),
    );
    if (discard == true && mounted) {
      await _repo.keep(
        draft.copyWith(status: 'rejected', error: 'Discarded by you.'),
      );
      await _refresh();
    }
  }

  String _draftSummary(WorkCommand draft) {
    final table = draft.action == 'save_shift'
        ? 'shifts'
        : draft.payload['table'] as String?;
    final values = draft.payload['data'] is Map
        ? Map<String, dynamic>.from(draft.payload['data'] as Map)
        : draft.payload;
    final fields = workforceFields[table] ?? const <WorkField>[];
    return fields
        .where((f) => values[f.key] != null)
        .map((f) {
          final value = f.reference == null
              ? values[f.key]
              : _data.label(f.reference!, values[f.key] as String?);
          return '${f.label}: $value';
        })
        .join('\n');
  }

  List<Widget> _content() {
    switch (_area) {
      case 'Schedule Board':
        return _board();
      case 'My Schedule':
        return _mine();
      case 'Open Shifts':
        return _open();
      case 'Shift Requests':
        return _requests();
      case 'Availability':
        return [
          _section('staff_availability_rules'),
          _section('staff_availability_exceptions'),
        ];
      case 'Time Off':
        return [
          _section('time_off_requests'),
          if (_can(Permission.staffManage)) _section('time_off_balances'),
        ];
      case 'Team Directory':
        return [
          'departments',
          'venue_areas',
          'job_roles',
          'staff_profiles',
          'staff_role_assignments',
          'staff_qualifications',
          'staff_certifications',
          if (_can(Permission.laborRead)) 'employee_wage_rates',
          if (_can(Permission.staffManage)) 'workforce_department_managers',
        ].map(_section).toList();
      case 'Shift Templates':
        return [
          _section('schedule_templates'),
          _section('schedule_template_shifts'),
          FilledButton.icon(
            onPressed: _busy || !_can(Permission.scheduleCopy)
                ? null
                : _applyTemplate,
            icon: const Icon(Icons.playlist_add),
            label: const Text('Apply template to draft schedule'),
          ),
        ];
      case 'Labor & Coverage':
        return [
          ..._labor(),
          _section('shift_requirements'),
          if (_can(Permission.wageManage)) _section('labor_targets'),
          if (_can(Permission.wageManage)) _section('labor_forecasts'),
        ];
      case 'Time Clock':
        return _clock();
      case 'Schedule Reports':
        return _reports();
      case 'Scheduling Settings':
        return [_section('workforce_settings'), _notifications()];
      default:
        return const [];
    }
  }

  List<WorkShift> get _filtered => _data.shifts
      .where(
        (s) =>
            s.status != 'retracted' &&
            (_department == null || s.departmentId == _department) &&
            (_job == null || s.jobRoleId == _job) &&
            (_outlet == null || s.areaId == _outlet) &&
            (_event == null || s.eventId == _event) &&
            (_employee == null ||
                _data.assignments.any(
                  (a) =>
                      a.shiftId == s.id &&
                      a.staffId == _employee &&
                      a.status == 'assigned',
                )),
      )
      .toList();
  List<Widget> _board() => [
    Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          tooltip: 'Previous period',
          onPressed: _busy
              ? null
              : () {
                  setState(
                    () => _start = _start.subtract(Duration(days: _days)),
                  );
                  unawaited(_refresh());
                },
          icon: const Icon(Icons.chevron_left),
        ),
        Text(DateFormat.yMMMd().format(_start)),
        IconButton(
          tooltip: 'Next period',
          onPressed: _busy
              ? null
              : () {
                  setState(() => _start = _start.add(Duration(days: _days)));
                  unawaited(_refresh());
                },
          icon: const Icon(Icons.chevron_right),
        ),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('Day')),
            ButtonSegment(value: 7, label: Text('Week')),
            ButtonSegment(value: 14, label: Text('2 weeks')),
            ButtonSegment(value: 31, label: Text('Month')),
          ],
          selected: {_days},
          onSelectionChanged: _busy
              ? null
              : (v) {
                  setState(() => _days = v.first);
                  unawaited(_refresh());
                },
        ),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Employee', label: Text('Employee')),
            ButtonSegment(value: 'Role', label: Text('Role')),
          ],
          selected: {_group},
          onSelectionChanged: (v) => setState(() => _group = v.first),
        ),
      ],
    ),
    const SizedBox(height: 12),
    Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _filter(
          'Department',
          'departments',
          _department,
          (v) => _department = v,
        ),
        _filter('Job role', 'job_roles', _job, (v) => _job = v),
        _filter('Area / outlet', 'venue_areas', _outlet, (v) => _outlet = v),
        _filter('Event', 'events', _event, (v) => _event = v),
        _filter('Employee', 'staff_profiles', _employee, (v) => _employee = v),
      ],
    ),
    const SizedBox(height: 12),
    Wrap(
      spacing: 12,
      children: [
        if (_can(Permission.scheduleCreate))
          FilledButton.icon(
            onPressed: _busy ? null : () => _editShift(),
            icon: const Icon(Icons.add),
            label: const Text('Create shift'),
          ),
        if (_can(Permission.scheduleCopy))
          OutlinedButton.icon(
            onPressed: _busy ? null : _copySchedule,
            icon: const Icon(Icons.copy),
            label: const Text('Copy schedule'),
          ),
      ],
    ),
    if (_data.staff.isEmpty || _data.rows('job_roles').isEmpty)
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Start in Team Directory: add departments, job roles, employees, and role qualifications. Then create a schedule period and shifts.',
        ),
      ),
    const SizedBox(height: 12),
    ScheduleBoard(
      shifts: _filtered,
      staff: _employee == null
          ? _data.staff
          : _data.staff.where((s) => s.id == _employee).toList(),
      assignments: _data.assignments,
      start: _start,
      days: _days,
      zone: _zone!,
      roleFirst: _group == 'Role',
      canEdit: _can(Permission.scheduleEdit),
      onEdit: (s) => unawaited(_shiftDetails(s)),
      onMove: (s, date) => unawaited(_move(s, date)),
      onAssign: (s, p) => unawaited(_assign(s, p.id)),
    ),
    const Padding(
      padding: EdgeInsets.all(12),
      child: Text(
        'Drag a shift within its employee or role lane to change the day. Drag a roster name onto a shift to assign. Edit / assign also works with the keyboard.',
      ),
    ),
    _section('schedule_periods'),
    _section('shift_break_rules'),
    _section('shift_notes'),
  ];
  Widget _filter(
    String label,
    String table,
    String? selected,
    void Function(String?) change,
  ) => SizedBox(
    width: 180,
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label:$selected'),
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('All')),
        for (final r in _data.rows(table))
          DropdownMenuItem(
            value: r['id'] as String,
            child: Text(
              (r['name'] ?? r['display_name'] ?? r['key']).toString(),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (v) => setState(() => change(v)),
    ),
  );
  Future<void> _editShift([WorkShift? shift]) async {
    final data = await workForm(
      context,
      title: shift == null ? 'Create shift' : 'Edit shift',
      fields: workforceFields['shifts']!,
      snapshot: _data,
      zone: _zone!,
      initial:
          shift?.toJson() ??
          {
            'starts_at': tz.TZDateTime(
              tz.getLocation(_zone!),
              _start.year,
              _start.month,
              _start.day,
              9,
            ).toUtc().toIso8601String(),
            'ends_at': tz.TZDateTime(
              tz.getLocation(_zone!),
              _start.year,
              _start.month,
              _start.day,
              17,
            ).toUtc().toIso8601String(),
          },
    );
    if (data == null || !mounted) return;
    final role = _data
        .rows('job_roles')
        .where((r) => r['id'] == data['job_role_id'])
        .firstOrNull;
    data['department_id'] = role?['department_id'];
    if (shift != null) {
      data['id'] = shift.id;
      data['revision'] = shift.revision;
      if (shift.status == 'published') {
        if (!await _confirm(
          'Update this published shift and notify assigned employees?',
        )) {
          return;
        }
        data['confirm_published'] = true;
      }
    }
    await _act('save_shift', data);
  }

  Future<void> _move(WorkShift shift, DateTime date) async {
    final location = tz.getLocation(_zone!),
        local = tz.TZDateTime.from(shift.startsAt, tz.getLocation(_zone!));
    final delta = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime.utc(local.year, local.month, local.day)).inDays;
    final end = tz.TZDateTime.from(shift.endsAt, location);
    final a = wallTimeCandidates(
      DateTime.utc(
        local.year,
        local.month,
        local.day + delta,
        local.hour,
        local.minute,
      ),
      _zone!,
    );
    final b = wallTimeCandidates(
      DateTime.utc(end.year, end.month, end.day + delta, end.hour, end.minute),
      _zone!,
    );
    if (a.length != 1 || b.length != 1) {
      setState(
        () => _error = 'This move reaches a daylight-saving gap or repeated hour. Use Edit to choose the exact time.',
      );
      return;
    }
    if (!await _confirm(
      'Move this shift to ${DateFormat.yMMMd().format(date)}? Assigned staff will be rechecked.',
    )) {
      return;
    }
    await _act('save_shift', {
      ...shift.toJson(),
      'starts_at': a.first.toIso8601String(),
      'ends_at': b.first.toIso8601String(),
      'confirm_published': true,
    });
  }

  Future<void> _assign(WorkShift shift, String? staff) async {
    final payload = await workForm(
      context,
      title: 'Assign qualified employee',
      fields: [
        const WorkField('staff_id', 'Employee', reference: 'staff_profiles'),
        if (_can(Permission.scheduleOverride))
          const WorkField(
            'override_reason',
            'Reason for availability / rest / hours override',
            required: false,
          ),
      ],
      snapshot: _data,
      zone: _zone!,
      initial: {'staff_id': staff},
    );
    if (payload == null || !mounted) return;
    await _act('assign', {
      'shift_id': shift.id,
      'revision': shift.revision,
      ...payload,
    });
  }

  Future<void> _shiftDetails(WorkShift shift) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(shift.roleKey.replaceAll('_', ' ')),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${_format(shift.startsAt)} – ${_format(shift.endsAt)}\n${shift.status}\n${shift.instructions}\n'
              'Area: ${_data.label('venue_areas', shift.areaId)}\nEvent: ${_data.label('events', shift.eventId)}',
            ),
          ),
          if (_can(Permission.scheduleEdit))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'edit'),
              child: const Text('Edit shift'),
            ),
          if (_can(Permission.scheduleAssign))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'assign'),
              child: const Text('Assign employee'),
            ),
          if (_can(Permission.scheduleOpen) && shift.status == 'published')
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'open'),
              child: const Text('Offer open positions'),
            ),
          if (_can(Permission.scheduleRetract))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'retract_shift'),
              child: const Text('Retract shift'),
            ),
          if (_can(Permission.scheduleAssign))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'remove'),
              child: const Text('Remove an assignment'),
            ),
          if (_data.assignments.any(
            (a) =>
                a.shiftId == shift.id &&
                a.staffId == _myStaff &&
                a.status == 'assigned',
          )) ...[
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'drop'),
              child: const Text('Request release'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'swap'),
              child: const Text('Request swap'),
            ),
          ],
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'message'),
            child: const Text('Message team'),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'edit') {
      await _editShift(shift);
      return;
    }
    if (action == 'assign') {
      await _assign(shift, null);
      return;
    }
    if (action == 'message') {
      await _messageTeam(shift);
      return;
    }
    if (action == 'drop') {
      final p = await _reasonForm('Request release');
      if (p != null) {
        await _act('drop', {
          'shift_id': shift.id,
          'revision': shift.revision,
          ...p,
        });
      }
      return;
    }
    if (action == 'swap') {
      await _swap(shift);
      return;
    }
    if (action == 'remove') {
      final options = _data.assignments
          .where((a) => a.shiftId == shift.id && a.status == 'assigned')
          .map(
            (a) => {
              'id': a.id,
              'name': _data.label('staff_profiles', a.staffId),
            },
          )
          .toList();
      final p = await workForm(
        context,
        title: 'Remove assignment',
        fields: const [
          WorkField(
            'assignment_id',
            'Assigned employee',
            reference: 'assignment_options',
          ),
          WorkField('reason', 'Reason'),
        ],
        snapshot: WorkforceSnapshot({
          ..._data.sections,
          'assignment_options': options,
        }),
        zone: _zone!,
      );
      if (p != null) {
        await _act('remove_assignment', {
          'shift_id': shift.id,
          'revision': shift.revision,
          ...p,
        });
      }
      return;
    }
    if (await _confirm(
      action == 'open'
          ? 'Make unfilled positions available for staff pickup requests?'
          : 'Retract this shift and notify assigned employees?',
    )) {
      await _act(action, {
        'shift_id': shift.id,
        'revision': shift.revision,
      }, queueable: false);
    }
  }

  String _format(DateTime utc) =>
      DateFormat('EEE MMM d, h:mm a')
          .format(tz.TZDateTime.from(utc, tz.getLocation(_zone!)));
  List<Widget> _mine() {
    final ids = _data.assignments
        .where((a) => a.staffId == _myStaff && a.status == 'assigned')
        .map((a) => a.shiftId)
        .toSet();
    return [
      if (_myStaff == null)
        const Text(
          'Ask your manager to link your team account to an employee profile.',
        ),
      ..._data.shifts
          .where((s) => ids.contains(s.id) && s.status == 'published')
          .map(
            (s) => Card(
              child: ListTile(
                title: Text(s.roleKey.replaceAll('_', ' ')),
                subtitle: Text('${_format(s.startsAt)}\n${s.instructions}'),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'Shift details and requests',
                  onPressed: () => _shiftDetails(s),
                  icon: const Icon(Icons.chevron_right),
                ),
              ),
            ),
          ),
      _notifications(),
      _messages(),
    ];
  }

  List<Widget> _open() => [
    const Text(
      'Pickup requests are checked for qualifications and require manager approval.',
    ),
    for (final offer
        in _data.rows('open_shift_offers').where((r) => r['status'] == 'open'))
      if (_data.shifts.any((s) => s.id == offer['shift_id']))
        Card(
          child: ListTile(
            title: Text(
              _data.shifts
                  .firstWhere((s) => s.id == offer['shift_id'])
                  .roleKey
                  .replaceAll('_', ' '),
            ),
            subtitle: Text(
              _format(
                _data.shifts
                    .firstWhere((s) => s.id == offer['shift_id'])
                    .startsAt,
              ),
            ),
            trailing: FilledButton(
              onPressed: _busy || _myStaff == null
                  ? null
                  : () => _act('pickup', {
                      'shift_id': offer['shift_id'],
                      'offer_id': offer['id'],
                      'revision': _data.shifts
                          .firstWhere((s) => s.id == offer['shift_id'])
                          .revision,
                    }),
              child: const Text('Request pickup'),
            ),
          ),
        ),
  ];
  List<Widget> _requests() => [
    for (final table in [
      'shift_drop_requests',
      'shift_pickup_requests',
      'shift_swap_requests',
      'time_off_requests',
      'clock_attestations',
    ])
      Card(
        child: ExpansionTile(
          title: Text(table.replaceAll('_', ' ')),
          children: [
            if (_data.rows(table).isEmpty)
              const ListTile(title: Text('No requests')),
            for (final row in _data.rows(table))
              ListTile(
                title: Text(
                  '${_data.label('staff_profiles', row['staff_id'] as String?)} · ${row['status']}',
                ),
                subtitle: Text((row['reason'] ?? 'Pickup request').toString()),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    if (row['status'] == 'pending' &&
                        table == 'shift_swap_requests' &&
                        row['other_staff_id'] == _myStaff &&
                        row['recipient_accepted'] != true)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _act('accept_swap', {
                                'table': table,
                                'id': row['id'],
                                'revision': row['revision'],
                              }, queueable: false),
                        child: const Text('Accept swap'),
                      ),
                    if (row['status'] == 'pending' &&
                        _can(_reviewPermission(table)))
                      TextButton(
                        onPressed: _busy ? null : () => _review(table, row),
                        child: const Text('Review'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
  ];
  String _reviewPermission(String table) => switch (table) {
    'shift_drop_requests' => Permission.scheduleDropReview,
    'shift_pickup_requests' => Permission.schedulePickupReview,
    'shift_swap_requests' => Permission.scheduleSwapReview,
    'time_off_requests' => Permission.timeOffReview,
    _ => Permission.timeclockManage,
  };
  Future<void> _review(String table, Map<String, dynamic> row) async {
    final p = await workForm(
      context,
      title: 'Review request',
      fields: const [
        WorkField('decision', 'Decision', choices: ['approved', 'rejected']),
        WorkField('reason', 'Review reason'),
      ],
      snapshot: _data,
      zone: _zone!,
    );
    if (p != null && mounted) {
      await _act('review_request', {
        'table': table,
        'id': row['id'],
        'revision': row['revision'],
        ...p,
      }, queueable: false);
    }
  }

  Future<Map<String, dynamic>?> _reasonForm(String title) => workForm(
    context,
    title: title,
    fields: const [WorkField('reason', 'Reason')],
    snapshot: _data,
    zone: _zone!,
  );
  Future<void> _swap(WorkShift shift) async {
    final cards = _data
        .rows('marketplace')
        .where((c) => c['staff_id'] != _myStaff && c['shift_id'] != shift.id)
        .toList();
    final options = cards
        .map(
          (c) => {
            ...c,
            'name':
                '${c['staff_name']} · ${c['role_key']} · ${_format(DateTime.parse(c['starts_at'] as String))}',
          },
        )
        .toList();
    final p = await workForm(
      context,
      title: 'Propose shift swap',
      fields: const [
        WorkField(
          'other_assignment',
          'Employee and published shift',
          reference: 'swap_options',
        ),
        WorkField('reason', 'Message', required: false),
      ],
      snapshot: WorkforceSnapshot({..._data.sections, 'swap_options': options}),
      zone: _zone!,
    );
    if (p == null) return;
    final other = cards
        .where((c) => c['id'] == p['other_assignment'])
        .firstOrNull;
    if (other == null) return;
    await _act('swap', {
      'shift_id': shift.id,
      'revision': shift.revision,
      'other_revision': other['revision'],
      'other_shift_id': other['shift_id'],
      'other_staff_id': other['staff_id'],
      'reason': p['reason'],
    });
  }

  Widget _section(String table) {
    final fields = workforceFields[table]!;
    final writable = _writable(table);
    final rows = _data.rows(table);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        title: Text(_labels[table] ?? table),
        subtitle: Text('${rows.length} records'),
        initiallyExpanded: rows.isEmpty,
        children: [
          if (writable)
            Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _editRecord(table, fields, null),
                icon: const Icon(Icons.add),
                label: Text('Add ${_labels[table]?.toLowerCase() ?? 'record'}'),
              ),
            ),
          for (final row in rows)
            ListTile(
              title: Text(_recordTitle(table, row)),
              subtitle: Text(_recordSubtitle(fields, row)),
              trailing: Wrap(
                children: [
                  if (table == 'staff_certifications' &&
                      row['evidence_path'] != null)
                    IconButton(
                      tooltip: 'View certification evidence',
                      onPressed: _busy ? null : () => _viewEvidence(row),
                      icon: const Icon(Icons.visibility_outlined),
                    ),
                  if (writable)
                    IconButton(
                      tooltip: 'Edit record',
                      onPressed: _busy
                          ? null
                          : () => _editRecord(table, fields, row),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  if (table == 'staff_certifications')
                    IconButton(
                      tooltip: 'Upload certification evidence',
                      onPressed: _busy ? null : () => _evidence(row),
                      icon: const Icon(Icons.attach_file),
                    ),
                  if (table == 'schedule_periods' &&
                      _can(Permission.schedulePublish))
                    TextButton(
                      onPressed: _busy ? null : () => _publish(row),
                      child: const Text('Publish'),
                    ),
                  if (table == 'schedule_periods' &&
                      _can(Permission.scheduleRetract) &&
                      row['status'] == 'published')
                    TextButton(
                      onPressed: _busy ? null : () => _retract(row),
                      child: const Text('Retract'),
                    ),
                ],
              ),
            ),
          if (rows.isEmpty && !writable)
            const ListTile(title: Text('No authorized records')),
        ],
      ),
    );
  }

  bool _writable(String table) => _can(switch (table) {
    'staff_availability_rules' ||
    'staff_availability_exceptions' => Permission.scheduleSelf,
    'time_off_requests' => Permission.scheduleSelf,
    'schedule_periods' => Permission.scheduleCreate,
    'shift_requirements' => Permission.scheduleRequirements,
    'shift_notes' || 'shift_break_rules' => Permission.scheduleEdit,
    'schedule_templates' ||
    'schedule_template_shifts' => Permission.scheduleTemplates,
    'employee_wage_rates' ||
    'labor_targets' ||
    'labor_forecasts' => Permission.wageManage,
    'staff_qualifications' || 'staff_certifications' => Permission.staffCertify,
    'workforce_settings' => Permission.scheduleSettings,
    _ => Permission.staffManage,
  });
  String _recordTitle(String table, Map<String, dynamic> row) =>
      (row['name'] ??
              row['display_name'] ??
              row['certification_key'] ??
              row['skill_key'] ??
              (row['staff_id'] != null
                  ? _data.label('staff_profiles', row['staff_id'] as String)
                  : row['service_date']) ??
              row['starts_on'] ??
              _labels[table])
          .toString();
  String _recordSubtitle(List<WorkField> fields, Map<String, dynamic> row) =>
      fields
          .where(
            (f) =>
                row[f.key] != null &&
                f.key != 'name' &&
                f.key != 'display_name',
          )
          .map((f) {
            final value = f.reference != null
                ? _data.label(f.reference!, row[f.key] as String?)
                : f.kind == 'timestamp'
                ? _format(DateTime.parse(row[f.key].toString()))
                : row[f.key];
            return '${f.label}: $value';
          })
          .join(' · ');
  Future<void> _editRecord(
    String table,
    List<WorkField> fields,
    Map<String, dynamic>? row,
  ) async {
    var initial = row ?? <String, dynamic>{};
    if (row == null &&
        fields.any((f) => f.key == 'staff_id') &&
        _myStaff != null) {
      initial = {...initial, 'staff_id': _myStaff};
    }
    final p = await workForm(
      context,
      title: row == null ? 'Add ${_labels[table]}' : 'Edit ${_labels[table]}',
      fields: fields,
      snapshot: _data,
      zone: _zone!,
      initial: initial,
    );
    if (p == null || !mounted) {
      return;
    }
    final related = _data.shifts
        .where((s) => s.id == p['shift_id'])
        .firstOrNull;
    if ({'shift_notes', 'shift_break_rules'}.contains(table) &&
        related?.status == 'published') {
      if (!await _confirm(
        'Update this published shift and notify assigned staff?',
      )) {
        return;
      }
    }
    await _act('save', {
      'table': table,
      'data': p,
      if (related?.status == 'published') 'confirm_published': true,
      if (row != null) 'id': row['id'],
      if (row != null) 'revision': row['revision'],
    });
  }

  Future<void> _publish(Map<String, dynamic> period) async {
    if (await _confirm(
      'Publish ${period['name']}? Assignments and staffing requirements will be checked and staff notified.',
    )) {
      await _act('publish', {
        'period_id': period['id'],
        'revision': period['revision'],
      }, queueable: false);
    }
  }

  Future<void> _retract(Map<String, dynamic> period) async {
    if (await _confirm('Retract ${period['name']} and notify staff?')) {
      await _act('retract', {
        'period_id': period['id'],
        'revision': period['revision'],
      }, queueable: false);
    }
  }

  Future<void> _copySchedule() async {
    final p = await workForm(
      context,
      title: 'Copy schedule',
      fields: const [
        WorkField(
          'source_period_id',
          'Source schedule',
          reference: 'schedule_periods',
        ),
        WorkField(
          'target_period_id',
          'Target draft schedule',
          reference: 'schedule_periods',
        ),
        WorkField(
          'include_assignments',
          'Copy employee assignments after eligibility checks',
          kind: 'bool',
          initial: false,
        ),
      ],
      snapshot: _data,
      zone: _zone!,
    );
    if (p == null) return;
    final target = _data.periods.firstWhere(
      (s) => s.id == p['target_period_id'],
    );
    await _act('copy_schedule', {...p, 'revision': target.revision});
  }

  Future<void> _applyTemplate() async {
    final p = await workForm(
      context,
      title: 'Apply template',
      fields: const [
        WorkField('template_id', 'Template', reference: 'schedule_templates'),
        WorkField(
          'target_period_id',
          'Target draft schedule',
          reference: 'schedule_periods',
        ),
      ],
      snapshot: _data,
      zone: _zone!,
    );
    if (p == null) return;
    final target = _data.periods.firstWhere(
      (s) => s.id == p['target_period_id'],
    );
    await _act('apply_template', {...p, 'revision': target.revision});
  }

  Future<void> _evidence(Map<String, dynamic> row) async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 20 * 1024 * 1024) {
        throw const ValidationFailure(
          'Choose a PDF or photo smaller than 20 MB.',
        );
      }
      final extension = file.extension?.toLowerCase() ?? '';
      final mime = {
        'pdf': 'application/pdf',
        'png': 'image/png',
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'webp': 'image/webp',
      }[extension];
      if (mime == null) throw const ValidationFailure('Choose a PDF or photo.');
      final path =
          '$_org/$_venue/${row['staff_id']}/${const Uuid().v4()}.$extension';
      await Supabase.instance.client.storage
          .from('workforce-certificates')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mime),
          );
      await _act('attach_evidence', {
        'id': row['id'],
        'revision': row['revision'],
        'evidence_path': path,
      }, queueable: false);
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    }
  }

  Future<void> _viewEvidence(Map<String, dynamic> row) async {
    try {
      final path = row['evidence_path'] as String;
      final url = await Supabase.instance.client.storage
          .from('workforce-certificates')
          .createSignedUrl(path, 300);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(row['certification_key'] as String),
          content: SizedBox(
            width: 700,
            height: 500,
            child: path.toLowerCase().endsWith('.pdf')
                ? PdfViewer.uri(Uri.parse(url))
                : Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) =>
                        const Text('The evidence could not be displayed.'),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    }
  }

  List<Widget> _clock() {
    final mine = _data
        .rows('time_entries')
        .where((e) => e['user_id'] == _user && e['clock_out'] == null)
        .firstOrNull;
    final breakOpen =
        mine != null &&
        _data
            .rows('break_entries')
            .any(
              (b) => b['time_entry_id'] == mine['id'] && b['ends_at'] == null,
            );
    return [
      const Text(
        'Clock-in and clock-out verify your location at the venue. Location is requested only when you punch. If location cannot be verified, report a missed punch for manager review.',
      ),
      if (_can(Permission.timeclockSelf))
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _busy || _locating
                  ? null
                  : () => _clockAction(mine == null ? 'clock_in' : 'clock_out'),
              icon: Icon(mine == null ? Icons.login : Icons.logout),
              label: Text(mine == null ? 'Clock in' : 'Clock out'),
            ),
            if (mine != null)
              OutlinedButton.icon(
                onPressed: _busy || _locating
                    ? null
                    : () =>
                          _clockAction(breakOpen ? 'break_end' : 'break_start'),
                icon: const Icon(Icons.coffee),
                label: Text(breakOpen ? 'End break' : 'Start break'),
              ),
            OutlinedButton(
              onPressed: _busy || _locating ? null : _attest,
              child: const Text('Report a missed or offline clock event'),
            ),
          ],
        ),
      if (_offline)
        const Text(
          'Offline clock events are claims for manager review, not confirmed time punches.',
        ),
      for (final row in _data.rows('time_entries'))
        Card(
          child: ListTile(
            title: Text(
              'In: ${_format(DateTime.parse(row['clock_in'] as String))}',
            ),
            subtitle: Text(
              row['clock_out'] == null
                  ? 'CLOCKED IN'
                  : 'Out: ${_format(DateTime.parse(row['clock_out'] as String))}',
            ),
            trailing: _can(Permission.timeclockManage)
                ? TextButton(
                    onPressed: _busy || _locating ? null : () => _correct(row),
                    child: const Text('Correct'),
                  )
                : null,
          ),
        ),
      ..._data
          .rows('break_entries')
          .map(
            (b) => ListTile(
              title: Text(
                '${b['paid'] == true ? 'Paid' : 'Unpaid'} break · ${_format(DateTime.parse(b['starts_at'] as String))}',
              ),
              subtitle: Text(
                b['ends_at'] == null
                    ? 'On break'
                    : _format(DateTime.parse(b['ends_at'] as String)),
              ),
            ),
          ),
    ];
  }

  Future<void> _clockAction(String action) async {
    if (_locating || _busy) return;
    if (_offline) {
      await _attest(
        kind: switch (action) {
          'clock_in' => 'offline_in',
          'clock_out' => 'offline_out',
          'break_start' => 'offline_break_start',
          _ => 'offline_break_end',
        },
      );
      return;
    }
    Map<String, dynamic> p = {};
    if (action == 'clock_in') {
      final mineIds = _data.assignments
          .where((a) => a.staffId == _myStaff && a.status == 'assigned')
          .map((a) => a.shiftId)
          .toSet();
      final choices = WorkforceSnapshot({
        ..._data.sections,
        'shifts': _data
            .rows('shifts')
            .where(
              (s) => mineIds.contains(s['id']) && s['status'] == 'published',
            )
            .toList(),
      });
      final entered = await workForm(
        context,
        title: 'Clock in',
        fields: const [
          WorkField(
            'shift_id',
            'Assigned shift',
            reference: 'shifts',
            required: false,
          ),
          WorkField(
            'reason',
            'Unscheduled work reason (manager permission required)',
            required: false,
          ),
        ],
        snapshot: choices,
        zone: _zone!,
      );
      if (entered == null) return;
      p = entered;
    }
    if (action == 'clock_in' || action == 'clock_out') {
      final org = _org, venue = _venue;
      setState(() => _locating = true);
      try {
        p['location'] = await captureClockLocation();
        if (!mounted || org != _org || venue != _venue) return;
      } on AppFailure catch (failure) {
        if (mounted) setState(() => _error = failure.message);
        return;
      } finally {
        if (mounted) setState(() => _locating = false);
      }
    }
    if (mounted) await _act(action, p, queueable: false);
  }

  Future<void> _attest({String? kind}) async {
    final p = await workForm(
      context,
      title: 'Clock claim for manager review',
      fields: [
        WorkField(
          'kind',
          'Event',
          choices: const [
            'missed_break',
            'offline_in',
            'offline_out',
            'offline_break_start',
            'offline_break_end',
          ],
          initial: kind,
        ),
        const WorkField(
          'captured_at',
          'Claimed time (venue time)',
          kind: 'timestamp',
        ),
        const WorkField('reason', 'Explanation'),
      ],
      snapshot: _data,
      zone: _zone!,
      initial: {'captured_at': DateTime.now().toUtc().toIso8601String()},
    );
    if (p != null) await _act('attest', p);
  }

  Future<void> _correct(Map<String, dynamic> row) async {
    final p = await workForm(
      context,
      title: 'Correct time entry',
      fields: const [
        WorkField('clock_in', 'Clock in (venue time)', kind: 'timestamp'),
        WorkField(
          'clock_out',
          'Clock out (venue time)',
          kind: 'timestamp',
          required: false,
        ),
        WorkField('reason', 'Correction reason'),
      ],
      snapshot: _data,
      zone: _zone!,
      initial: row,
    );
    if (p != null) {
      await _act('correct_time', {
        'id': row['id'],
        'revision': row['revision'],
        ...p,
      }, queueable: false);
    }
  }

  List<Widget> _labor() {
    var filled = 0, required = 0, minutes = 0;
    final costs = <String, List<String>>{};
    var missing = 0;
    for (final shift in _filtered) {
      required += shift.headcount;
      final assignments = _data.assignments.where(
        (a) => a.shiftId == shift.id && a.status == 'assigned',
      );
      filled += assignments.length;
      for (final assignment in assignments) {
        final duration = shift.endsAt.difference(shift.startsAt).inMinutes;
        final breaks = _data
            .rows('shift_break_rules')
            .where((b) => b['shift_id'] == shift.id && b['paid'] != true)
            .firstOrNull;
        final paid = (duration - (breaks?['minimum_minutes'] as int? ?? 0))
            .clamp(0, duration);
        minutes += paid;
        if (_can(Permission.laborRead) && !_offline) {
          final day = DateFormat(
            'yyyy-MM-dd',
          ).format(tz.TZDateTime.from(shift.startsAt, tz.getLocation(_zone!)));
          final rates =
              _data
                  .rows('employee_wage_rates')
                  .where(
                    (w) =>
                        w['staff_id'] == assignment.staffId &&
                        (w['job_role_id'] == null ||
                            w['job_role_id'] == shift.jobRoleId) &&
                        w['effective_from'].toString().compareTo(day) <= 0 &&
                        (w['effective_until'] == null ||
                            w['effective_until'].toString().compareTo(day) > 0),
                  )
                  .toList()
                ..sort(
                  (a, b) => (b['job_role_id'] == null ? 0 : 1).compareTo(
                    a['job_role_id'] == null ? 0 : 1,
                  ),
                );
          if (rates.isEmpty) {
            missing++;
            continue;
          }
          final wage = rates.first;
          costs
              .putIfAbsent(wage['currency_code'] as String, () => [])
              .add(laborCost(wage['hourly_rate'] as String, paid));
        }
      }
    }
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              Text('$filled / $required positions assigned'),
              Text('${(minutes / 60).toStringAsFixed(1)} planned paid hours'),
              Text('${required - filled} unfilled positions'),
            ],
          ),
        ),
      ),
      if (_can(Permission.laborRead)) ...[
        Text(
          'Base planned labor (before weekly overtime): ${costs.entries.map((e) => '${e.key} ${_sumCosts(e.value)}').join(' · ')}',
        ),
        if (missing > 0)
          Text('$missing assignments have no effective wage rate.'),
        const Text(
          'Wages are exact decimals. Cross-venue weekly overtime is included in the server labor report.',
        ),
        OutlinedButton(
          onPressed: _busy || _offline ? null : _serverLabor,
          child: const Text('Calculate labor and overtime'),
        ),
      ],
      ..._data.rows('shift_requirements').map((q) {
        final count = _data.assignments
            .where(
              (a) =>
                  a.status == 'assigned' &&
                  _data.shifts.any(
                    (s) =>
                        s.id == a.shiftId &&
                        s.periodId == q['period_id'] &&
                        s.jobRoleId == q['job_role_id'] &&
                        (q['area_id'] == null || s.areaId == q['area_id']) &&
                        !s.startsAt.isAfter(
                          DateTime.parse(q['starts_at'] as String),
                        ) &&
                        !s.endsAt.isBefore(
                          DateTime.parse(q['ends_at'] as String),
                        ),
                  ),
            )
            .length;
        return ListTile(
          title: Text(
            '${_data.label('job_roles', q['job_role_id'] as String)} · $count / ${q['minimum_staff']}',
          ),
          subtitle: Text(_format(DateTime.parse(q['starts_at'] as String))),
          leading: Icon(
            count >= (q['minimum_staff'] as int)
                ? Icons.check_circle_outline
                : Icons.warning_amber,
          ),
        );
      }),
    ];
  }

  String _sumCosts(List<String> values) {
    var cents = BigInt.zero;
    for (final value in values) {
      cents += BigInt.parse(value.replaceAll('.', ''));
    }
    return '${cents ~/ BigInt.from(100)}.${(cents % BigInt.from(100)).toString().padLeft(2, '0')}';
  }

  Future<void> _serverLabor() async {
    try {
      final data = await Supabase.instance.client.rpc(
        'workforce_labor_report',
        params: {
          'p_org': _org,
          'p_venue': _venue,
          'p_start': DateFormat('yyyy-MM-dd').format(_start),
          'p_end': DateFormat('yyyy-MM-dd')
              .format(_start.add(Duration(days: _days))),
        },
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Labor report'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final row in (data as List))
                  ListTile(
                    title: Text(
                      '${row['kind']} · ${row['currency']} ${row['cost']}',
                    ),
                    subtitle: Text(
                      '${row['paid_minutes']} paid minutes · ${row['overtime_minutes']} overtime · ${row['missing_rates']} missing rates',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    }
  }

  List<Widget> _reports() => [
    ..._labor(),
    OutlinedButton.icon(
      onPressed: _busy ? null : _exportReport,
      icon: const Icon(Icons.download),
      label: const Text('Export schedule CSV'),
    ),
    Card(
      child: ExpansionTile(
        title: const Text('Schedule versions'),
        children: _data
            .rows('schedule_versions')
            .map(
              (v) => ListTile(
                title: Text('Version ${v['version_number']} · ${v['source']}'),
                subtitle: Text(v['created_at'].toString()),
              ),
            )
            .toList(),
      ),
    ),
    Card(
      child: ExpansionTile(
        title: const Text('Change history'),
        children: _data
            .rows('shift_change_events')
            .reversed
            .take(100)
            .map(
              (e) => ListTile(
                title: Text('${e['entity_type']} · ${e['action']}'),
                subtitle: Text(
                  '${e['source']} · ${e['created_at']} · by ${e['created_by']}',
                ),
              ),
            )
            .toList(),
      ),
    ),
  ];
  Future<void> _exportReport() async {
    String cell(Object? value) {
      var text = (value ?? '').toString();
      if (RegExp(r'^\s*[=+@-]').hasMatch(text)) text = "'$text";
      return '"${text.replaceAll('"', '""')}"';
    }

    final lines = [
      [
        'role',
        'starts_at_utc',
        'ends_at_utc',
        'status',
        'positions',
        'assigned_employees',
      ],
      for (final s in _filtered)
        [
          s.roleKey,
          s.startsAt.toIso8601String(),
          s.endsAt.toIso8601String(),
          s.status,
          s.headcount,
          _data.assignments
              .where((a) => a.shiftId == s.id && a.status == 'assigned')
              .map((a) => _data.label('staff_profiles', a.staffId))
              .join('; '),
        ],
    ];
    try {
      await FilePicker.saveFile(
        fileName: 'venue-wrangler-schedule.csv',
        bytes: Uint8List.fromList(
          utf8.encode(lines.map((row) => row.map(cell).join(',')).join('\r\n')),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    }
  }

  Widget _notifications() => Card(
    child: ExpansionTile(
      title: const Text('Notifications & reminders'),
      children: [
        ListTile(
          title: const Text('Android notifications'),
          subtitle: Text(
            _data
                        .rows('workforce_push_status')
                        .firstOrNull?['last_delivery_at'] ==
                    null
                ? 'Remote delivery has not been verified. In-app notices remain available.'
                : 'Last delivery: ${_data.rows('workforce_push_status').first['last_delivery_at']}',
          ),
          trailing: TextButton(
            onPressed: _busy ? null : _enableNotifications,
            child: const Text('Enable'),
          ),
        ),
        for (final row in _data.rows('notifications').reversed.take(30))
          ListTile(
            title: Text(row['title'] as String),
            subtitle: Text(row['body'] as String),
            leading: Icon(
              row['read_at'] == null
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_none,
            ),
            trailing: row['read_at'] == null
                ? TextButton(
                    onPressed: _busy
                        ? null
                        : () => _act('read_notification', {'id': row['id']}),
                    child: const Text('Read'),
                  )
                : null,
          ),
      ],
    ),
  );
  Future<void> _enableNotifications() async {
    try {
      final enabled = await ref.read(workforceNotificationsProvider).enable(
        _org!,
        _venue!,
        (shift) {
          if (mounted) {
            context.go(
              '/app/scheduling${shift == null ? '' : '?shift=$shift'}',
            );
          }
        },
      );
      if (mounted) {
        setState(
          () => _message = enabled
              ? 'Device registered. Upcoming-shift reminders enabled.'
              : 'Notifications are unavailable or permission was declined.',
        );
      }
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    }
  }

  Widget _messages() => Card(
    child: ExpansionTile(
      title: const Text('Team messages'),
      children: [
        TextButton(
          onPressed: _busy ? null : () => _messageTeam(null),
          child: const Text('Write message'),
        ),
        for (final row in _data.rows('staff_messages').reversed.take(30))
          ListTile(
            title: Text(row['body'] as String),
            subtitle: Text(row['created_at'].toString()),
          ),
      ],
    ),
  );
  Future<void> _messageTeam(WorkShift? shift) async {
    final p = await workForm(
      context,
      title: 'Team message',
      fields: const [
        WorkField(
          'recipient_id',
          'Recipient (none = venue team)',
          reference: 'memberships',
          required: false,
        ),
        WorkField('body', 'Message'),
      ],
      snapshot: _data,
      zone: _zone!,
    );
    if (p != null) {
      await _act('message', {...p, if (shift != null) 'shift_id': shift.id});
    }
  }
}
