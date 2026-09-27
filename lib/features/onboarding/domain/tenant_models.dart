import 'package:freezed_annotation/freezed_annotation.dart';

part 'tenant_models.freezed.dart';
part 'tenant_models.g.dart';

@freezed
abstract class Organization with _$Organization {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Organization({
    required String id,
    required String name,
    required String slug,
    String? legalName,
  }) = _Organization;

  factory Organization.fromJson(Map<String, dynamic> json) =>
      _$OrganizationFromJson(json);
}

@freezed
abstract class Venue with _$Venue {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Venue({
    required String id,
    required String organizationId,
    required String name,
    required String slug,
    required String timezone,
    required String currencyCode,
    required String serviceStyle,
    required String status,
    String? city,
  }) = _Venue;

  factory Venue.fromJson(Map<String, dynamic> json) => _$VenueFromJson(json);
}

@freezed
abstract class MembershipRecord with _$MembershipRecord {
  const factory MembershipRecord({
    required String id,
    required String organizationId,
    required String userId,
    required String roleKey,
    required String status,
    String? venueId,
    String? displayName,
    String? email,
  }) = _MembershipRecord;
}

@freezed
abstract class InviteRecord with _$InviteRecord {
  const factory InviteRecord({
    required String id,
    required String organizationId,
    required String email,
    required String roleKey,
    required DateTime expiresAt,
    String? venueId,
    DateTime? acceptedAt,
    DateTime? revokedAt,
  }) = _InviteRecord;
}

@freezed
abstract class JoinRequestRecord with _$JoinRequestRecord {
  const factory JoinRequestRecord({
    required String id,
    required String organizationId,
    required String userId,
    required String requestedRoleKey,
    required String status,
    String? venueId,
    String? message,
    String? displayName,
    String? email,
  }) = _JoinRequestRecord;
}

@freezed
abstract class AuditEventRecord with _$AuditEventRecord {
  const factory AuditEventRecord({
    required String id,
    required String action,
    required DateTime createdAt,
    String? entityType,
  }) = _AuditEventRecord;
}

@freezed
abstract class VenueLookup with _$VenueLookup {
  const factory VenueLookup({
    required String venueId,
    required String venueName,
    required String organizationName,
    required String serviceStyle,
  }) = _VenueLookup;
}

@freezed
abstract class InviteIssue with _$InviteIssue {
  const factory InviteIssue({
    required String id,
    required bool created,
  }) = _InviteIssue;
}
