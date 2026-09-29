import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../floor_plan/presentation/floor_host_page.dart';
import '../../onboarding/application/tenant_controller.dart';
import '../../onboarding/application/workspace_controller.dart';

class HostPage extends ConsumerWidget {
  const HostPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceControllerProvider);
    final org = workspace.organizationId, venue = workspace.venueId;
    if (org == null || venue == null) {
      return const Center(child: Text('Create a venue first.'));
    }
    final zone =
        ref
            .watch(tenantControllerProvider)
            .value
            ?.venues
            .where((v) => v.id == venue)
            .firstOrNull
            ?.timezone ??
        'UTC';
    return FloorHostPage(
      key: ValueKey('$org/$venue'),
      organization: org,
      venue: venue,
      zone: zone,
    );
  }
}
