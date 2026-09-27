import 'package:venue_wrangler/core/permissions/app_role.dart';
import 'package:venue_wrangler/core/permissions/permission.dart';
import 'package:venue_wrangler/core/permissions/role_catalog.dart';

void main() {
  stdoutRoles();
  stdoutPermissions();
  stdoutGrants();
}

void stdoutRoles() {
  print('-- app_roles');
  print('insert into public.app_roles (key, label, rank) values');
  final rows = AppRole.values
      .map((role) => "  ('${role.key}', '${role.label}', ${role.rank})")
      .join(',\n');
  print('$rows\non conflict (key) do update set label = excluded.label, rank = excluded.rank;');
}

void stdoutPermissions() {
  print('-- permissions');
  print('insert into public.permissions (key, description) values');
  final rows = Permission.all
      .map((key) => "  ('$key', '${Permission.descriptions[key]}')")
      .join(',\n');
  print(
    '$rows\non conflict (key) do update set description = excluded.description;',
  );
}

void stdoutGrants() {
  print('-- role_permissions');
  print('insert into public.role_permissions (role_key, permission_key) values');
  final rows = <String>[];
  for (final role in AppRole.values) {
    final permissions = RoleCatalog.permissionsFor(role).toList()..sort();
    for (final permission in permissions) {
      rows.add("  ('${role.key}', '$permission')");
    }
  }
  print('${rows.join(',\n')}\non conflict do nothing;');
}
