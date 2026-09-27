import '../../../core/permissions/app_role.dart';
import '../../../core/permissions/capability_checker.dart';
import '../../../core/permissions/permission.dart';
import 'tenant_models.dart';

class TenantSession {
  const TenantSession({
    required this.userId,
    required this.memberships,
    required this.organizations,
    required this.venues,
    required this.invites,
    required this.joinRequests,
    required this.auditEvents,
  });

  final String? userId;
  final List<MembershipRecord> memberships;
  final List<Organization> organizations;
  final List<Venue> venues;
  final List<InviteRecord> invites;
  final List<JoinRequestRecord> joinRequests;
  final List<AuditEventRecord> auditEvents;

  factory TenantSession.empty() {
    return const TenantSession(
      userId: null,
      memberships: [],
      organizations: [],
      venues: [],
      invites: [],
      joinRequests: [],
      auditEvents: [],
    );
  }

  List<MembershipRecord> get ownMemberships {
    return memberships.where((membership) => membership.userId == userId).toList();
  }

  bool get hasMembership => ownMemberships.isNotEmpty;

  bool get hasVenue => venues.isNotEmpty;

  bool can(String organizationId, String permission) {
    const checker = CapabilityChecker();
    for (final membership in ownMemberships) {
      if (membership.organizationId != organizationId) continue;
      final role = AppRole.byKey(membership.roleKey);
      if (role != null && checker.can(role: role, permission: permission)) {
        return true;
      }
    }
    return false;
  }

  bool get canCreateVenue {
    return ownMemberships.any((membership) {
      final role = AppRole.byKey(membership.roleKey);
      return role != null &&
          const CapabilityChecker().can(role: role, permission: Permission.venueCreate);
    });
  }

  Organization? organization(String? id) {
    for (final organization in organizations) {
      if (organization.id == id) return organization;
    }
    return null;
  }

  List<Venue> venuesFor(String? organizationId) {
    return venues.where((venue) => venue.organizationId == organizationId).toList();
  }

  List<MembershipRecord> membersFor(String? organizationId) {
    return memberships.where((membership) => membership.organizationId == organizationId).toList();
  }
}
