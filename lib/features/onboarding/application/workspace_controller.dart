import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/tenant_session.dart';
import 'tenant_controller.dart';

class WorkspaceSelection {
  const WorkspaceSelection({this.organizationId, this.venueId});

  final String? organizationId;
  final String? venueId;
}

final workspaceControllerProvider =
    NotifierProvider<WorkspaceController, WorkspaceSelection>(WorkspaceController.new);

class WorkspaceController extends Notifier<WorkspaceSelection> {
  String? _organizationId;
  String? _venueId;

  @override
  WorkspaceSelection build() {
    final session = ref.watch(tenantControllerProvider).value;
    return _resolve(session);
  }

  void selectOrganization(String organizationId) {
    _organizationId = organizationId;
    _venueId = null;
    state = _resolve(ref.read(tenantControllerProvider).value);
  }

  void selectVenue(String venueId) {
    _venueId = venueId;
    state = _resolve(ref.read(tenantControllerProvider).value);
  }

  WorkspaceSelection _resolve(TenantSession? session) {
    if (session == null || !session.hasMembership) {
      return const WorkspaceSelection();
    }
    final orgIds = session.ownMemberships.map((item) => item.organizationId).toSet();
    final organizationId = orgIds.contains(_organizationId)
        ? _organizationId
        : session.ownMemberships.first.organizationId;
    final venues = session.venuesFor(organizationId);
    final venueId = venues.any((venue) => venue.id == _venueId)
        ? _venueId
        : (venues.isEmpty ? null : venues.first.id);
    _organizationId = organizationId;
    _venueId = venueId;
    return WorkspaceSelection(organizationId: organizationId, venueId: venueId);
  }
}
