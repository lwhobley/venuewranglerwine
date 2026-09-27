import 'tenant_models.dart';
import 'tenant_session.dart';

class CreateVenueRequest {
  const CreateVenueRequest({
    required this.organizationId,
    required this.name,
    required this.slug,
    required this.timezone,
    required this.currencyCode,
    required this.serviceStyle,
    this.countryCode = 'US',
    this.addressLine1,
    this.city,
    this.region,
    this.postalCode,
  });

  final String organizationId;
  final String name;
  final String slug;
  final String timezone;
  final String currencyCode;
  final String serviceStyle;
  final String countryCode;
  final String? addressLine1;
  final String? city;
  final String? region;
  final String? postalCode;
}

abstract interface class TenantRepository {
  Future<TenantSession> loadSession(String userId);
  Future<String> createOrganization({
    required String name,
    required String slug,
    String? legalName,
  });
  Future<String> createVenue(CreateVenueRequest request);
  Future<InviteIssue> createInvite({
    required String organizationId,
    required String? venueId,
    required String email,
    required String roleKey,
    required String token,
  });
  Future<void> revokeInvite(String inviteId);
  Future<void> acceptInvite(String token);
  Future<VenueLookup?> lookupVenue(String code);
  Future<void> requestJoin({
    required String code,
    required String roleKey,
    String? message,
  });
  Future<void> reviewJoin({required String requestId, required bool approve});
  Future<void> assignRole({required String membershipId, required String roleKey});
  Future<String?> venueJoinCode(String venueId);
  Future<void> updateDisplayName({required String userId, required String name});
}
