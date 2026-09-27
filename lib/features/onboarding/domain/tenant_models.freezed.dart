// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tenant_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Organization {

 String get id; String get name; String get slug; String? get legalName;
/// Create a copy of Organization
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrganizationCopyWith<Organization> get copyWith => _$OrganizationCopyWithImpl<Organization>(this as Organization, _$identity);

  /// Serializes this Organization to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Organization;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Organization&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.legalName, _this.legalName) || other.legalName == _this.legalName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Organization;
  return Object.hash(runtimeType,_this.id,_this.name,_this.slug,_this.legalName);
}

@override
String toString() {
  final _this = this as Organization;
  return 'Organization(id: ${_this.id}, name: ${_this.name}, slug: ${_this.slug}, legalName: ${_this.legalName})';
}


}

/// @nodoc
abstract mixin class $OrganizationCopyWith<$Res>  {
  factory $OrganizationCopyWith(Organization value, $Res Function(Organization) _then) = _$OrganizationCopyWithImpl;
@useResult
$Res call({
 String id, String name, String slug, String? legalName
});




}
/// @nodoc
class _$OrganizationCopyWithImpl<$Res>
    implements $OrganizationCopyWith<$Res> {
  _$OrganizationCopyWithImpl(this._self, this._then);

  final Organization _self;
  final $Res Function(Organization) _then;

/// Create a copy of Organization
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? slug = null,Object? legalName = freezed,}) {
  return _then(Organization(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,legalName: freezed == legalName ? _self.legalName : legalName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Organization].
extension OrganizationPatterns on Organization {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Organization value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Organization() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Organization value)  $default,){
final _that = this;
switch (_that) {
case _Organization():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Organization value)?  $default,){
final _that = this;
switch (_that) {
case _Organization() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String slug,  String? legalName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Organization() when $default != null:
return $default(_that.id,_that.name,_that.slug,_that.legalName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String slug,  String? legalName)  $default,) {final _that = this;
switch (_that) {
case _Organization():
return $default(_that.id,_that.name,_that.slug,_that.legalName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String slug,  String? legalName)?  $default,) {final _that = this;
switch (_that) {
case _Organization() when $default != null:
return $default(_that.id,_that.name,_that.slug,_that.legalName);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _Organization implements Organization {
  const _Organization({required this.id, required this.name, required this.slug, this.legalName});
  factory _Organization.fromJson(Map<String, dynamic> json) => _$OrganizationFromJson(json);

@override final  String id;
@override final  String name;
@override final  String slug;
@override final  String? legalName;

/// Create a copy of Organization
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrganizationCopyWith<_Organization> get copyWith => __$OrganizationCopyWithImpl<_Organization>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrganizationToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Organization&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.legalName, legalName) || other.legalName == legalName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,slug,legalName);
}

@override
String toString() {
    return 'Organization(id: $id, name: $name, slug: $slug, legalName: $legalName)';
}


}

/// @nodoc
abstract mixin class _$OrganizationCopyWith<$Res> implements $OrganizationCopyWith<$Res> {
  factory _$OrganizationCopyWith(_Organization value, $Res Function(_Organization) _then) = __$OrganizationCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String slug, String? legalName
});




}
/// @nodoc
class __$OrganizationCopyWithImpl<$Res>
    implements _$OrganizationCopyWith<$Res> {
  __$OrganizationCopyWithImpl(this._self, this._then);

  final _Organization _self;
  final $Res Function(_Organization) _then;

/// Create a copy of Organization
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? slug = null,Object? legalName = freezed,}) {
  return _then(_Organization(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,legalName: freezed == legalName ? _self.legalName : legalName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$Venue {

 String get id; String get organizationId; String get name; String get slug; String get timezone; String get currencyCode; String get serviceStyle; String get status; String? get city;
/// Create a copy of Venue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VenueCopyWith<Venue> get copyWith => _$VenueCopyWithImpl<Venue>(this as Venue, _$identity);

  /// Serializes this Venue to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Venue;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Venue&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.organizationId, _this.organizationId) || other.organizationId == _this.organizationId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.timezone, _this.timezone) || other.timezone == _this.timezone)&&(identical(other.currencyCode, _this.currencyCode) || other.currencyCode == _this.currencyCode)&&(identical(other.serviceStyle, _this.serviceStyle) || other.serviceStyle == _this.serviceStyle)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.city, _this.city) || other.city == _this.city));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Venue;
  return Object.hash(runtimeType,_this.id,_this.organizationId,_this.name,_this.slug,_this.timezone,_this.currencyCode,_this.serviceStyle,_this.status,_this.city);
}

@override
String toString() {
  final _this = this as Venue;
  return 'Venue(id: ${_this.id}, organizationId: ${_this.organizationId}, name: ${_this.name}, slug: ${_this.slug}, timezone: ${_this.timezone}, currencyCode: ${_this.currencyCode}, serviceStyle: ${_this.serviceStyle}, status: ${_this.status}, city: ${_this.city})';
}


}

/// @nodoc
abstract mixin class $VenueCopyWith<$Res>  {
  factory $VenueCopyWith(Venue value, $Res Function(Venue) _then) = _$VenueCopyWithImpl;
@useResult
$Res call({
 String id, String organizationId, String name, String slug, String timezone, String currencyCode, String serviceStyle, String status, String? city
});




}
/// @nodoc
class _$VenueCopyWithImpl<$Res>
    implements $VenueCopyWith<$Res> {
  _$VenueCopyWithImpl(this._self, this._then);

  final Venue _self;
  final $Res Function(Venue) _then;

/// Create a copy of Venue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? organizationId = null,Object? name = null,Object? slug = null,Object? timezone = null,Object? currencyCode = null,Object? serviceStyle = null,Object? status = null,Object? city = freezed,}) {
  return _then(Venue(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,organizationId: null == organizationId ? _self.organizationId : organizationId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,serviceStyle: null == serviceStyle ? _self.serviceStyle : serviceStyle // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Venue].
extension VenuePatterns on Venue {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Venue value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Venue() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Venue value)  $default,){
final _that = this;
switch (_that) {
case _Venue():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Venue value)?  $default,){
final _that = this;
switch (_that) {
case _Venue() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String organizationId,  String name,  String slug,  String timezone,  String currencyCode,  String serviceStyle,  String status,  String? city)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Venue() when $default != null:
return $default(_that.id,_that.organizationId,_that.name,_that.slug,_that.timezone,_that.currencyCode,_that.serviceStyle,_that.status,_that.city);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String organizationId,  String name,  String slug,  String timezone,  String currencyCode,  String serviceStyle,  String status,  String? city)  $default,) {final _that = this;
switch (_that) {
case _Venue():
return $default(_that.id,_that.organizationId,_that.name,_that.slug,_that.timezone,_that.currencyCode,_that.serviceStyle,_that.status,_that.city);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String organizationId,  String name,  String slug,  String timezone,  String currencyCode,  String serviceStyle,  String status,  String? city)?  $default,) {final _that = this;
switch (_that) {
case _Venue() when $default != null:
return $default(_that.id,_that.organizationId,_that.name,_that.slug,_that.timezone,_that.currencyCode,_that.serviceStyle,_that.status,_that.city);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _Venue implements Venue {
  const _Venue({required this.id, required this.organizationId, required this.name, required this.slug, required this.timezone, required this.currencyCode, required this.serviceStyle, required this.status, this.city});
  factory _Venue.fromJson(Map<String, dynamic> json) => _$VenueFromJson(json);

@override final  String id;
@override final  String organizationId;
@override final  String name;
@override final  String slug;
@override final  String timezone;
@override final  String currencyCode;
@override final  String serviceStyle;
@override final  String status;
@override final  String? city;

/// Create a copy of Venue
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VenueCopyWith<_Venue> get copyWith => __$VenueCopyWithImpl<_Venue>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VenueToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Venue&&(identical(other.id, id) || other.id == id)&&(identical(other.organizationId, organizationId) || other.organizationId == organizationId)&&(identical(other.name, name) || other.name == name)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.serviceStyle, serviceStyle) || other.serviceStyle == serviceStyle)&&(identical(other.status, status) || other.status == status)&&(identical(other.city, city) || other.city == city));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,organizationId,name,slug,timezone,currencyCode,serviceStyle,status,city);
}

@override
String toString() {
    return 'Venue(id: $id, organizationId: $organizationId, name: $name, slug: $slug, timezone: $timezone, currencyCode: $currencyCode, serviceStyle: $serviceStyle, status: $status, city: $city)';
}


}

/// @nodoc
abstract mixin class _$VenueCopyWith<$Res> implements $VenueCopyWith<$Res> {
  factory _$VenueCopyWith(_Venue value, $Res Function(_Venue) _then) = __$VenueCopyWithImpl;
@override @useResult
$Res call({
 String id, String organizationId, String name, String slug, String timezone, String currencyCode, String serviceStyle, String status, String? city
});




}
/// @nodoc
class __$VenueCopyWithImpl<$Res>
    implements _$VenueCopyWith<$Res> {
  __$VenueCopyWithImpl(this._self, this._then);

  final _Venue _self;
  final $Res Function(_Venue) _then;

/// Create a copy of Venue
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? organizationId = null,Object? name = null,Object? slug = null,Object? timezone = null,Object? currencyCode = null,Object? serviceStyle = null,Object? status = null,Object? city = freezed,}) {
  return _then(_Venue(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,organizationId: null == organizationId ? _self.organizationId : organizationId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,serviceStyle: null == serviceStyle ? _self.serviceStyle : serviceStyle // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$MembershipRecord {

 String get id; String get organizationId; String get userId; String get roleKey; String get status; String? get venueId; String? get displayName; String? get email;
/// Create a copy of MembershipRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MembershipRecordCopyWith<MembershipRecord> get copyWith => _$MembershipRecordCopyWithImpl<MembershipRecord>(this as MembershipRecord, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MembershipRecord;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MembershipRecord&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.organizationId, _this.organizationId) || other.organizationId == _this.organizationId)&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.roleKey, _this.roleKey) || other.roleKey == _this.roleKey)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.venueId, _this.venueId) || other.venueId == _this.venueId)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.email, _this.email) || other.email == _this.email));
}


@override
int get hashCode {
  final _this = this as MembershipRecord;
  return Object.hash(runtimeType,_this.id,_this.organizationId,_this.userId,_this.roleKey,_this.status,_this.venueId,_this.displayName,_this.email);
}

@override
String toString() {
  final _this = this as MembershipRecord;
  return 'MembershipRecord(id: ${_this.id}, organizationId: ${_this.organizationId}, userId: ${_this.userId}, roleKey: ${_this.roleKey}, status: ${_this.status}, venueId: ${_this.venueId}, displayName: ${_this.displayName}, email: ${_this.email})';
}


}

/// @nodoc
abstract mixin class $MembershipRecordCopyWith<$Res>  {
  factory $MembershipRecordCopyWith(MembershipRecord value, $Res Function(MembershipRecord) _then) = _$MembershipRecordCopyWithImpl;
@useResult
$Res call({
 String id, String organizationId, String userId, String roleKey, String status, String? venueId, String? displayName, String? email
});




}
/// @nodoc
class _$MembershipRecordCopyWithImpl<$Res>
    implements $MembershipRecordCopyWith<$Res> {
  _$MembershipRecordCopyWithImpl(this._self, this._then);

  final MembershipRecord _self;
  final $Res Function(MembershipRecord) _then;

/// Create a copy of MembershipRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? organizationId = null,Object? userId = null,Object? roleKey = null,Object? status = null,Object? venueId = freezed,Object? displayName = freezed,Object? email = freezed,}) {
  return _then(MembershipRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,organizationId: null == organizationId ? _self.organizationId : organizationId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,roleKey: null == roleKey ? _self.roleKey : roleKey // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,venueId: freezed == venueId ? _self.venueId : venueId // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MembershipRecord].
extension MembershipRecordPatterns on MembershipRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MembershipRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MembershipRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MembershipRecord value)  $default,){
final _that = this;
switch (_that) {
case _MembershipRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MembershipRecord value)?  $default,){
final _that = this;
switch (_that) {
case _MembershipRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String organizationId,  String userId,  String roleKey,  String status,  String? venueId,  String? displayName,  String? email)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MembershipRecord() when $default != null:
return $default(_that.id,_that.organizationId,_that.userId,_that.roleKey,_that.status,_that.venueId,_that.displayName,_that.email);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String organizationId,  String userId,  String roleKey,  String status,  String? venueId,  String? displayName,  String? email)  $default,) {final _that = this;
switch (_that) {
case _MembershipRecord():
return $default(_that.id,_that.organizationId,_that.userId,_that.roleKey,_that.status,_that.venueId,_that.displayName,_that.email);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String organizationId,  String userId,  String roleKey,  String status,  String? venueId,  String? displayName,  String? email)?  $default,) {final _that = this;
switch (_that) {
case _MembershipRecord() when $default != null:
return $default(_that.id,_that.organizationId,_that.userId,_that.roleKey,_that.status,_that.venueId,_that.displayName,_that.email);case _:
  return null;

}
}

}

/// @nodoc


class _MembershipRecord implements MembershipRecord {
  const _MembershipRecord({required this.id, required this.organizationId, required this.userId, required this.roleKey, required this.status, this.venueId, this.displayName, this.email});
  

@override final  String id;
@override final  String organizationId;
@override final  String userId;
@override final  String roleKey;
@override final  String status;
@override final  String? venueId;
@override final  String? displayName;
@override final  String? email;

/// Create a copy of MembershipRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MembershipRecordCopyWith<_MembershipRecord> get copyWith => __$MembershipRecordCopyWithImpl<_MembershipRecord>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MembershipRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.organizationId, organizationId) || other.organizationId == organizationId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.roleKey, roleKey) || other.roleKey == roleKey)&&(identical(other.status, status) || other.status == status)&&(identical(other.venueId, venueId) || other.venueId == venueId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.email, email) || other.email == email));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,organizationId,userId,roleKey,status,venueId,displayName,email);
}

@override
String toString() {
    return 'MembershipRecord(id: $id, organizationId: $organizationId, userId: $userId, roleKey: $roleKey, status: $status, venueId: $venueId, displayName: $displayName, email: $email)';
}


}

/// @nodoc
abstract mixin class _$MembershipRecordCopyWith<$Res> implements $MembershipRecordCopyWith<$Res> {
  factory _$MembershipRecordCopyWith(_MembershipRecord value, $Res Function(_MembershipRecord) _then) = __$MembershipRecordCopyWithImpl;
@override @useResult
$Res call({
 String id, String organizationId, String userId, String roleKey, String status, String? venueId, String? displayName, String? email
});




}
/// @nodoc
class __$MembershipRecordCopyWithImpl<$Res>
    implements _$MembershipRecordCopyWith<$Res> {
  __$MembershipRecordCopyWithImpl(this._self, this._then);

  final _MembershipRecord _self;
  final $Res Function(_MembershipRecord) _then;

/// Create a copy of MembershipRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? organizationId = null,Object? userId = null,Object? roleKey = null,Object? status = null,Object? venueId = freezed,Object? displayName = freezed,Object? email = freezed,}) {
  return _then(_MembershipRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,organizationId: null == organizationId ? _self.organizationId : organizationId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,roleKey: null == roleKey ? _self.roleKey : roleKey // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,venueId: freezed == venueId ? _self.venueId : venueId // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$InviteRecord {

 String get id; String get organizationId; String get email; String get roleKey; DateTime get expiresAt; String? get venueId; DateTime? get acceptedAt; DateTime? get revokedAt;
/// Create a copy of InviteRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InviteRecordCopyWith<InviteRecord> get copyWith => _$InviteRecordCopyWithImpl<InviteRecord>(this as InviteRecord, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as InviteRecord;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InviteRecord&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.organizationId, _this.organizationId) || other.organizationId == _this.organizationId)&&(identical(other.email, _this.email) || other.email == _this.email)&&(identical(other.roleKey, _this.roleKey) || other.roleKey == _this.roleKey)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt)&&(identical(other.venueId, _this.venueId) || other.venueId == _this.venueId)&&(identical(other.acceptedAt, _this.acceptedAt) || other.acceptedAt == _this.acceptedAt)&&(identical(other.revokedAt, _this.revokedAt) || other.revokedAt == _this.revokedAt));
}


@override
int get hashCode {
  final _this = this as InviteRecord;
  return Object.hash(runtimeType,_this.id,_this.organizationId,_this.email,_this.roleKey,_this.expiresAt,_this.venueId,_this.acceptedAt,_this.revokedAt);
}

@override
String toString() {
  final _this = this as InviteRecord;
  return 'InviteRecord(id: ${_this.id}, organizationId: ${_this.organizationId}, email: ${_this.email}, roleKey: ${_this.roleKey}, expiresAt: ${_this.expiresAt}, venueId: ${_this.venueId}, acceptedAt: ${_this.acceptedAt}, revokedAt: ${_this.revokedAt})';
}


}

/// @nodoc
abstract mixin class $InviteRecordCopyWith<$Res>  {
  factory $InviteRecordCopyWith(InviteRecord value, $Res Function(InviteRecord) _then) = _$InviteRecordCopyWithImpl;
@useResult
$Res call({
 String id, String organizationId, String email, String roleKey, DateTime expiresAt, String? venueId, DateTime? acceptedAt, DateTime? revokedAt
});




}
/// @nodoc
class _$InviteRecordCopyWithImpl<$Res>
    implements $InviteRecordCopyWith<$Res> {
  _$InviteRecordCopyWithImpl(this._self, this._then);

  final InviteRecord _self;
  final $Res Function(InviteRecord) _then;

/// Create a copy of InviteRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? organizationId = null,Object? email = null,Object? roleKey = null,Object? expiresAt = null,Object? venueId = freezed,Object? acceptedAt = freezed,Object? revokedAt = freezed,}) {
  return _then(InviteRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,organizationId: null == organizationId ? _self.organizationId : organizationId // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,roleKey: null == roleKey ? _self.roleKey : roleKey // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,venueId: freezed == venueId ? _self.venueId : venueId // ignore: cast_nullable_to_non_nullable
as String?,acceptedAt: freezed == acceptedAt ? _self.acceptedAt : acceptedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,revokedAt: freezed == revokedAt ? _self.revokedAt : revokedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [InviteRecord].
extension InviteRecordPatterns on InviteRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InviteRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InviteRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InviteRecord value)  $default,){
final _that = this;
switch (_that) {
case _InviteRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InviteRecord value)?  $default,){
final _that = this;
switch (_that) {
case _InviteRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String organizationId,  String email,  String roleKey,  DateTime expiresAt,  String? venueId,  DateTime? acceptedAt,  DateTime? revokedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InviteRecord() when $default != null:
return $default(_that.id,_that.organizationId,_that.email,_that.roleKey,_that.expiresAt,_that.venueId,_that.acceptedAt,_that.revokedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String organizationId,  String email,  String roleKey,  DateTime expiresAt,  String? venueId,  DateTime? acceptedAt,  DateTime? revokedAt)  $default,) {final _that = this;
switch (_that) {
case _InviteRecord():
return $default(_that.id,_that.organizationId,_that.email,_that.roleKey,_that.expiresAt,_that.venueId,_that.acceptedAt,_that.revokedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String organizationId,  String email,  String roleKey,  DateTime expiresAt,  String? venueId,  DateTime? acceptedAt,  DateTime? revokedAt)?  $default,) {final _that = this;
switch (_that) {
case _InviteRecord() when $default != null:
return $default(_that.id,_that.organizationId,_that.email,_that.roleKey,_that.expiresAt,_that.venueId,_that.acceptedAt,_that.revokedAt);case _:
  return null;

}
}

}

/// @nodoc


class _InviteRecord implements InviteRecord {
  const _InviteRecord({required this.id, required this.organizationId, required this.email, required this.roleKey, required this.expiresAt, this.venueId, this.acceptedAt, this.revokedAt});
  

@override final  String id;
@override final  String organizationId;
@override final  String email;
@override final  String roleKey;
@override final  DateTime expiresAt;
@override final  String? venueId;
@override final  DateTime? acceptedAt;
@override final  DateTime? revokedAt;

/// Create a copy of InviteRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InviteRecordCopyWith<_InviteRecord> get copyWith => __$InviteRecordCopyWithImpl<_InviteRecord>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _InviteRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.organizationId, organizationId) || other.organizationId == organizationId)&&(identical(other.email, email) || other.email == email)&&(identical(other.roleKey, roleKey) || other.roleKey == roleKey)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.venueId, venueId) || other.venueId == venueId)&&(identical(other.acceptedAt, acceptedAt) || other.acceptedAt == acceptedAt)&&(identical(other.revokedAt, revokedAt) || other.revokedAt == revokedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,organizationId,email,roleKey,expiresAt,venueId,acceptedAt,revokedAt);
}

@override
String toString() {
    return 'InviteRecord(id: $id, organizationId: $organizationId, email: $email, roleKey: $roleKey, expiresAt: $expiresAt, venueId: $venueId, acceptedAt: $acceptedAt, revokedAt: $revokedAt)';
}


}

/// @nodoc
abstract mixin class _$InviteRecordCopyWith<$Res> implements $InviteRecordCopyWith<$Res> {
  factory _$InviteRecordCopyWith(_InviteRecord value, $Res Function(_InviteRecord) _then) = __$InviteRecordCopyWithImpl;
@override @useResult
$Res call({
 String id, String organizationId, String email, String roleKey, DateTime expiresAt, String? venueId, DateTime? acceptedAt, DateTime? revokedAt
});




}
/// @nodoc
class __$InviteRecordCopyWithImpl<$Res>
    implements _$InviteRecordCopyWith<$Res> {
  __$InviteRecordCopyWithImpl(this._self, this._then);

  final _InviteRecord _self;
  final $Res Function(_InviteRecord) _then;

/// Create a copy of InviteRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? organizationId = null,Object? email = null,Object? roleKey = null,Object? expiresAt = null,Object? venueId = freezed,Object? acceptedAt = freezed,Object? revokedAt = freezed,}) {
  return _then(_InviteRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,organizationId: null == organizationId ? _self.organizationId : organizationId // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,roleKey: null == roleKey ? _self.roleKey : roleKey // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,venueId: freezed == venueId ? _self.venueId : venueId // ignore: cast_nullable_to_non_nullable
as String?,acceptedAt: freezed == acceptedAt ? _self.acceptedAt : acceptedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,revokedAt: freezed == revokedAt ? _self.revokedAt : revokedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$JoinRequestRecord {

 String get id; String get organizationId; String get userId; String get requestedRoleKey; String get status; String? get venueId; String? get message; String? get displayName; String? get email;
/// Create a copy of JoinRequestRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JoinRequestRecordCopyWith<JoinRequestRecord> get copyWith => _$JoinRequestRecordCopyWithImpl<JoinRequestRecord>(this as JoinRequestRecord, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as JoinRequestRecord;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JoinRequestRecord&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.organizationId, _this.organizationId) || other.organizationId == _this.organizationId)&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.requestedRoleKey, _this.requestedRoleKey) || other.requestedRoleKey == _this.requestedRoleKey)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.venueId, _this.venueId) || other.venueId == _this.venueId)&&(identical(other.message, _this.message) || other.message == _this.message)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.email, _this.email) || other.email == _this.email));
}


@override
int get hashCode {
  final _this = this as JoinRequestRecord;
  return Object.hash(runtimeType,_this.id,_this.organizationId,_this.userId,_this.requestedRoleKey,_this.status,_this.venueId,_this.message,_this.displayName,_this.email);
}

@override
String toString() {
  final _this = this as JoinRequestRecord;
  return 'JoinRequestRecord(id: ${_this.id}, organizationId: ${_this.organizationId}, userId: ${_this.userId}, requestedRoleKey: ${_this.requestedRoleKey}, status: ${_this.status}, venueId: ${_this.venueId}, message: ${_this.message}, displayName: ${_this.displayName}, email: ${_this.email})';
}


}

/// @nodoc
abstract mixin class $JoinRequestRecordCopyWith<$Res>  {
  factory $JoinRequestRecordCopyWith(JoinRequestRecord value, $Res Function(JoinRequestRecord) _then) = _$JoinRequestRecordCopyWithImpl;
@useResult
$Res call({
 String id, String organizationId, String userId, String requestedRoleKey, String status, String? venueId, String? message, String? displayName, String? email
});




}
/// @nodoc
class _$JoinRequestRecordCopyWithImpl<$Res>
    implements $JoinRequestRecordCopyWith<$Res> {
  _$JoinRequestRecordCopyWithImpl(this._self, this._then);

  final JoinRequestRecord _self;
  final $Res Function(JoinRequestRecord) _then;

/// Create a copy of JoinRequestRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? organizationId = null,Object? userId = null,Object? requestedRoleKey = null,Object? status = null,Object? venueId = freezed,Object? message = freezed,Object? displayName = freezed,Object? email = freezed,}) {
  return _then(JoinRequestRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,organizationId: null == organizationId ? _self.organizationId : organizationId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,requestedRoleKey: null == requestedRoleKey ? _self.requestedRoleKey : requestedRoleKey // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,venueId: freezed == venueId ? _self.venueId : venueId // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [JoinRequestRecord].
extension JoinRequestRecordPatterns on JoinRequestRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JoinRequestRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JoinRequestRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JoinRequestRecord value)  $default,){
final _that = this;
switch (_that) {
case _JoinRequestRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JoinRequestRecord value)?  $default,){
final _that = this;
switch (_that) {
case _JoinRequestRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String organizationId,  String userId,  String requestedRoleKey,  String status,  String? venueId,  String? message,  String? displayName,  String? email)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JoinRequestRecord() when $default != null:
return $default(_that.id,_that.organizationId,_that.userId,_that.requestedRoleKey,_that.status,_that.venueId,_that.message,_that.displayName,_that.email);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String organizationId,  String userId,  String requestedRoleKey,  String status,  String? venueId,  String? message,  String? displayName,  String? email)  $default,) {final _that = this;
switch (_that) {
case _JoinRequestRecord():
return $default(_that.id,_that.organizationId,_that.userId,_that.requestedRoleKey,_that.status,_that.venueId,_that.message,_that.displayName,_that.email);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String organizationId,  String userId,  String requestedRoleKey,  String status,  String? venueId,  String? message,  String? displayName,  String? email)?  $default,) {final _that = this;
switch (_that) {
case _JoinRequestRecord() when $default != null:
return $default(_that.id,_that.organizationId,_that.userId,_that.requestedRoleKey,_that.status,_that.venueId,_that.message,_that.displayName,_that.email);case _:
  return null;

}
}

}

/// @nodoc


class _JoinRequestRecord implements JoinRequestRecord {
  const _JoinRequestRecord({required this.id, required this.organizationId, required this.userId, required this.requestedRoleKey, required this.status, this.venueId, this.message, this.displayName, this.email});
  

@override final  String id;
@override final  String organizationId;
@override final  String userId;
@override final  String requestedRoleKey;
@override final  String status;
@override final  String? venueId;
@override final  String? message;
@override final  String? displayName;
@override final  String? email;

/// Create a copy of JoinRequestRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JoinRequestRecordCopyWith<_JoinRequestRecord> get copyWith => __$JoinRequestRecordCopyWithImpl<_JoinRequestRecord>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _JoinRequestRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.organizationId, organizationId) || other.organizationId == organizationId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.requestedRoleKey, requestedRoleKey) || other.requestedRoleKey == requestedRoleKey)&&(identical(other.status, status) || other.status == status)&&(identical(other.venueId, venueId) || other.venueId == venueId)&&(identical(other.message, message) || other.message == message)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.email, email) || other.email == email));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,organizationId,userId,requestedRoleKey,status,venueId,message,displayName,email);
}

@override
String toString() {
    return 'JoinRequestRecord(id: $id, organizationId: $organizationId, userId: $userId, requestedRoleKey: $requestedRoleKey, status: $status, venueId: $venueId, message: $message, displayName: $displayName, email: $email)';
}


}

/// @nodoc
abstract mixin class _$JoinRequestRecordCopyWith<$Res> implements $JoinRequestRecordCopyWith<$Res> {
  factory _$JoinRequestRecordCopyWith(_JoinRequestRecord value, $Res Function(_JoinRequestRecord) _then) = __$JoinRequestRecordCopyWithImpl;
@override @useResult
$Res call({
 String id, String organizationId, String userId, String requestedRoleKey, String status, String? venueId, String? message, String? displayName, String? email
});




}
/// @nodoc
class __$JoinRequestRecordCopyWithImpl<$Res>
    implements _$JoinRequestRecordCopyWith<$Res> {
  __$JoinRequestRecordCopyWithImpl(this._self, this._then);

  final _JoinRequestRecord _self;
  final $Res Function(_JoinRequestRecord) _then;

/// Create a copy of JoinRequestRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? organizationId = null,Object? userId = null,Object? requestedRoleKey = null,Object? status = null,Object? venueId = freezed,Object? message = freezed,Object? displayName = freezed,Object? email = freezed,}) {
  return _then(_JoinRequestRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,organizationId: null == organizationId ? _self.organizationId : organizationId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,requestedRoleKey: null == requestedRoleKey ? _self.requestedRoleKey : requestedRoleKey // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,venueId: freezed == venueId ? _self.venueId : venueId // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$AuditEventRecord {

 String get id; String get action; DateTime get createdAt; String? get entityType;
/// Create a copy of AuditEventRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuditEventRecordCopyWith<AuditEventRecord> get copyWith => _$AuditEventRecordCopyWithImpl<AuditEventRecord>(this as AuditEventRecord, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AuditEventRecord;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuditEventRecord&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.action, _this.action) || other.action == _this.action)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.entityType, _this.entityType) || other.entityType == _this.entityType));
}


@override
int get hashCode {
  final _this = this as AuditEventRecord;
  return Object.hash(runtimeType,_this.id,_this.action,_this.createdAt,_this.entityType);
}

@override
String toString() {
  final _this = this as AuditEventRecord;
  return 'AuditEventRecord(id: ${_this.id}, action: ${_this.action}, createdAt: ${_this.createdAt}, entityType: ${_this.entityType})';
}


}

/// @nodoc
abstract mixin class $AuditEventRecordCopyWith<$Res>  {
  factory $AuditEventRecordCopyWith(AuditEventRecord value, $Res Function(AuditEventRecord) _then) = _$AuditEventRecordCopyWithImpl;
@useResult
$Res call({
 String id, String action, DateTime createdAt, String? entityType
});




}
/// @nodoc
class _$AuditEventRecordCopyWithImpl<$Res>
    implements $AuditEventRecordCopyWith<$Res> {
  _$AuditEventRecordCopyWithImpl(this._self, this._then);

  final AuditEventRecord _self;
  final $Res Function(AuditEventRecord) _then;

/// Create a copy of AuditEventRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? action = null,Object? createdAt = null,Object? entityType = freezed,}) {
  return _then(AuditEventRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,entityType: freezed == entityType ? _self.entityType : entityType // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AuditEventRecord].
extension AuditEventRecordPatterns on AuditEventRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AuditEventRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AuditEventRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AuditEventRecord value)  $default,){
final _that = this;
switch (_that) {
case _AuditEventRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AuditEventRecord value)?  $default,){
final _that = this;
switch (_that) {
case _AuditEventRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String action,  DateTime createdAt,  String? entityType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AuditEventRecord() when $default != null:
return $default(_that.id,_that.action,_that.createdAt,_that.entityType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String action,  DateTime createdAt,  String? entityType)  $default,) {final _that = this;
switch (_that) {
case _AuditEventRecord():
return $default(_that.id,_that.action,_that.createdAt,_that.entityType);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String action,  DateTime createdAt,  String? entityType)?  $default,) {final _that = this;
switch (_that) {
case _AuditEventRecord() when $default != null:
return $default(_that.id,_that.action,_that.createdAt,_that.entityType);case _:
  return null;

}
}

}

/// @nodoc


class _AuditEventRecord implements AuditEventRecord {
  const _AuditEventRecord({required this.id, required this.action, required this.createdAt, this.entityType});
  

@override final  String id;
@override final  String action;
@override final  DateTime createdAt;
@override final  String? entityType;

/// Create a copy of AuditEventRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuditEventRecordCopyWith<_AuditEventRecord> get copyWith => __$AuditEventRecordCopyWithImpl<_AuditEventRecord>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuditEventRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.action, action) || other.action == action)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.entityType, entityType) || other.entityType == entityType));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,action,createdAt,entityType);
}

@override
String toString() {
    return 'AuditEventRecord(id: $id, action: $action, createdAt: $createdAt, entityType: $entityType)';
}


}

/// @nodoc
abstract mixin class _$AuditEventRecordCopyWith<$Res> implements $AuditEventRecordCopyWith<$Res> {
  factory _$AuditEventRecordCopyWith(_AuditEventRecord value, $Res Function(_AuditEventRecord) _then) = __$AuditEventRecordCopyWithImpl;
@override @useResult
$Res call({
 String id, String action, DateTime createdAt, String? entityType
});




}
/// @nodoc
class __$AuditEventRecordCopyWithImpl<$Res>
    implements _$AuditEventRecordCopyWith<$Res> {
  __$AuditEventRecordCopyWithImpl(this._self, this._then);

  final _AuditEventRecord _self;
  final $Res Function(_AuditEventRecord) _then;

/// Create a copy of AuditEventRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? action = null,Object? createdAt = null,Object? entityType = freezed,}) {
  return _then(_AuditEventRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,entityType: freezed == entityType ? _self.entityType : entityType // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$VenueLookup {

 String get venueId; String get venueName; String get organizationName; String get serviceStyle;
/// Create a copy of VenueLookup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VenueLookupCopyWith<VenueLookup> get copyWith => _$VenueLookupCopyWithImpl<VenueLookup>(this as VenueLookup, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as VenueLookup;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VenueLookup&&(identical(other.venueId, _this.venueId) || other.venueId == _this.venueId)&&(identical(other.venueName, _this.venueName) || other.venueName == _this.venueName)&&(identical(other.organizationName, _this.organizationName) || other.organizationName == _this.organizationName)&&(identical(other.serviceStyle, _this.serviceStyle) || other.serviceStyle == _this.serviceStyle));
}


@override
int get hashCode {
  final _this = this as VenueLookup;
  return Object.hash(runtimeType,_this.venueId,_this.venueName,_this.organizationName,_this.serviceStyle);
}

@override
String toString() {
  final _this = this as VenueLookup;
  return 'VenueLookup(venueId: ${_this.venueId}, venueName: ${_this.venueName}, organizationName: ${_this.organizationName}, serviceStyle: ${_this.serviceStyle})';
}


}

/// @nodoc
abstract mixin class $VenueLookupCopyWith<$Res>  {
  factory $VenueLookupCopyWith(VenueLookup value, $Res Function(VenueLookup) _then) = _$VenueLookupCopyWithImpl;
@useResult
$Res call({
 String venueId, String venueName, String organizationName, String serviceStyle
});




}
/// @nodoc
class _$VenueLookupCopyWithImpl<$Res>
    implements $VenueLookupCopyWith<$Res> {
  _$VenueLookupCopyWithImpl(this._self, this._then);

  final VenueLookup _self;
  final $Res Function(VenueLookup) _then;

/// Create a copy of VenueLookup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? venueId = null,Object? venueName = null,Object? organizationName = null,Object? serviceStyle = null,}) {
  return _then(VenueLookup(
venueId: null == venueId ? _self.venueId : venueId // ignore: cast_nullable_to_non_nullable
as String,venueName: null == venueName ? _self.venueName : venueName // ignore: cast_nullable_to_non_nullable
as String,organizationName: null == organizationName ? _self.organizationName : organizationName // ignore: cast_nullable_to_non_nullable
as String,serviceStyle: null == serviceStyle ? _self.serviceStyle : serviceStyle // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [VenueLookup].
extension VenueLookupPatterns on VenueLookup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VenueLookup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VenueLookup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VenueLookup value)  $default,){
final _that = this;
switch (_that) {
case _VenueLookup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VenueLookup value)?  $default,){
final _that = this;
switch (_that) {
case _VenueLookup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String venueId,  String venueName,  String organizationName,  String serviceStyle)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VenueLookup() when $default != null:
return $default(_that.venueId,_that.venueName,_that.organizationName,_that.serviceStyle);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String venueId,  String venueName,  String organizationName,  String serviceStyle)  $default,) {final _that = this;
switch (_that) {
case _VenueLookup():
return $default(_that.venueId,_that.venueName,_that.organizationName,_that.serviceStyle);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String venueId,  String venueName,  String organizationName,  String serviceStyle)?  $default,) {final _that = this;
switch (_that) {
case _VenueLookup() when $default != null:
return $default(_that.venueId,_that.venueName,_that.organizationName,_that.serviceStyle);case _:
  return null;

}
}

}

/// @nodoc


class _VenueLookup implements VenueLookup {
  const _VenueLookup({required this.venueId, required this.venueName, required this.organizationName, required this.serviceStyle});
  

@override final  String venueId;
@override final  String venueName;
@override final  String organizationName;
@override final  String serviceStyle;

/// Create a copy of VenueLookup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VenueLookupCopyWith<_VenueLookup> get copyWith => __$VenueLookupCopyWithImpl<_VenueLookup>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VenueLookup&&(identical(other.venueId, venueId) || other.venueId == venueId)&&(identical(other.venueName, venueName) || other.venueName == venueName)&&(identical(other.organizationName, organizationName) || other.organizationName == organizationName)&&(identical(other.serviceStyle, serviceStyle) || other.serviceStyle == serviceStyle));
}


@override
int get hashCode {
    return Object.hash(runtimeType,venueId,venueName,organizationName,serviceStyle);
}

@override
String toString() {
    return 'VenueLookup(venueId: $venueId, venueName: $venueName, organizationName: $organizationName, serviceStyle: $serviceStyle)';
}


}

/// @nodoc
abstract mixin class _$VenueLookupCopyWith<$Res> implements $VenueLookupCopyWith<$Res> {
  factory _$VenueLookupCopyWith(_VenueLookup value, $Res Function(_VenueLookup) _then) = __$VenueLookupCopyWithImpl;
@override @useResult
$Res call({
 String venueId, String venueName, String organizationName, String serviceStyle
});




}
/// @nodoc
class __$VenueLookupCopyWithImpl<$Res>
    implements _$VenueLookupCopyWith<$Res> {
  __$VenueLookupCopyWithImpl(this._self, this._then);

  final _VenueLookup _self;
  final $Res Function(_VenueLookup) _then;

/// Create a copy of VenueLookup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? venueId = null,Object? venueName = null,Object? organizationName = null,Object? serviceStyle = null,}) {
  return _then(_VenueLookup(
venueId: null == venueId ? _self.venueId : venueId // ignore: cast_nullable_to_non_nullable
as String,venueName: null == venueName ? _self.venueName : venueName // ignore: cast_nullable_to_non_nullable
as String,organizationName: null == organizationName ? _self.organizationName : organizationName // ignore: cast_nullable_to_non_nullable
as String,serviceStyle: null == serviceStyle ? _self.serviceStyle : serviceStyle // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$InviteIssue {

 String get id; bool get created;
/// Create a copy of InviteIssue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InviteIssueCopyWith<InviteIssue> get copyWith => _$InviteIssueCopyWithImpl<InviteIssue>(this as InviteIssue, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as InviteIssue;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InviteIssue&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.created, _this.created) || other.created == _this.created));
}


@override
int get hashCode {
  final _this = this as InviteIssue;
  return Object.hash(runtimeType,_this.id,_this.created);
}

@override
String toString() {
  final _this = this as InviteIssue;
  return 'InviteIssue(id: ${_this.id}, created: ${_this.created})';
}


}

/// @nodoc
abstract mixin class $InviteIssueCopyWith<$Res>  {
  factory $InviteIssueCopyWith(InviteIssue value, $Res Function(InviteIssue) _then) = _$InviteIssueCopyWithImpl;
@useResult
$Res call({
 String id, bool created
});




}
/// @nodoc
class _$InviteIssueCopyWithImpl<$Res>
    implements $InviteIssueCopyWith<$Res> {
  _$InviteIssueCopyWithImpl(this._self, this._then);

  final InviteIssue _self;
  final $Res Function(InviteIssue) _then;

/// Create a copy of InviteIssue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? created = null,}) {
  return _then(InviteIssue(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [InviteIssue].
extension InviteIssuePatterns on InviteIssue {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InviteIssue value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InviteIssue() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InviteIssue value)  $default,){
final _that = this;
switch (_that) {
case _InviteIssue():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InviteIssue value)?  $default,){
final _that = this;
switch (_that) {
case _InviteIssue() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  bool created)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InviteIssue() when $default != null:
return $default(_that.id,_that.created);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  bool created)  $default,) {final _that = this;
switch (_that) {
case _InviteIssue():
return $default(_that.id,_that.created);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  bool created)?  $default,) {final _that = this;
switch (_that) {
case _InviteIssue() when $default != null:
return $default(_that.id,_that.created);case _:
  return null;

}
}

}

/// @nodoc


class _InviteIssue implements InviteIssue {
  const _InviteIssue({required this.id, required this.created});
  

@override final  String id;
@override final  bool created;

/// Create a copy of InviteIssue
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InviteIssueCopyWith<_InviteIssue> get copyWith => __$InviteIssueCopyWithImpl<_InviteIssue>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _InviteIssue&&(identical(other.id, id) || other.id == id)&&(identical(other.created, created) || other.created == created));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,created);
}

@override
String toString() {
    return 'InviteIssue(id: $id, created: $created)';
}


}

/// @nodoc
abstract mixin class _$InviteIssueCopyWith<$Res> implements $InviteIssueCopyWith<$Res> {
  factory _$InviteIssueCopyWith(_InviteIssue value, $Res Function(_InviteIssue) _then) = __$InviteIssueCopyWithImpl;
@override @useResult
$Res call({
 String id, bool created
});




}
/// @nodoc
class __$InviteIssueCopyWithImpl<$Res>
    implements _$InviteIssueCopyWith<$Res> {
  __$InviteIssueCopyWithImpl(this._self, this._then);

  final _InviteIssue _self;
  final $Res Function(_InviteIssue) _then;

/// Create a copy of InviteIssue
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? created = null,}) {
  return _then(_InviteIssue(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
