import 'dart:io';

import '../lib/core/permissions/app_role.dart';
import '../lib/core/permissions/permission.dart';
import '../lib/core/permissions/role_catalog.dart';

void main() {
  final sql = StringBuffer(
    '-- Workforce permissions generated from RoleCatalog.\n',
  );
  sql.writeln('insert into public.app_roles(key,label,rank) values');
  sql.writeln(
    AppRole.values
        .map((r) => "('${r.key}', '${r.label}', ${r.rank})")
        .join(',\n'),
  );
  sql.writeln(
    'on conflict(key) do update set label=excluded.label, rank=excluded.rank;',
  );
  sql.writeln('insert into public.permissions(key,description) values');
  sql.writeln(
    Permission.all
        .map(
          (p) =>
              "('$p', '${Permission.descriptions[p]!.replaceAll("'", "''")}')",
        )
        .join(',\n'),
  );
  sql.writeln(
    'on conflict(key) do update set description=excluded.description;',
  );
  sql.writeln('-- role_permissions');
  sql.writeln(
    'insert into public.role_permissions(role_key,permission_key) values',
  );
  sql.writeln(
    AppRole.values
        .expand(
          (r) => RoleCatalog.permissionsFor(r).map((p) => "('${r.key}', '$p')"),
        )
        .join(',\n'),
  );
  sql.writeln('on conflict do nothing;');
  File('supabase/workforce-role-catalog.sql')
      .writeAsStringSync(sql.toString());
}
