// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workforce_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WorkShift {

 String get id; String get organizationId; String get venueId; String get roleKey; DateTime get startsAt; DateTime get endsAt; String get status; int get revision; int get headcount; String get instructions; String? get periodId; String? get jobRoleId; String? get departmentId; String? get areaId; String? get eventId;
/// Create a copy of WorkShift
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkShiftCopyWith<WorkShift> get copyWith => _$WorkShiftCopyWithImpl<WorkShift>(this as WorkShift, _$identity);

  /// Serializes this WorkShift to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WorkShift;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkShift&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.organizationId, _this.organizationId) || other.organizationId == _this.organizationId)&&(identical(other.venueId, _this.venueId) || other.venueId == _this.venueId)&&(identical(other.roleKey, _this.roleKey) || other.roleKey == _this.roleKey)&&(identical(other.startsAt, _this.startsAt) || other.startsAt == _this.startsAt)&&(identical(other.endsAt, _this.endsAt) || other.endsAt == _this.endsAt)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&(identical(other.headcount, _this.headcount) || other.headcount == _this.headcount)&&(identical(other.instructions, _this.instructions) || other.instructions == _this.instructions)&&(identical(other.periodId, _this.periodId) || other.periodId == _this.periodId)&&(identical(other.jobRoleId, _this.jobRoleId) || other.jobRoleId == _this.jobRoleId)&&(identical(other.departmentId, _this.departmentId) || other.departmentId == _this.departmentId)&&(identical(other.areaId, _this.areaId) || other.areaId == _this.areaId)&&(identical(other.eventId, _this.eventId) || other.eventId == _this.eventId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WorkShift;
  return Object.hash(runtimeType,_this.id,_this.organizationId,_this.venueId,_this.roleKey,_this.startsAt,_this.endsAt,_this.status,_this.revision,_this.headcount,_this.instructions,_this.periodId,_this.jobRoleId,_this.departmentId,_this.areaId,_this.eventId);
}

@override
String toString() {
  final _this = this as WorkShift;
  return 'WorkShift(id: ${_this.id}, organizationId: ${_this.organizationId}, venueId: ${_this.venueId}, roleKey: ${_this.roleKey}, startsAt: ${_this.startsAt}, endsAt: ${_this.endsAt}, status: ${_this.status}, revision: ${_this.revision}, headcount: ${_this.headcount}, instructions: ${_this.instructions}, periodId: ${_this.periodId}, jobRoleId: ${_this.jobRoleId}, departmentId: ${_this.departmentId}, areaId: ${_this.areaId}, eventId: ${_this.eventId})';
}


}

/// @nodoc
abstract mixin class $WorkShiftCopyWith<$Res>  {
  factory $WorkShiftCopyWith(WorkShift value, $Res Function(WorkShift) _then) = _$WorkShiftCopyWithImpl;
@useResult
$Res call({
 String id, String organizationId, String venueId, String roleKey, DateTime startsAt, DateTime endsAt, String status, int revision, int headcount, String instructions, String? periodId, String? jobRoleId, String? departmentId, String? areaId, String? eventId
});




}
/// @nodoc
class _$WorkShiftCopyWithImpl<$Res>
    implements $WorkShiftCopyWith<$Res> {
  _$WorkShiftCopyWithImpl(this._self, this._then);

  final WorkShift _self;
  final $Res Function(WorkShift) _then;

/// Create a copy of WorkShift
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? organizationId = null,Object? venueId = null,Object? roleKey = null,Object? startsAt = null,Object? endsAt = null,Object? status = null,Object? revision = null,Object? headcount = null,Object? instructions = null,Object? periodId = freezed,Object? jobRoleId = freezed,Object? departmentId = freezed,Object? areaId = freezed,Object? eventId = freezed,}) {
  return _then(WorkShift(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,organizationId: null == organizationId ? _self.organizationId : organizationId // ignore: cast_nullable_to_non_nullable
as String,venueId: null == venueId ? _self.venueId : venueId // ignore: cast_nullable_to_non_nullable
as String,roleKey: null == roleKey ? _self.roleKey : roleKey // ignore: cast_nullable_to_non_nullable
as String,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,headcount: null == headcount ? _self.headcount : headcount // ignore: cast_nullable_to_non_nullable
as int,instructions: null == instructions ? _self.instructions : instructions // ignore: cast_nullable_to_non_nullable
as String,periodId: freezed == periodId ? _self.periodId : periodId // ignore: cast_nullable_to_non_nullable
as String?,jobRoleId: freezed == jobRoleId ? _self.jobRoleId : jobRoleId // ignore: cast_nullable_to_non_nullable
as String?,departmentId: freezed == departmentId ? _self.departmentId : departmentId // ignore: cast_nullable_to_non_nullable
as String?,areaId: freezed == areaId ? _self.areaId : areaId // ignore: cast_nullable_to_non_nullable
as String?,eventId: freezed == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkShift].
extension WorkShiftPatterns on WorkShift {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkShift value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkShift() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkShift value)  $default,){
final _that = this;
switch (_that) {
case _WorkShift():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkShift value)?  $default,){
final _that = this;
switch (_that) {
case _WorkShift() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String organizationId,  String venueId,  String roleKey,  DateTime startsAt,  DateTime endsAt,  String status,  int revision,  int headcount,  String instructions,  String? periodId,  String? jobRoleId,  String? departmentId,  String? areaId,  String? eventId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkShift() when $default != null:
return $default(_that.id,_that.organizationId,_that.venueId,_that.roleKey,_that.startsAt,_that.endsAt,_that.status,_that.revision,_that.headcount,_that.instructions,_that.periodId,_that.jobRoleId,_that.departmentId,_that.areaId,_that.eventId);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String organizationId,  String venueId,  String roleKey,  DateTime startsAt,  DateTime endsAt,  String status,  int revision,  int headcount,  String instructions,  String? periodId,  String? jobRoleId,  String? departmentId,  String? areaId,  String? eventId)  $default,) {final _that = this;
switch (_that) {
case _WorkShift():
return $default(_that.id,_that.organizationId,_that.venueId,_that.roleKey,_that.startsAt,_that.endsAt,_that.status,_that.revision,_that.headcount,_that.instructions,_that.periodId,_that.jobRoleId,_that.departmentId,_that.areaId,_that.eventId);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String organizationId,  String venueId,  String roleKey,  DateTime startsAt,  DateTime endsAt,  String status,  int revision,  int headcount,  String instructions,  String? periodId,  String? jobRoleId,  String? departmentId,  String? areaId,  String? eventId)?  $default,) {final _that = this;
switch (_that) {
case _WorkShift() when $default != null:
return $default(_that.id,_that.organizationId,_that.venueId,_that.roleKey,_that.startsAt,_that.endsAt,_that.status,_that.revision,_that.headcount,_that.instructions,_that.periodId,_that.jobRoleId,_that.departmentId,_that.areaId,_that.eventId);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _WorkShift implements WorkShift {
  const _WorkShift({required this.id, required this.organizationId, required this.venueId, required this.roleKey, required this.startsAt, required this.endsAt, required this.status, this.revision = 1, this.headcount = 1, this.instructions = '', this.periodId, this.jobRoleId, this.departmentId, this.areaId, this.eventId});
  factory _WorkShift.fromJson(Map<String, dynamic> json) => _$WorkShiftFromJson(json);

@override final  String id;
@override final  String organizationId;
@override final  String venueId;
@override final  String roleKey;
@override final  DateTime startsAt;
@override final  DateTime endsAt;
@override final  String status;
@override@JsonKey() final  int revision;
@override@JsonKey() final  int headcount;
@override@JsonKey() final  String instructions;
@override final  String? periodId;
@override final  String? jobRoleId;
@override final  String? departmentId;
@override final  String? areaId;
@override final  String? eventId;

/// Create a copy of WorkShift
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkShiftCopyWith<_WorkShift> get copyWith => __$WorkShiftCopyWithImpl<_WorkShift>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkShiftToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkShift&&(identical(other.id, id) || other.id == id)&&(identical(other.organizationId, organizationId) || other.organizationId == organizationId)&&(identical(other.venueId, venueId) || other.venueId == venueId)&&(identical(other.roleKey, roleKey) || other.roleKey == roleKey)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.headcount, headcount) || other.headcount == headcount)&&(identical(other.instructions, instructions) || other.instructions == instructions)&&(identical(other.periodId, periodId) || other.periodId == periodId)&&(identical(other.jobRoleId, jobRoleId) || other.jobRoleId == jobRoleId)&&(identical(other.departmentId, departmentId) || other.departmentId == departmentId)&&(identical(other.areaId, areaId) || other.areaId == areaId)&&(identical(other.eventId, eventId) || other.eventId == eventId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,organizationId,venueId,roleKey,startsAt,endsAt,status,revision,headcount,instructions,periodId,jobRoleId,departmentId,areaId,eventId);
}

@override
String toString() {
    return 'WorkShift(id: $id, organizationId: $organizationId, venueId: $venueId, roleKey: $roleKey, startsAt: $startsAt, endsAt: $endsAt, status: $status, revision: $revision, headcount: $headcount, instructions: $instructions, periodId: $periodId, jobRoleId: $jobRoleId, departmentId: $departmentId, areaId: $areaId, eventId: $eventId)';
}


}

/// @nodoc
abstract mixin class _$WorkShiftCopyWith<$Res> implements $WorkShiftCopyWith<$Res> {
  factory _$WorkShiftCopyWith(_WorkShift value, $Res Function(_WorkShift) _then) = __$WorkShiftCopyWithImpl;
@override @useResult
$Res call({
 String id, String organizationId, String venueId, String roleKey, DateTime startsAt, DateTime endsAt, String status, int revision, int headcount, String instructions, String? periodId, String? jobRoleId, String? departmentId, String? areaId, String? eventId
});




}
/// @nodoc
class __$WorkShiftCopyWithImpl<$Res>
    implements _$WorkShiftCopyWith<$Res> {
  __$WorkShiftCopyWithImpl(this._self, this._then);

  final _WorkShift _self;
  final $Res Function(_WorkShift) _then;

/// Create a copy of WorkShift
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? organizationId = null,Object? venueId = null,Object? roleKey = null,Object? startsAt = null,Object? endsAt = null,Object? status = null,Object? revision = null,Object? headcount = null,Object? instructions = null,Object? periodId = freezed,Object? jobRoleId = freezed,Object? departmentId = freezed,Object? areaId = freezed,Object? eventId = freezed,}) {
  return _then(_WorkShift(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,organizationId: null == organizationId ? _self.organizationId : organizationId // ignore: cast_nullable_to_non_nullable
as String,venueId: null == venueId ? _self.venueId : venueId // ignore: cast_nullable_to_non_nullable
as String,roleKey: null == roleKey ? _self.roleKey : roleKey // ignore: cast_nullable_to_non_nullable
as String,startsAt: null == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime,endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,headcount: null == headcount ? _self.headcount : headcount // ignore: cast_nullable_to_non_nullable
as int,instructions: null == instructions ? _self.instructions : instructions // ignore: cast_nullable_to_non_nullable
as String,periodId: freezed == periodId ? _self.periodId : periodId // ignore: cast_nullable_to_non_nullable
as String?,jobRoleId: freezed == jobRoleId ? _self.jobRoleId : jobRoleId // ignore: cast_nullable_to_non_nullable
as String?,departmentId: freezed == departmentId ? _self.departmentId : departmentId // ignore: cast_nullable_to_non_nullable
as String?,areaId: freezed == areaId ? _self.areaId : areaId // ignore: cast_nullable_to_non_nullable
as String?,eventId: freezed == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$WorkStaff {

 String get id; String get userId; String get displayName; String get employmentStatus; String get employmentType; int get weeklyLimitMinutes; int get minimumRestMinutes; int get revision;
/// Create a copy of WorkStaff
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkStaffCopyWith<WorkStaff> get copyWith => _$WorkStaffCopyWithImpl<WorkStaff>(this as WorkStaff, _$identity);

  /// Serializes this WorkStaff to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WorkStaff;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkStaff&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.employmentStatus, _this.employmentStatus) || other.employmentStatus == _this.employmentStatus)&&(identical(other.employmentType, _this.employmentType) || other.employmentType == _this.employmentType)&&(identical(other.weeklyLimitMinutes, _this.weeklyLimitMinutes) || other.weeklyLimitMinutes == _this.weeklyLimitMinutes)&&(identical(other.minimumRestMinutes, _this.minimumRestMinutes) || other.minimumRestMinutes == _this.minimumRestMinutes)&&(identical(other.revision, _this.revision) || other.revision == _this.revision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WorkStaff;
  return Object.hash(runtimeType,_this.id,_this.userId,_this.displayName,_this.employmentStatus,_this.employmentType,_this.weeklyLimitMinutes,_this.minimumRestMinutes,_this.revision);
}

@override
String toString() {
  final _this = this as WorkStaff;
  return 'WorkStaff(id: ${_this.id}, userId: ${_this.userId}, displayName: ${_this.displayName}, employmentStatus: ${_this.employmentStatus}, employmentType: ${_this.employmentType}, weeklyLimitMinutes: ${_this.weeklyLimitMinutes}, minimumRestMinutes: ${_this.minimumRestMinutes}, revision: ${_this.revision})';
}


}

/// @nodoc
abstract mixin class $WorkStaffCopyWith<$Res>  {
  factory $WorkStaffCopyWith(WorkStaff value, $Res Function(WorkStaff) _then) = _$WorkStaffCopyWithImpl;
@useResult
$Res call({
 String id, String userId, String displayName, String employmentStatus, String employmentType, int weeklyLimitMinutes, int minimumRestMinutes, int revision
});




}
/// @nodoc
class _$WorkStaffCopyWithImpl<$Res>
    implements $WorkStaffCopyWith<$Res> {
  _$WorkStaffCopyWithImpl(this._self, this._then);

  final WorkStaff _self;
  final $Res Function(WorkStaff) _then;

/// Create a copy of WorkStaff
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? displayName = null,Object? employmentStatus = null,Object? employmentType = null,Object? weeklyLimitMinutes = null,Object? minimumRestMinutes = null,Object? revision = null,}) {
  return _then(WorkStaff(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,employmentStatus: null == employmentStatus ? _self.employmentStatus : employmentStatus // ignore: cast_nullable_to_non_nullable
as String,employmentType: null == employmentType ? _self.employmentType : employmentType // ignore: cast_nullable_to_non_nullable
as String,weeklyLimitMinutes: null == weeklyLimitMinutes ? _self.weeklyLimitMinutes : weeklyLimitMinutes // ignore: cast_nullable_to_non_nullable
as int,minimumRestMinutes: null == minimumRestMinutes ? _self.minimumRestMinutes : minimumRestMinutes // ignore: cast_nullable_to_non_nullable
as int,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkStaff].
extension WorkStaffPatterns on WorkStaff {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkStaff value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkStaff() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkStaff value)  $default,){
final _that = this;
switch (_that) {
case _WorkStaff():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkStaff value)?  $default,){
final _that = this;
switch (_that) {
case _WorkStaff() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userId,  String displayName,  String employmentStatus,  String employmentType,  int weeklyLimitMinutes,  int minimumRestMinutes,  int revision)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkStaff() when $default != null:
return $default(_that.id,_that.userId,_that.displayName,_that.employmentStatus,_that.employmentType,_that.weeklyLimitMinutes,_that.minimumRestMinutes,_that.revision);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userId,  String displayName,  String employmentStatus,  String employmentType,  int weeklyLimitMinutes,  int minimumRestMinutes,  int revision)  $default,) {final _that = this;
switch (_that) {
case _WorkStaff():
return $default(_that.id,_that.userId,_that.displayName,_that.employmentStatus,_that.employmentType,_that.weeklyLimitMinutes,_that.minimumRestMinutes,_that.revision);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userId,  String displayName,  String employmentStatus,  String employmentType,  int weeklyLimitMinutes,  int minimumRestMinutes,  int revision)?  $default,) {final _that = this;
switch (_that) {
case _WorkStaff() when $default != null:
return $default(_that.id,_that.userId,_that.displayName,_that.employmentStatus,_that.employmentType,_that.weeklyLimitMinutes,_that.minimumRestMinutes,_that.revision);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _WorkStaff implements WorkStaff {
  const _WorkStaff({required this.id, required this.userId, required this.displayName, required this.employmentStatus, required this.employmentType, this.weeklyLimitMinutes = 2400, this.minimumRestMinutes = 660, this.revision = 1});
  factory _WorkStaff.fromJson(Map<String, dynamic> json) => _$WorkStaffFromJson(json);

@override final  String id;
@override final  String userId;
@override final  String displayName;
@override final  String employmentStatus;
@override final  String employmentType;
@override@JsonKey() final  int weeklyLimitMinutes;
@override@JsonKey() final  int minimumRestMinutes;
@override@JsonKey() final  int revision;

/// Create a copy of WorkStaff
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkStaffCopyWith<_WorkStaff> get copyWith => __$WorkStaffCopyWithImpl<_WorkStaff>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkStaffToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkStaff&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.employmentStatus, employmentStatus) || other.employmentStatus == employmentStatus)&&(identical(other.employmentType, employmentType) || other.employmentType == employmentType)&&(identical(other.weeklyLimitMinutes, weeklyLimitMinutes) || other.weeklyLimitMinutes == weeklyLimitMinutes)&&(identical(other.minimumRestMinutes, minimumRestMinutes) || other.minimumRestMinutes == minimumRestMinutes)&&(identical(other.revision, revision) || other.revision == revision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,userId,displayName,employmentStatus,employmentType,weeklyLimitMinutes,minimumRestMinutes,revision);
}

@override
String toString() {
    return 'WorkStaff(id: $id, userId: $userId, displayName: $displayName, employmentStatus: $employmentStatus, employmentType: $employmentType, weeklyLimitMinutes: $weeklyLimitMinutes, minimumRestMinutes: $minimumRestMinutes, revision: $revision)';
}


}

/// @nodoc
abstract mixin class _$WorkStaffCopyWith<$Res> implements $WorkStaffCopyWith<$Res> {
  factory _$WorkStaffCopyWith(_WorkStaff value, $Res Function(_WorkStaff) _then) = __$WorkStaffCopyWithImpl;
@override @useResult
$Res call({
 String id, String userId, String displayName, String employmentStatus, String employmentType, int weeklyLimitMinutes, int minimumRestMinutes, int revision
});




}
/// @nodoc
class __$WorkStaffCopyWithImpl<$Res>
    implements _$WorkStaffCopyWith<$Res> {
  __$WorkStaffCopyWithImpl(this._self, this._then);

  final _WorkStaff _self;
  final $Res Function(_WorkStaff) _then;

/// Create a copy of WorkStaff
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? displayName = null,Object? employmentStatus = null,Object? employmentType = null,Object? weeklyLimitMinutes = null,Object? minimumRestMinutes = null,Object? revision = null,}) {
  return _then(_WorkStaff(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,employmentStatus: null == employmentStatus ? _self.employmentStatus : employmentStatus // ignore: cast_nullable_to_non_nullable
as String,employmentType: null == employmentType ? _self.employmentType : employmentType // ignore: cast_nullable_to_non_nullable
as String,weeklyLimitMinutes: null == weeklyLimitMinutes ? _self.weeklyLimitMinutes : weeklyLimitMinutes // ignore: cast_nullable_to_non_nullable
as int,minimumRestMinutes: null == minimumRestMinutes ? _self.minimumRestMinutes : minimumRestMinutes // ignore: cast_nullable_to_non_nullable
as int,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ShiftAssignment {

 String get id; String get shiftId; String get staffId; String get status; int get revision; String? get overrideReason;
/// Create a copy of ShiftAssignment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShiftAssignmentCopyWith<ShiftAssignment> get copyWith => _$ShiftAssignmentCopyWithImpl<ShiftAssignment>(this as ShiftAssignment, _$identity);

  /// Serializes this ShiftAssignment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ShiftAssignment;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShiftAssignment&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.shiftId, _this.shiftId) || other.shiftId == _this.shiftId)&&(identical(other.staffId, _this.staffId) || other.staffId == _this.staffId)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&(identical(other.overrideReason, _this.overrideReason) || other.overrideReason == _this.overrideReason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ShiftAssignment;
  return Object.hash(runtimeType,_this.id,_this.shiftId,_this.staffId,_this.status,_this.revision,_this.overrideReason);
}

@override
String toString() {
  final _this = this as ShiftAssignment;
  return 'ShiftAssignment(id: ${_this.id}, shiftId: ${_this.shiftId}, staffId: ${_this.staffId}, status: ${_this.status}, revision: ${_this.revision}, overrideReason: ${_this.overrideReason})';
}


}

/// @nodoc
abstract mixin class $ShiftAssignmentCopyWith<$Res>  {
  factory $ShiftAssignmentCopyWith(ShiftAssignment value, $Res Function(ShiftAssignment) _then) = _$ShiftAssignmentCopyWithImpl;
@useResult
$Res call({
 String id, String shiftId, String staffId, String status, int revision, String? overrideReason
});




}
/// @nodoc
class _$ShiftAssignmentCopyWithImpl<$Res>
    implements $ShiftAssignmentCopyWith<$Res> {
  _$ShiftAssignmentCopyWithImpl(this._self, this._then);

  final ShiftAssignment _self;
  final $Res Function(ShiftAssignment) _then;

/// Create a copy of ShiftAssignment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? shiftId = null,Object? staffId = null,Object? status = null,Object? revision = null,Object? overrideReason = freezed,}) {
  return _then(ShiftAssignment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,shiftId: null == shiftId ? _self.shiftId : shiftId // ignore: cast_nullable_to_non_nullable
as String,staffId: null == staffId ? _self.staffId : staffId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,overrideReason: freezed == overrideReason ? _self.overrideReason : overrideReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ShiftAssignment].
extension ShiftAssignmentPatterns on ShiftAssignment {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ShiftAssignment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ShiftAssignment() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ShiftAssignment value)  $default,){
final _that = this;
switch (_that) {
case _ShiftAssignment():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ShiftAssignment value)?  $default,){
final _that = this;
switch (_that) {
case _ShiftAssignment() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String shiftId,  String staffId,  String status,  int revision,  String? overrideReason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ShiftAssignment() when $default != null:
return $default(_that.id,_that.shiftId,_that.staffId,_that.status,_that.revision,_that.overrideReason);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String shiftId,  String staffId,  String status,  int revision,  String? overrideReason)  $default,) {final _that = this;
switch (_that) {
case _ShiftAssignment():
return $default(_that.id,_that.shiftId,_that.staffId,_that.status,_that.revision,_that.overrideReason);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String shiftId,  String staffId,  String status,  int revision,  String? overrideReason)?  $default,) {final _that = this;
switch (_that) {
case _ShiftAssignment() when $default != null:
return $default(_that.id,_that.shiftId,_that.staffId,_that.status,_that.revision,_that.overrideReason);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _ShiftAssignment implements ShiftAssignment {
  const _ShiftAssignment({required this.id, required this.shiftId, required this.staffId, required this.status, this.revision = 1, this.overrideReason});
  factory _ShiftAssignment.fromJson(Map<String, dynamic> json) => _$ShiftAssignmentFromJson(json);

@override final  String id;
@override final  String shiftId;
@override final  String staffId;
@override final  String status;
@override@JsonKey() final  int revision;
@override final  String? overrideReason;

/// Create a copy of ShiftAssignment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShiftAssignmentCopyWith<_ShiftAssignment> get copyWith => __$ShiftAssignmentCopyWithImpl<_ShiftAssignment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ShiftAssignmentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShiftAssignment&&(identical(other.id, id) || other.id == id)&&(identical(other.shiftId, shiftId) || other.shiftId == shiftId)&&(identical(other.staffId, staffId) || other.staffId == staffId)&&(identical(other.status, status) || other.status == status)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.overrideReason, overrideReason) || other.overrideReason == overrideReason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,shiftId,staffId,status,revision,overrideReason);
}

@override
String toString() {
    return 'ShiftAssignment(id: $id, shiftId: $shiftId, staffId: $staffId, status: $status, revision: $revision, overrideReason: $overrideReason)';
}


}

/// @nodoc
abstract mixin class _$ShiftAssignmentCopyWith<$Res> implements $ShiftAssignmentCopyWith<$Res> {
  factory _$ShiftAssignmentCopyWith(_ShiftAssignment value, $Res Function(_ShiftAssignment) _then) = __$ShiftAssignmentCopyWithImpl;
@override @useResult
$Res call({
 String id, String shiftId, String staffId, String status, int revision, String? overrideReason
});




}
/// @nodoc
class __$ShiftAssignmentCopyWithImpl<$Res>
    implements _$ShiftAssignmentCopyWith<$Res> {
  __$ShiftAssignmentCopyWithImpl(this._self, this._then);

  final _ShiftAssignment _self;
  final $Res Function(_ShiftAssignment) _then;

/// Create a copy of ShiftAssignment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? shiftId = null,Object? staffId = null,Object? status = null,Object? revision = null,Object? overrideReason = freezed,}) {
  return _then(_ShiftAssignment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,shiftId: null == shiftId ? _self.shiftId : shiftId // ignore: cast_nullable_to_non_nullable
as String,staffId: null == staffId ? _self.staffId : staffId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,overrideReason: freezed == overrideReason ? _self.overrideReason : overrideReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$WorkPeriod {

 String get id; String get name; String get startsOn; String get endsOn; String get status; int get revision;
/// Create a copy of WorkPeriod
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkPeriodCopyWith<WorkPeriod> get copyWith => _$WorkPeriodCopyWithImpl<WorkPeriod>(this as WorkPeriod, _$identity);

  /// Serializes this WorkPeriod to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WorkPeriod;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkPeriod&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.startsOn, _this.startsOn) || other.startsOn == _this.startsOn)&&(identical(other.endsOn, _this.endsOn) || other.endsOn == _this.endsOn)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.revision, _this.revision) || other.revision == _this.revision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WorkPeriod;
  return Object.hash(runtimeType,_this.id,_this.name,_this.startsOn,_this.endsOn,_this.status,_this.revision);
}

@override
String toString() {
  final _this = this as WorkPeriod;
  return 'WorkPeriod(id: ${_this.id}, name: ${_this.name}, startsOn: ${_this.startsOn}, endsOn: ${_this.endsOn}, status: ${_this.status}, revision: ${_this.revision})';
}


}

/// @nodoc
abstract mixin class $WorkPeriodCopyWith<$Res>  {
  factory $WorkPeriodCopyWith(WorkPeriod value, $Res Function(WorkPeriod) _then) = _$WorkPeriodCopyWithImpl;
@useResult
$Res call({
 String id, String name, String startsOn, String endsOn, String status, int revision
});




}
/// @nodoc
class _$WorkPeriodCopyWithImpl<$Res>
    implements $WorkPeriodCopyWith<$Res> {
  _$WorkPeriodCopyWithImpl(this._self, this._then);

  final WorkPeriod _self;
  final $Res Function(WorkPeriod) _then;

/// Create a copy of WorkPeriod
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? startsOn = null,Object? endsOn = null,Object? status = null,Object? revision = null,}) {
  return _then(WorkPeriod(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,startsOn: null == startsOn ? _self.startsOn : startsOn // ignore: cast_nullable_to_non_nullable
as String,endsOn: null == endsOn ? _self.endsOn : endsOn // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkPeriod].
extension WorkPeriodPatterns on WorkPeriod {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkPeriod value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkPeriod() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkPeriod value)  $default,){
final _that = this;
switch (_that) {
case _WorkPeriod():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkPeriod value)?  $default,){
final _that = this;
switch (_that) {
case _WorkPeriod() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String startsOn,  String endsOn,  String status,  int revision)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkPeriod() when $default != null:
return $default(_that.id,_that.name,_that.startsOn,_that.endsOn,_that.status,_that.revision);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String startsOn,  String endsOn,  String status,  int revision)  $default,) {final _that = this;
switch (_that) {
case _WorkPeriod():
return $default(_that.id,_that.name,_that.startsOn,_that.endsOn,_that.status,_that.revision);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String startsOn,  String endsOn,  String status,  int revision)?  $default,) {final _that = this;
switch (_that) {
case _WorkPeriod() when $default != null:
return $default(_that.id,_that.name,_that.startsOn,_that.endsOn,_that.status,_that.revision);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _WorkPeriod implements WorkPeriod {
  const _WorkPeriod({required this.id, required this.name, required this.startsOn, required this.endsOn, required this.status, this.revision = 1});
  factory _WorkPeriod.fromJson(Map<String, dynamic> json) => _$WorkPeriodFromJson(json);

@override final  String id;
@override final  String name;
@override final  String startsOn;
@override final  String endsOn;
@override final  String status;
@override@JsonKey() final  int revision;

/// Create a copy of WorkPeriod
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkPeriodCopyWith<_WorkPeriod> get copyWith => __$WorkPeriodCopyWithImpl<_WorkPeriod>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkPeriodToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkPeriod&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.startsOn, startsOn) || other.startsOn == startsOn)&&(identical(other.endsOn, endsOn) || other.endsOn == endsOn)&&(identical(other.status, status) || other.status == status)&&(identical(other.revision, revision) || other.revision == revision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,startsOn,endsOn,status,revision);
}

@override
String toString() {
    return 'WorkPeriod(id: $id, name: $name, startsOn: $startsOn, endsOn: $endsOn, status: $status, revision: $revision)';
}


}

/// @nodoc
abstract mixin class _$WorkPeriodCopyWith<$Res> implements $WorkPeriodCopyWith<$Res> {
  factory _$WorkPeriodCopyWith(_WorkPeriod value, $Res Function(_WorkPeriod) _then) = __$WorkPeriodCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String startsOn, String endsOn, String status, int revision
});




}
/// @nodoc
class __$WorkPeriodCopyWithImpl<$Res>
    implements _$WorkPeriodCopyWith<$Res> {
  __$WorkPeriodCopyWithImpl(this._self, this._then);

  final _WorkPeriod _self;
  final $Res Function(_WorkPeriod) _then;

/// Create a copy of WorkPeriod
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? startsOn = null,Object? endsOn = null,Object? status = null,Object? revision = null,}) {
  return _then(_WorkPeriod(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,startsOn: null == startsOn ? _self.startsOn : startsOn // ignore: cast_nullable_to_non_nullable
as String,endsOn: null == endsOn ? _self.endsOn : endsOn // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$WorkCommand {

 String get id; String get scope; String get action; Map<String, dynamic> get payload; DateTime get createdAt; String get status; String? get error;
/// Create a copy of WorkCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkCommandCopyWith<WorkCommand> get copyWith => _$WorkCommandCopyWithImpl<WorkCommand>(this as WorkCommand, _$identity);

  /// Serializes this WorkCommand to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WorkCommand;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkCommand&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.scope, _this.scope) || other.scope == _this.scope)&&(identical(other.action, _this.action) || other.action == _this.action)&&const DeepCollectionEquality().equals(other.payload, _this.payload)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.error, _this.error) || other.error == _this.error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WorkCommand;
  return Object.hash(runtimeType,_this.id,_this.scope,_this.action,const DeepCollectionEquality().hash(_this.payload),_this.createdAt,_this.status,_this.error);
}

@override
String toString() {
  final _this = this as WorkCommand;
  return 'WorkCommand(id: ${_this.id}, scope: ${_this.scope}, action: ${_this.action}, payload: ${_this.payload}, createdAt: ${_this.createdAt}, status: ${_this.status}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $WorkCommandCopyWith<$Res>  {
  factory $WorkCommandCopyWith(WorkCommand value, $Res Function(WorkCommand) _then) = _$WorkCommandCopyWithImpl;
@useResult
$Res call({
 String id, String scope, String action, Map<String, dynamic> payload, DateTime createdAt, String status, String? error
});




}
/// @nodoc
class _$WorkCommandCopyWithImpl<$Res>
    implements $WorkCommandCopyWith<$Res> {
  _$WorkCommandCopyWithImpl(this._self, this._then);

  final WorkCommand _self;
  final $Res Function(WorkCommand) _then;

/// Create a copy of WorkCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? scope = null,Object? action = null,Object? payload = null,Object? createdAt = null,Object? status = null,Object? error = freezed,}) {
  return _then(WorkCommand(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as String,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkCommand].
extension WorkCommandPatterns on WorkCommand {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkCommand value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkCommand() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkCommand value)  $default,){
final _that = this;
switch (_that) {
case _WorkCommand():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkCommand value)?  $default,){
final _that = this;
switch (_that) {
case _WorkCommand() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String scope,  String action,  Map<String, dynamic> payload,  DateTime createdAt,  String status,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkCommand() when $default != null:
return $default(_that.id,_that.scope,_that.action,_that.payload,_that.createdAt,_that.status,_that.error);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String scope,  String action,  Map<String, dynamic> payload,  DateTime createdAt,  String status,  String? error)  $default,) {final _that = this;
switch (_that) {
case _WorkCommand():
return $default(_that.id,_that.scope,_that.action,_that.payload,_that.createdAt,_that.status,_that.error);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String scope,  String action,  Map<String, dynamic> payload,  DateTime createdAt,  String status,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _WorkCommand() when $default != null:
return $default(_that.id,_that.scope,_that.action,_that.payload,_that.createdAt,_that.status,_that.error);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkCommand implements WorkCommand {
  const _WorkCommand({required this.id, required this.scope, required this.action, required  Map<String, dynamic> payload, required this.createdAt, this.status = 'pending', this.error}): _payload = payload;
  factory _WorkCommand.fromJson(Map<String, dynamic> json) => _$WorkCommandFromJson(json);

@override final  String id;
@override final  String scope;
@override final  String action;
 final  Map<String, dynamic> _payload;
@override Map<String, dynamic> get payload {
  if (_payload is EqualUnmodifiableMapView) return _payload;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_payload);
}

@override final  DateTime createdAt;
@override@JsonKey() final  String status;
@override final  String? error;

/// Create a copy of WorkCommand
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkCommandCopyWith<_WorkCommand> get copyWith => __$WorkCommandCopyWithImpl<_WorkCommand>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkCommandToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkCommand&&(identical(other.id, id) || other.id == id)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.action, action) || other.action == action)&&const DeepCollectionEquality().equals(other.payload, _payload)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,scope,action,const DeepCollectionEquality().hash(_payload),createdAt,status,error);
}

@override
String toString() {
    return 'WorkCommand(id: $id, scope: $scope, action: $action, payload: $payload, createdAt: $createdAt, status: $status, error: $error)';
}


}

/// @nodoc
abstract mixin class _$WorkCommandCopyWith<$Res> implements $WorkCommandCopyWith<$Res> {
  factory _$WorkCommandCopyWith(_WorkCommand value, $Res Function(_WorkCommand) _then) = __$WorkCommandCopyWithImpl;
@override @useResult
$Res call({
 String id, String scope, String action, Map<String, dynamic> payload, DateTime createdAt, String status, String? error
});




}
/// @nodoc
class __$WorkCommandCopyWithImpl<$Res>
    implements _$WorkCommandCopyWith<$Res> {
  __$WorkCommandCopyWithImpl(this._self, this._then);

  final _WorkCommand _self;
  final $Res Function(_WorkCommand) _then;

/// Create a copy of WorkCommand
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? scope = null,Object? action = null,Object? payload = null,Object? createdAt = null,Object? status = null,Object? error = freezed,}) {
  return _then(_WorkCommand(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as String,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self._payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
