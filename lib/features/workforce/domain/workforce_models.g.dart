// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workforce_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WorkShift _$WorkShiftFromJson(Map<String, dynamic> json) => _WorkShift(
  id: json['id'] as String,
  organizationId: json['organization_id'] as String,
  venueId: json['venue_id'] as String,
  roleKey: json['role_key'] as String,
  startsAt: DateTime.parse(json['starts_at'] as String),
  endsAt: DateTime.parse(json['ends_at'] as String),
  status: json['status'] as String,
  revision: (json['revision'] as num?)?.toInt() ?? 1,
  headcount: (json['headcount'] as num?)?.toInt() ?? 1,
  instructions: json['instructions'] as String? ?? '',
  periodId: json['period_id'] as String?,
  jobRoleId: json['job_role_id'] as String?,
  departmentId: json['department_id'] as String?,
  areaId: json['area_id'] as String?,
  eventId: json['event_id'] as String?,
);

Map<String, dynamic> _$WorkShiftToJson(_WorkShift instance) =>
    <String, dynamic>{
      'id': instance.id,
      'organization_id': instance.organizationId,
      'venue_id': instance.venueId,
      'role_key': instance.roleKey,
      'starts_at': instance.startsAt.toIso8601String(),
      'ends_at': instance.endsAt.toIso8601String(),
      'status': instance.status,
      'revision': instance.revision,
      'headcount': instance.headcount,
      'instructions': instance.instructions,
      'period_id': instance.periodId,
      'job_role_id': instance.jobRoleId,
      'department_id': instance.departmentId,
      'area_id': instance.areaId,
      'event_id': instance.eventId,
    };

_WorkStaff _$WorkStaffFromJson(Map<String, dynamic> json) => _WorkStaff(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  displayName: json['display_name'] as String,
  employmentStatus: json['employment_status'] as String,
  employmentType: json['employment_type'] as String,
  weeklyLimitMinutes: (json['weekly_limit_minutes'] as num?)?.toInt() ?? 2400,
  minimumRestMinutes: (json['minimum_rest_minutes'] as num?)?.toInt() ?? 660,
  revision: (json['revision'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$WorkStaffToJson(_WorkStaff instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'display_name': instance.displayName,
      'employment_status': instance.employmentStatus,
      'employment_type': instance.employmentType,
      'weekly_limit_minutes': instance.weeklyLimitMinutes,
      'minimum_rest_minutes': instance.minimumRestMinutes,
      'revision': instance.revision,
    };

_ShiftAssignment _$ShiftAssignmentFromJson(Map<String, dynamic> json) =>
    _ShiftAssignment(
      id: json['id'] as String,
      shiftId: json['shift_id'] as String,
      staffId: json['staff_id'] as String,
      status: json['status'] as String,
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      overrideReason: json['override_reason'] as String?,
    );

Map<String, dynamic> _$ShiftAssignmentToJson(_ShiftAssignment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'shift_id': instance.shiftId,
      'staff_id': instance.staffId,
      'status': instance.status,
      'revision': instance.revision,
      'override_reason': instance.overrideReason,
    };

_WorkPeriod _$WorkPeriodFromJson(Map<String, dynamic> json) => _WorkPeriod(
  id: json['id'] as String,
  name: json['name'] as String,
  startsOn: json['starts_on'] as String,
  endsOn: json['ends_on'] as String,
  status: json['status'] as String,
  revision: (json['revision'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$WorkPeriodToJson(_WorkPeriod instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'starts_on': instance.startsOn,
      'ends_on': instance.endsOn,
      'status': instance.status,
      'revision': instance.revision,
    };

_WorkCommand _$WorkCommandFromJson(Map<String, dynamic> json) => _WorkCommand(
  id: json['id'] as String,
  scope: json['scope'] as String,
  action: json['action'] as String,
  payload: json['payload'] as Map<String, dynamic>,
  createdAt: DateTime.parse(json['createdAt'] as String),
  status: json['status'] as String? ?? 'pending',
  error: json['error'] as String?,
);

Map<String, dynamic> _$WorkCommandToJson(_WorkCommand instance) =>
    <String, dynamic>{
      'id': instance.id,
      'scope': instance.scope,
      'action': instance.action,
      'payload': instance.payload,
      'createdAt': instance.createdAt.toIso8601String(),
      'status': instance.status,
      'error': instance.error,
    };
