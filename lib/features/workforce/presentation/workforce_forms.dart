import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/workforce_models.dart';
import '../domain/workforce_time.dart';

class WorkField {
  const WorkField(
    this.key,
    this.label, {
    this.kind = 'text',
    this.reference,
    this.choices = const [],
    this.required = true,
    this.initial,
  });
  final String key, label, kind;
  final String? reference;
  final List<String> choices;
  final bool required;
  final Object? initial;
}

const _staff = WorkField('staff_id', 'Employee', reference: 'staff_profiles');
const _job = WorkField('job_role_id', 'Job role', reference: 'job_roles');
const _department = WorkField(
  'department_id',
  'Department',
  reference: 'departments',
  required: false,
);
const _area = WorkField(
  'area_id',
  'Area / outlet',
  reference: 'venue_areas',
  required: false,
);
const _start = WorkField(
  'starts_at',
  'Starts at (venue time)',
  kind: 'timestamp',
);
const _end = WorkField('ends_at', 'Ends at (venue time)', kind: 'timestamp');
const _from = WorkField('valid_from', 'Effective from', kind: 'date');
const _until = WorkField(
  'valid_until',
  'Effective until',
  kind: 'date',
  required: false,
);
const workforceFields = <String, List<WorkField>>{
  'departments': [
    WorkField('name', 'Department name'),
    WorkField('code', 'Code'),
  ],
  'venue_areas': [
    WorkField('name', 'Area / outlet name'),
    WorkField('code', 'Code'),
    WorkField(
      'location_id',
      'Inventory location',
      reference: 'storage_locations',
      required: false,
    ),
  ],
  'job_roles': [
    WorkField('name', 'Job role'),
    WorkField('key', 'Role code'),
    _department,
    WorkField(
      'required_skills',
      'Required skills (comma separated)',
      kind: 'list',
      required: false,
    ),
    WorkField(
      'required_certifications',
      'Required certifications (comma separated)',
      kind: 'list',
      required: false,
    ),
    WorkField('enabled', 'Enabled', kind: 'bool', initial: true),
  ],
  'staff_profiles': [
    WorkField('user_id', 'Team member', reference: 'memberships'),
    WorkField('display_name', 'Display name'),
    WorkField(
      'employment_status',
      'Employment status',
      choices: ['active', 'leave', 'suspended', 'terminated'],
      initial: 'active',
    ),
    WorkField(
      'employment_type',
      'Employment type',
      choices: ['hourly', 'salary', 'contract'],
      initial: 'hourly',
    ),
    WorkField(
      'weekly_limit_minutes',
      'Weekly limit (minutes)',
      kind: 'int',
      initial: 2400,
    ),
    WorkField(
      'minimum_rest_minutes',
      'Minimum rest (minutes)',
      kind: 'int',
      initial: 660,
    ),
  ],
  'staff_role_assignments': [_staff, _job],
  'staff_qualifications': [
    _staff,
    WorkField('skill_key', 'Skill code'),
    WorkField('approved', 'Approved', kind: 'bool', initial: false),
  ],
  'staff_certifications': [
    _staff,
    WorkField('certification_key', 'Certification code'),
    WorkField('expires_on', 'Expires on', kind: 'date'),
    WorkField(
      'status',
      'Verification status',
      choices: ['pending', 'verified', 'revoked'],
      initial: 'pending',
    ),
  ],
  'employee_wage_rates': [
    _staff,
    WorkField(
      'job_role_id',
      'Role-specific rate',
      reference: 'job_roles',
      required: false,
    ),
    WorkField('hourly_rate', 'Hourly rate', kind: 'decimal'),
    WorkField('currency_code', 'Currency', initial: 'USD'),
    WorkField('effective_from', 'Effective from', kind: 'date'),
    WorkField(
      'effective_until',
      'Effective until',
      kind: 'date',
      required: false,
    ),
  ],
  'staff_availability_rules': [
    _staff,
    WorkField('weekday', 'Day (Monday = 1)', kind: 'int', initial: 1),
    WorkField(
      'starts_local',
      'Start time (HH:mm)',
      kind: 'time',
      initial: '09:00',
    ),
    WorkField('ends_local', 'End time (HH:mm)', kind: 'time', initial: '17:00'),
    WorkField(
      'available',
      'Available (off means unavailable)',
      kind: 'bool',
      initial: true,
    ),
    _from,
    _until,
  ],
  'staff_availability_exceptions': [
    _staff,
    _start,
    _end,
    WorkField('available', 'Available', kind: 'bool', initial: false),
    WorkField('reason', 'Reason', required: false),
  ],
  'time_off_requests': [
    _staff,
    _start,
    _end,
    WorkField(
      'category',
      'Category',
      choices: ['paid', 'unpaid', 'sick', 'other'],
      initial: 'unpaid',
    ),
    WorkField(
      'requested_minutes',
      'Balance minutes requested',
      kind: 'int',
      initial: 0,
    ),
    WorkField('reason', 'Reason', required: false),
  ],
  'time_off_balances': [
    _staff,
    WorkField('category', 'Balance category', initial: 'paid'),
    WorkField('minutes', 'Balance minutes', kind: 'int', initial: 0),
  ],
  'schedule_periods': [
    WorkField('name', 'Schedule name'),
    WorkField('starts_on', 'First date', kind: 'date'),
    WorkField('ends_on', 'End date (exclusive)', kind: 'date'),
  ],
  'shifts': [
    WorkField(
      'period_id',
      'Schedule period',
      reference: 'schedule_periods',
      required: false,
    ),
    _job,
    _department,
    _area,
    WorkField('event_id', 'Event', reference: 'events', required: false),
    _start,
    _end,
    WorkField('headcount', 'Required positions', kind: 'int', initial: 1),
    WorkField('instructions', 'Shift instructions', required: false),
  ],
  'shift_requirements': [
    WorkField('period_id', 'Schedule period', reference: 'schedule_periods'),
    _job,
    _area,
    _start,
    _end,
    WorkField(
      'minimum_staff',
      'Minimum assigned employees',
      kind: 'int',
      initial: 1,
    ),
  ],
  'shift_break_rules': [
    WorkField('shift_id', 'Shift', reference: 'shifts'),
    WorkField('minimum_minutes', 'Break minutes', kind: 'int', initial: 30),
    WorkField('paid', 'Paid break', kind: 'bool', initial: false),
    WorkField('required', 'Required', kind: 'bool', initial: true),
  ],
  'shift_notes': [
    WorkField('shift_id', 'Shift', reference: 'shifts'),
    WorkField('body', 'Note'),
    WorkField('staff_visible', 'Visible to staff', kind: 'bool', initial: true),
  ],
  'schedule_templates': [WorkField('name', 'Template name')],
  'schedule_template_shifts': [
    WorkField('template_id', 'Template', reference: 'schedule_templates'),
    _job,
    _department,
    _area,
    WorkField('weekday', 'Day (Monday = 1)', kind: 'int', initial: 1),
    WorkField(
      'starts_local',
      'Start time (HH:mm)',
      kind: 'time',
      initial: '09:00',
    ),
    WorkField(
      'duration_minutes',
      'Duration minutes',
      kind: 'int',
      initial: 480,
    ),
    WorkField('headcount', 'Positions', kind: 'int', initial: 1),
    WorkField('instructions', 'Instructions', required: false),
    WorkField('break_minutes', 'Break minutes', kind: 'int', initial: 30),
    WorkField('break_paid', 'Paid break', kind: 'bool', initial: false),
  ],
  'labor_targets': [
    WorkField('starts_on', 'First date', kind: 'date'),
    WorkField('ends_on', 'End date', kind: 'date'),
    WorkField('target_minutes', 'Labor minutes target', kind: 'int'),
    WorkField('target_cost', 'Labor budget', kind: 'decimal'),
    WorkField('target_percent', 'Labor percent target', kind: 'decimal'),
  ],
  'labor_forecasts': [
    WorkField('service_date', 'Service date', kind: 'date'),
    WorkField('forecast_sales', 'Sales forecast', kind: 'decimal'),
    WorkField('forecast_covers', 'Covers', kind: 'int', initial: 0),
  ],
  'workforce_settings': [
    WorkField('geofence_address', 'Venue address for clock boundary'),
    WorkField('geofence_latitude', 'Venue latitude', kind: 'coordinate'),
    WorkField('geofence_longitude', 'Venue longitude', kind: 'coordinate'),
    WorkField(
      'geofence_radius_ft',
      'Clock radius (1–1,000 feet)',
      kind: 'int',
      initial: 1000,
    ),
    WorkField(
      'require_assigned_clock',
      'Require assigned clock-in',
      kind: 'bool',
      initial: true,
    ),
    WorkField(
      'clock_early_minutes',
      'Early clock-in allowance',
      kind: 'int',
      initial: 15,
    ),
    WorkField(
      'clock_late_minutes',
      'Late clock-out allowance',
      kind: 'int',
      initial: 120,
    ),
    WorkField(
      'overtime_week_minutes',
      'Weekly overtime threshold (minutes)',
      kind: 'int',
      initial: 2400,
    ),
    WorkField(
      'overtime_multiplier',
      'Overtime multiplier',
      kind: 'decimal',
      initial: '1.5000',
    ),
    WorkField(
      'minimum_break_minutes',
      'Minimum break minutes',
      kind: 'int',
      initial: 30,
    ),
    WorkField(
      'break_after_minutes',
      'Break after minutes worked',
      kind: 'int',
      initial: 360,
    ),
    WorkField(
      'reminder_minutes',
      'Shift reminder minutes',
      kind: 'int',
      initial: 60,
    ),
  ],
  'workforce_department_managers': [
    WorkField('user_id', 'Department manager', reference: 'memberships'),
    WorkField('department_id', 'Managed department', reference: 'departments'),
  ],
};

Future<Map<String, dynamic>?> workForm(
  BuildContext context, {
  required String title,
  required List<WorkField> fields,
  required WorkforceSnapshot snapshot,
  required String zone,
  Map<String, dynamic> initial = const {},
}) => showDialog<Map<String, dynamic>>(
  context: context,
  builder: (context) => _WorkForm(
    title: title,
    fields: fields,
    snapshot: snapshot,
    zone: zone,
    initial: initial,
  ),
);

class _WorkForm extends StatefulWidget {
  const _WorkForm({
    required this.title,
    required this.fields,
    required this.snapshot,
    required this.zone,
    required this.initial,
  });
  final String title, zone;
  final List<WorkField> fields;
  final WorkforceSnapshot snapshot;
  final Map<String, dynamic> initial;
  @override
  State<_WorkForm> createState() => _WorkFormState();
}

class _WorkFormState extends State<_WorkForm> {
  final _key = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _values = <String, dynamic>{};
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      final value = widget.initial[f.key] ?? f.initial;
      _values[f.key] = value;
      var text = value?.toString() ?? '';
      if (f.kind == 'list' && value is List) text = value.join(', ');
      if (f.kind == 'timestamp' && value != null) {
        final utc = DateTime.parse(value.toString());
        final local = tz.TZDateTime.from(utc, tz.getLocation(widget.zone));
        text = DateFormat('yyyy-MM-dd HH:mm').format(local);
      }
      _controllers[f.key] = TextEditingController(text: text);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Times use ${widget.zone}. Overnight shifts need an end date on the following day.',
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              for (final f in widget.fields)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _field(f),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: const Text('Save'),
      ),
    ],
  );
  Widget _field(WorkField f) {
    if (f.kind == 'bool') {
      return SwitchListTile(
        title: Text(f.label),
        value: _values[f.key] == true,
        onChanged: (v) => setState(() => _values[f.key] = v),
      );
    }
    if (f.reference != null || f.choices.isNotEmpty) {
      final options = <String, String>{};
      if (!f.required) options[''] = 'None';
      if (f.reference != null) {
        for (final row in widget.snapshot.rows(f.reference!)) {
          final id = (row['id'] ?? '').toString();
          options[id] =
              (row['name'] ??
                      row['display_name'] ??
                      row['role_key'] ??
                      row['key'] ??
                      id)
                  .toString();
          if (f.reference == 'shifts') {
            options[id] = '${row['role_key']} · ${row['starts_at']}';
          }
        }
      } else {
        for (final choice in f.choices) {
          options[choice] = choice.replaceAll('_', ' ');
        }
      }
      final selected = _values[f.key]?.toString();
      return DropdownButtonFormField<String>(
        initialValue: options.containsKey(selected) ? selected : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: f.label),
        items: options.entries
            .map(
              (e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        validator: (v) => f.required && (v == null || v.isEmpty)
            ? 'Choose ${f.label.toLowerCase()}'
            : null,
        onChanged: (v) => _values[f.key] = v,
      );
    }
    return TextFormField(
      controller: _controllers[f.key],
      decoration: InputDecoration(
        labelText: f.label,
        hintText: f.kind == 'timestamp'
            ? 'yyyy-MM-dd HH:mm'
            : f.kind == 'date'
            ? 'yyyy-MM-dd'
            : null,
      ),
      keyboardType: f.kind == 'int' || f.kind == 'decimal'
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      minLines: 1,
      maxLines: f.key == 'instructions' || f.key == 'body' ? 4 : 1,
      validator: (v) {
        if (f.required && (v == null || v.trim().isEmpty)) {
          return 'Enter ${f.label.toLowerCase()}';
        }
        if (v == null || v.trim().isEmpty) return null;
        if (f.kind == 'int' && int.tryParse(v) == null) {
          return 'Enter a whole number';
        }
        if (f.key == 'geofence_radius_ft' &&
            (int.parse(v) < 1 || int.parse(v) > 1000)) {
          return 'Choose 1–1,000 feet';
        }
        if (f.kind == 'coordinate') {
          final number = double.tryParse(v);
          final limit = f.key == 'geofence_latitude' ? 90 : 180;
          if (number == null || !number.isFinite || number.abs() > limit) {
            return 'Enter a valid coordinate';
          }
        }
        if (f.kind == 'decimal' && !RegExp(r'^\d+(\.\d{1,4})?$').hasMatch(v)) {
          return 'Use up to four decimal places';
        }
        if (f.kind == 'time' &&
            !RegExp(r'^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$').hasMatch(v)) {
          return 'Use HH:mm';
        }
        if (f.kind == 'date' || f.kind == 'timestamp') {
          try {
            DateFormat(f.kind == 'date' ? 'yyyy-MM-dd' : 'yyyy-MM-dd HH:mm')
                .parseStrict(v, true);
          } on FormatException {
            return 'Use a valid date in the displayed format';
          }
        }
        return null;
      },
    );
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final result = <String, dynamic>{};
      for (final f in widget.fields) {
        if (f.kind == 'bool' || f.reference != null || f.choices.isNotEmpty) {
          result[f.key] = _values[f.key] == '' ? null : _values[f.key];
          continue;
        }
        final raw = _controllers[f.key]!.text.trim();
        if (raw.isEmpty) {
          result[f.key] = f.kind == 'list'
              ? <String>[]
              : {'reason', 'instructions'}.contains(f.key)
              ? ''
              : null;
          continue;
        }
        if (f.kind == 'timestamp') {
          final wall = DateFormat('yyyy-MM-dd HH:mm').parseStrict(raw, true);
          final choices = wallTimeCandidates(wall, widget.zone);
          if (choices.isEmpty) {
            throw FormatException(
              '${f.label} does not exist during the daylight-saving transition.',
            );
          }
          DateTime? selected = choices.first;
          if (choices.length > 1) {
            if (!mounted) return;
            selected = await showDialog<DateTime>(
              context: context,
              builder: (context) => SimpleDialog(
                title: Text('${f.label}: choose the repeated hour'),
                children: choices
                    .map(
                      (utc) => SimpleDialogOption(
                        onPressed: () => Navigator.pop(context, utc),
                        child: Text('${utc.toIso8601String()} UTC'),
                      ),
                    )
                    .toList(),
              ),
            );
          }
          if (selected == null) {
            if (mounted) setState(() => _busy = false);
            return;
          }
          result[f.key] = selected.toIso8601String();
        } else if (f.kind == 'int') {
          result[f.key] = int.parse(raw);
        } else if (f.kind == 'coordinate') {
          result[f.key] = double.parse(raw);
        } else if (f.kind == 'list') {
          result[f.key] = raw
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        } else {
          result[f.key] = raw;
        }
      }
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
