import 'app_role.dart';
import 'role_catalog.dart';

enum PermissionEffect { allow, deny }

class CapabilityChecker {
  const CapabilityChecker();

  bool can({
    required AppRole role,
    required String permission,
    Map<String, PermissionEffect> overrides = const {},
  }) {
    final override = overrides[permission];
    if (override == PermissionEffect.deny) return false;
    if (override == PermissionEffect.allow) return true;
    return RoleCatalog.roleHas(role, permission);
  }

  bool canAssign({required AppRole actor, required AppRole target}) {
    return target.rank >= actor.rank;
  }

  AppRole? strongest(Iterable<AppRole> roles) {
    AppRole? best;
    for (final role in roles) {
      if (best == null || role.rank < best.rank) best = role;
    }
    return best;
  }
}
