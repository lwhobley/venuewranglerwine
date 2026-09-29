import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure_mapper.dart';
import '../domain/tenant_models.dart';
import '../domain/tenant_repository.dart';
import '../domain/tenant_session.dart';

class SupabaseTenantRepository implements TenantRepository {
  SupabaseTenantRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<TenantSession> loadSession(String userId) {
    return _guard(() async {
      final isPlatformAdmin = await _client.rpc('is_platform_admin') == true;
      final List<String> orgIds;
      if (isPlatformAdmin) {
        final rows = await _client.from('organizations').select('id');
        orgIds = _list(rows).map((row) => row['id'] as String).toList();
      } else {
        final ownRows = await _client
            .from('memberships')
            .select('organization_id')
            .eq('user_id', userId)
            .eq('status', 'active');
        orgIds = _list(ownRows)
            .map((row) => row['organization_id'] as String)
            .toSet()
            .toList();
      }
      if (orgIds.isEmpty) {
        return isPlatformAdmin
            ? TenantSession(
                userId: userId,
                memberships: const [],
                organizations: const [],
                venues: const [],
                invites: const [],
                joinRequests: const [],
                auditEvents: const [],
                isPlatformAdmin: true,
              )
            : TenantSession.empty();
      }

      final membershipRows = await _client
          .from('memberships')
          .select(
            'id, organization_id, user_id, venue_id, role_key, status, profiles!memberships_user_id_fkey(display_name, email)',
          )
          .inFilter('organization_id', orgIds)
          .eq('status', 'active');
      final organizationRows = await _client
          .from('organizations')
          .select('id, name, slug, legal_name')
          .inFilter('id', orgIds);
      final venueRows = await _client
          .from('venues')
          .select(
            'id, organization_id, name, slug, timezone, currency_code, service_style, status, city',
          )
          .inFilter('organization_id', orgIds);
      final inviteRows = await _client
          .from('invites')
          .select(
            'id, organization_id, venue_id, email, role_key, expires_at, accepted_at, revoked_at',
          )
          .inFilter('organization_id', orgIds)
          .isFilter('accepted_at', null)
          .isFilter('revoked_at', null);
      final joinRows = await _client
          .from('join_requests')
          .select(
            'id, organization_id, venue_id, user_id, requested_role_key, status, message, profiles!join_requests_user_id_fkey(display_name, email)',
          )
          .inFilter('organization_id', orgIds)
          .eq('status', 'pending');
      List<dynamic> auditRows = const [];
      try {
        auditRows = await _client
            .from('audit_events')
            .select('id, action, entity_type, created_at')
            .inFilter('organization_id', orgIds)
            .order('created_at', ascending: false)
            .limit(12);
      } catch (_) {
        auditRows = const [];
      }

      return TenantSession(
        userId: userId,
        memberships: _list(membershipRows).map(_membership).toList(),
        organizations: _list(organizationRows)
            .map(Organization.fromJson)
            .toList(),
        venues: _list(venueRows).map(Venue.fromJson).toList(),
        invites: _list(inviteRows).map(_invite).toList(),
        joinRequests: _list(joinRows).map(_join).toList(),
        auditEvents: auditRows
            .map((row) => _audit(Map<String, dynamic>.from(row as Map)))
            .toList(),
        isPlatformAdmin: isPlatformAdmin,
      );
    });
  }

  @override
  Future<String> createOrganization({
    required String name,
    required String slug,
    String? legalName,
  }) {
    return _guard(() async {
      final id = await _client.rpc(
        'create_organization',
        params: {'p_name': name, 'p_slug': slug, 'p_legal_name': legalName},
      );
      return id.toString();
    });
  }

  @override
  Future<String> createVenue(CreateVenueRequest request) {
    return _guard(() async {
      final id = await _client.rpc(
        'create_venue_geofenced',
        params: {
          'p_organization_id': request.organizationId,
          'p_name': request.name,
          'p_slug': request.slug,
          'p_timezone': request.timezone,
          'p_currency_code': request.currencyCode,
          'p_country_code': request.countryCode,
          'p_address_line1': request.addressLine1,
          'p_city': request.city,
          'p_region': request.region,
          'p_postal_code': request.postalCode,
          'p_service_style': request.serviceStyle,
          'p_latitude': request.geofenceLatitude,
          'p_longitude': request.geofenceLongitude,
          'p_radius_ft': request.geofenceRadiusFt,
        },
      );
      return id.toString();
    });
  }

  @override
  Future<InviteIssue> createInvite({
    required String organizationId,
    required String? venueId,
    required String email,
    required String roleKey,
    required String token,
  }) {
    return _guard(() async {
      final raw = await _client.rpc(
        'create_invite',
        params: {
          'p_organization_id': organizationId,
          'p_venue_id': venueId,
          'p_email': email,
          'p_role_key': roleKey,
          'p_token': token,
        },
      );
      final map = Map<String, dynamic>.from(raw as Map);
      return InviteIssue(
        id: map['id'].toString(),
        created: map['created'] == true,
      );
    });
  }

  @override
  Future<void> revokeInvite(String inviteId) {
    return _guard(
      () => _client.rpc('revoke_invite', params: {'p_invite_id': inviteId}),
    );
  }

  @override
  Future<void> acceptInvite(String token) {
    return _guard(
      () => _client.rpc('accept_invite', params: {'p_token': token}),
    );
  }

  @override
  Future<VenueLookup?> lookupVenue(String code) {
    return _guard(() async {
      final raw = await _client.rpc(
        'lookup_venue_by_code',
        params: {'p_code': code},
      );
      final rows = _list(raw);
      if (rows.isEmpty) return null;
      final row = rows.first;
      return VenueLookup(
        venueId: row['venue_id'].toString(),
        venueName: row['venue_name'] as String,
        organizationName: row['organization_name'] as String,
        serviceStyle: row['service_style'] as String,
      );
    });
  }

  @override
  Future<void> requestJoin({
    required String code,
    required String roleKey,
    String? message,
  }) {
    return _guard(
      () => _client.rpc(
        'request_join',
        params: {'p_code': code, 'p_role_key': roleKey, 'p_message': message},
      ),
    );
  }

  @override
  Future<void> reviewJoin({required String requestId, required bool approve}) {
    return _guard(
      () => _client.rpc(
        'review_join_request',
        params: {
          'p_request_id': requestId,
          'p_decision': approve ? 'approved' : 'declined',
        },
      ),
    );
  }

  @override
  Future<void> assignRole({
    required String membershipId,
    required String roleKey,
  }) {
    return _guard(
      () => _client.rpc(
        'assign_membership_role',
        params: {'p_membership_id': membershipId, 'p_role_key': roleKey},
      ),
    );
  }

  @override
  Future<String?> venueJoinCode(String venueId) {
    return _guard(() async {
      final code = await _client.rpc(
        'venue_join_code',
        params: {'p_venue_id': venueId},
      );
      return code as String?;
    });
  }

  @override
  Future<void> updateDisplayName({
    required String userId,
    required String name,
  }) {
    return _guard(
      () => _client
          .from('profiles')
          .update({'display_name': name})
          .eq('id', userId),
    );
  }

  List<Map<String, dynamic>> _list(dynamic raw) {
    return (raw as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  MembershipRecord _membership(Map<String, dynamic> row) {
    final profile = row['profiles'] == null
        ? null
        : Map<String, dynamic>.from(row['profiles'] as Map);
    return MembershipRecord(
      id: row['id'] as String,
      organizationId: row['organization_id'] as String,
      userId: row['user_id'] as String,
      venueId: row['venue_id'] as String?,
      roleKey: row['role_key'] as String,
      status: row['status'] as String,
      displayName: profile?['display_name'] as String?,
      email: profile?['email'] as String?,
    );
  }

  InviteRecord _invite(Map<String, dynamic> row) {
    return InviteRecord(
      id: row['id'] as String,
      organizationId: row['organization_id'] as String,
      venueId: row['venue_id'] as String?,
      email: row['email'] as String,
      roleKey: row['role_key'] as String,
      expiresAt: DateTime.parse(row['expires_at'] as String).toUtc(),
      acceptedAt: _date(row['accepted_at']),
      revokedAt: _date(row['revoked_at']),
    );
  }

  JoinRequestRecord _join(Map<String, dynamic> row) {
    final profile = row['profiles'] == null
        ? null
        : Map<String, dynamic>.from(row['profiles'] as Map);
    return JoinRequestRecord(
      id: row['id'] as String,
      organizationId: row['organization_id'] as String,
      venueId: row['venue_id'] as String?,
      userId: row['user_id'] as String,
      requestedRoleKey: row['requested_role_key'] as String,
      status: row['status'] as String,
      message: row['message'] as String?,
      displayName: profile?['display_name'] as String?,
      email: profile?['email'] as String?,
    );
  }

  AuditEventRecord _audit(Map<String, dynamic> row) {
    return AuditEventRecord(
      id: row['id'] as String,
      action: row['action'] as String,
      entityType: row['entity_type'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
    );
  }

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.parse(value as String).toUtc();
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw mapFailure(error);
    }
  }
}
