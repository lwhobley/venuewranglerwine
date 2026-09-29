import 'package:freezed_annotation/freezed_annotation.dart';
part 'workforce_models.freezed.dart';
part 'workforce_models.g.dart';

@freezed
abstract class WorkShift with _$WorkShift {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory WorkShift({
    required String id,
    required String organizationId,
    required String venueId,
    required String roleKey,
    required DateTime startsAt,
    required DateTime endsAt,
    required String status,
    @Default(1) int revision,
    @Default(1) int headcount,
    @Default('') String instructions,
    String? periodId,
    String? jobRoleId,
    String? departmentId,
    String? areaId,
    String? eventId,
  }) = _WorkShift;
  factory WorkShift.fromJson(Map<String, dynamic> json) =>
      _$WorkShiftFromJson(json);
}

@freezed
abstract class WorkStaff with _$WorkStaff {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory WorkStaff({
    required String id,
    required String userId,
    required String displayName,
    required String employmentStatus,
    required String employmentType,
    @Default(2400) int weeklyLimitMinutes,
    @Default(660) int minimumRestMinutes,
    @Default(1) int revision,
  }) = _WorkStaff;
  factory WorkStaff.fromJson(Map<String, dynamic> json) =>
      _$WorkStaffFromJson(json);
}

@freezed
abstract class ShiftAssignment with _$ShiftAssignment {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ShiftAssignment({
    required String id,
    required String shiftId,
    required String staffId,
    required String status,
    @Default(1) int revision,
    String? overrideReason,
  }) = _ShiftAssignment;
  factory ShiftAssignment.fromJson(Map<String, dynamic> json) =>
      _$ShiftAssignmentFromJson(json);
}

@freezed
abstract class WorkPeriod with _$WorkPeriod {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory WorkPeriod({
    required String id,
    required String name,
    required String startsOn,
    required String endsOn,
    required String status,
    @Default(1) int revision,
  }) = _WorkPeriod;
  factory WorkPeriod.fromJson(Map<String, dynamic> json) =>
      _$WorkPeriodFromJson(json);
}

@freezed
abstract class WorkCommand with _$WorkCommand {
  const factory WorkCommand({
    required String id,
    required String scope,
    required String action,
    required Map<String, dynamic> payload,
    required DateTime createdAt,
    @Default('pending') String status,
    String? error,
  }) = _WorkCommand;
  factory WorkCommand.fromJson(Map<String, dynamic> json) =>
      _$WorkCommandFromJson(json);
}

class WorkforceSnapshot {
  WorkforceSnapshot(Map<String, dynamic> data)
    : sections = Map.unmodifiable(
        data.map(
          (k, v) => MapEntry(
            k,
            List<Map<String, dynamic>>.unmodifiable(
              (v as List).map(
                (x) => Map<String, dynamic>.unmodifiable(
                  Map<String, dynamic>.from(x as Map),
                ),
              ),
            ),
          ),
        ),
      );
  final Map<String, List<Map<String, dynamic>>> sections;
  List<Map<String, dynamic>> rows(String table) => sections[table] ?? const [];
  List<WorkShift> get shifts => rows('shifts').map(WorkShift.fromJson).toList();
  List<WorkStaff> get staff =>
      rows('staff_profiles').map(WorkStaff.fromJson).toList();
  List<ShiftAssignment> get assignments =>
      rows('shift_assignments').map(ShiftAssignment.fromJson).toList();
  List<WorkPeriod> get periods =>
      rows('schedule_periods').map(WorkPeriod.fromJson).toList();
  String label(String table, String? id) {
    for (final row in rows(table)) {
      if (row['id'] == id) {
        return (row['name'] ?? row['display_name'] ?? row['key'] ?? id)
            .toString();
      }
    }
    return id == null ? 'None' : 'Unavailable';
  }
}
