import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:venue_wrangler/core/permissions/app_role.dart';
import 'package:venue_wrangler/core/permissions/permission.dart';
import 'package:venue_wrangler/core/permissions/role_catalog.dart';

void main() {
  final migration = File(
    'supabase/migrations/20260927000000_phase1_tenant_auth.sql',
  ).readAsStringSync();
  final workforceCatalog = File(
    'supabase/migrations/20260928094804_workforce_management.sql',
  ).readAsStringSync();

  test('every tenant table enables row level security', () {
    const tables = [
      'profiles',
      'organizations',
      'venues',
      'app_roles',
      'permissions',
      'role_permissions',
      'memberships',
      'membership_permission_overrides',
      'invites',
      'join_requests',
      'platform_admins',
      'audit_events',
    ];
    for (final table in tables) {
      expect(
        migration.contains(
          'alter table public.$table enable row level security',
        ),
        isTrue,
        reason: table,
      );
    }
  });

  test('privileged mutations are functions, not client inserts', () {
    for (final name in [
      'create_organization',
      'create_venue',
      'create_invite',
      'accept_invite',
      'review_join_request',
      'assign_membership_role',
    ]) {
      expect(migration.contains('function public.$name'), isTrue, reason: name);
      expect(migration.contains('security definer'), isTrue);
    }
    expect(migration.contains('raise exception \'audit_immutable\''), isTrue);
    expect(migration.contains('grant insert on public.organizations'), isFalse);
  });

  test('role catalog matches the client capability matrix', () {
    final grants = RegExp(r"\('([a-z_]+)', '([a-z0-9_.]+)'\)")
        .allMatches(workforceCatalog.split('-- role_permissions').last);
    final actual = grants
        .map((match) => '${match.group(1)}|${match.group(2)}')
        .toSet();
    final expected = <String>{};
    for (final role in AppRole.values) {
      for (final permission in RoleCatalog.permissionsFor(role)) {
        expected.add('${role.key}|$permission');
      }
    }
    expect(actual, expected);
    for (final permission in Permission.all) {
      expect(
        workforceCatalog.contains("'$permission'"),
        isTrue,
        reason: permission,
      );
    }
  });
}
