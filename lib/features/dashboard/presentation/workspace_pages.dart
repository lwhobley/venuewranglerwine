import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/offline/mutation_queue.dart';
import '../../../core/permissions/app_role.dart';
import '../../../core/permissions/capability_checker.dart';
import '../../../core/permissions/permission.dart';
import '../../../core/time/venue_clock.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../core/widgets/hospitality_design.dart';
import '../../onboarding/application/tenant_controller.dart';
import '../../onboarding/application/workspace_controller.dart';
import '../../onboarding/domain/validators.dart';
import '../../data_import/domain/import_schema.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final location = GoRouterState.of(context).uri.path;
    final session = ref.watch(tenantControllerProvider).value;
    final organizationId = ref
        .watch(workspaceControllerProvider)
        .organizationId;
    final showCellar =
        organizationId != null &&
        (session?.can(organizationId, Permission.wineCatalogRead) ?? false);
    final showHost =
        organizationId != null &&
        ((session?.can(organizationId, Permission.reservationRead) ?? false) ||
            (session?.can(organizationId, Permission.floorRead) ?? false));
    final showPeople =
        organizationId != null &&
        ((session?.can(organizationId, Permission.scheduleRead) ?? false) ||
            (session?.can(organizationId, Permission.timeclockSelf) ?? false));
    final showBusiness =
        organizationId != null &&
        ((session?.can(organizationId, Permission.eventRead) ?? false) ||
            (session?.can(organizationId, Permission.reportOperational) ??
                false));
    final destinations = [
      (path: '/app/home', label: 'Tonight', icon: Icons.home_outlined),
      if (showHost)
        (path: '/app/host', label: 'Host', icon: Icons.event_seat_outlined),
      if (showCellar)
        (path: '/app/cellar', label: 'Cellar', icon: Icons.grid_on_outlined),
      if (showPeople)
        (path: '/app/people', label: 'People', icon: Icons.badge_outlined),
      if (showBusiness)
        (
          path: '/app/business',
          label: 'Business',
          icon: Icons.account_balance_outlined,
        ),
      (path: '/app/team', label: 'Team', icon: Icons.groups_outlined),
      (path: '/app/profile', label: 'Profile', icon: Icons.person_outline),
    ];
    final selected = destinations.indexWhere(
      (item) =>
          location.startsWith(item.path) ||
          (item.path == '/app/people' &&
              location.startsWith('/app/scheduling')),
    );
    final index = selected < 0 ? 0 : selected;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: true,
              minExtendedWidth: 210,
              leading: const Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.wine_bar_outlined, size: 30),
                    SizedBox(height: 12),
                    Text(
                      'Venue Wrangler',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'HOSPITALITY, IN HARMONY',
                      style: TextStyle(fontSize: 9, letterSpacing: 1.4),
                    ),
                  ],
                ),
              ),
              selectedIndex: index,
              onDestinationSelected: (index) =>
                  context.go(destinations[index].path),
              destinations: [
                for (final item in destinations)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    label: Text(item.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final overflow = destinations.length > 5;
    final visible = overflow ? destinations.take(4).toList() : destinations;
    return Scaffold(
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: overflow && index >= 4 ? 4 : index,
        onDestinationSelected: (selected) async {
          if (selected < visible.length) {
            context.go(visible[selected].path);
            return;
          }
          final route = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            builder: (context) => SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const WorkspaceHeading(
                        title: 'Your workspace',
                        subtitle: 'Everything you need, close at hand.',
                        icon: Icons.apps_rounded,
                      ),
                      for (final item in destinations.skip(4))
                        ListTile(
                          leading: Icon(item.icon),
                          title: Text(item.label),
                          selected: location.startsWith(item.path),
                          onTap: () => Navigator.pop(context, item.path),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
          if (context.mounted && route != null) context.go(route);
        },
        destinations: [
          for (final item in visible)
            NavigationDestination(icon: Icon(item.icon), label: item.label),
          if (overflow)
            const NavigationDestination(
              icon: Icon(Icons.more_horiz_rounded),
              label: 'More',
            ),
        ],
      ),
    );
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String? _joinCode;
  var _loadingCode = false;

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(tenantControllerProvider);
    final selection = ref.watch(workspaceControllerProvider);
    final queue = ref.watch(mutationQueueProvider);
    return tenant.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _Retry(
        message: error is AppFailure
            ? error.message
            : 'The workspace could not be loaded.',
        onRetry: () => ref.read(tenantControllerProvider.notifier).refresh(),
      ),
      data: (session) {
        final organization = session.organization(selection.organizationId);
        final venues = session.venuesFor(selection.organizationId);
        final venue = venues
            .where((item) => item.id == selection.venueId)
            .firstOrNull;
        final role = session.isPlatformAdmin
            ? 'Platform administrator'
            : session.ownMemberships
                  .where(
                    (item) => item.organizationId == selection.organizationId,
                  )
                  .map((item) => AppRole.byKey(item.roleKey)?.label)
                  .whereType<String>()
                  .join(', ');
        final canInvite =
            selection.organizationId != null &&
            session.can(selection.organizationId!, Permission.membershipInvite);
        final clock = venue == null
            ? null
            : const VenueClock().format(DateTime.now().toUtc(), venue.timezone);
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            HospitalityHero(
              title: 'A beautiful service\nstarts here.',
              subtitle:
                  venue?.name ??
                  organization?.name ??
                  'Your hospitality workspace',
              eyebrow: 'TONIGHT · VENUE WRANGLER',
              detail: clock == null
                  ? 'Bring your venue to life'
                  : 'Venue time $clock · ${venue!.timezone}',
            ),
            const SizedBox(height: 28),
            const WorkspaceHeading(
              title: 'Make it a great night',
              subtitle: 'The floor, the cellar, and your people. All together.',
              icon: Icons.auto_awesome_outlined,
            ),
            if (venue != null)
              LayoutBuilder(
                builder: (context, constraints) {
                  final actions = [
                    if (session.can(
                          selection.organizationId!,
                          Permission.floorRead,
                        ) ||
                        session.can(
                          selection.organizationId!,
                          Permission.reservationRead,
                        ))
                      (
                        title: 'Welcome your guests',
                        subtitle: 'Seating, tables & reservations',
                        icon: Icons.event_seat_outlined,
                        path: '/app/host',
                      ),
                    if (session.can(
                      selection.organizationId!,
                      Permission.wineCatalogRead,
                    ))
                      (
                        title: 'Explore the cellar',
                        subtitle: 'Wines, stock & locations',
                        icon: Icons.wine_bar_outlined,
                        path: '/app/cellar',
                      ),
                    if (session.can(
                          selection.organizationId!,
                          Permission.scheduleRead,
                        ) ||
                        session.can(
                          selection.organizationId!,
                          Permission.timeclockSelf,
                        ))
                      (
                        title: 'Bring your team together',
                        subtitle: 'Schedules, shifts & time',
                        icon: Icons.groups_outlined,
                        path: '/app/people',
                      ),
                    if (session.can(
                          selection.organizationId!,
                          Permission.eventRead,
                        ) ||
                        session.can(
                          selection.organizationId!,
                          Permission.reportOperational,
                        ))
                      (
                        title: 'Plan what comes next',
                        subtitle: 'Events, insights & business',
                        icon: Icons.insights_outlined,
                        path: '/app/business',
                      ),
                  ];
                  final width = constraints.maxWidth >= 700
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      for (final action in actions)
                        SizedBox(
                          width: width,
                          child: WorkspaceActionCard(
                            title: action.title,
                            subtitle: action.subtitle,
                            icon: action.icon,
                            onTap: () => context.go(action.path),
                          ),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 24),
            Text(
              'Workspace details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(organization?.name ?? 'No organization'),
            if (session.isPlatformAdmin &&
                session.organizations.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(selection.organizationId),
                initialValue: selection.organizationId,
                decoration: const InputDecoration(labelText: 'Organization'),
                items: [
                  for (final item in session.organizations)
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(workspaceControllerProvider.notifier)
                        .selectOrganization(value);
                  }
                },
              ),
              if (venues.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(selection.venueId),
                  initialValue: selection.venueId,
                  decoration: const InputDecoration(labelText: 'Venue'),
                  items: [
                    for (final item in venues)
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(workspaceControllerProvider.notifier)
                          .selectVenue(value);
                    }
                  },
                ),
              ],
            ],
            if (role.isNotEmpty) Text(role),
            if (clock != null) Text('Venue time $clock'),
            if (venue != null &&
                importSchemas.any(
                  (schema) =>
                      session.can(selection.organizationId!, schema.permission),
                )) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.go('/app/import'),
                icon: const Icon(Icons.upload_file),
                label: const Text('Import data'),
              ),
            ],
            const SizedBox(height: 16),
            queue.when(
              data: (items) => FutureBuilder(
                future: items.pending(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return StatusBanner(
                    message:
                        '$count invite${count == 1 ? '' : 's'} saved on this device.',
                    tone: BannerTone.warning,
                    actionLabel: 'Send now',
                    onAction: () async {
                      final tokens = await ref
                          .read(tenantControllerProvider.notifier)
                          .flushInvites();
                      if (!context.mounted || tokens.isEmpty) return;
                      await showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Invite code'),
                          content: SelectableText(tokens.join('\n')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            if (venue == null && session.canCreateVenue) ...[
              const SizedBox(height: 12),
              const StatusBanner(
                message: 'Create the opening venue before cellar setup.',
                tone: BannerTone.warning,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/onboarding/venue'),
                child: const Text('Create venue'),
              ),
            ],
            if (canInvite && venue != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _loadingCode
                    ? null
                    : () async {
                        setState(() => _loadingCode = true);
                        try {
                          final code = await ref
                              .read(tenantControllerProvider.notifier)
                              .venueJoinCode(venue.id);
                          setState(() => _joinCode = code);
                        } on AppFailure catch (failure) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(failure.message)),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _loadingCode = false);
                        }
                      },
                child: const Text('Show venue join code'),
              ),
              if (_joinCode != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SelectableText('Join code $_joinCode'),
                ),
            ],
            if (venue != null &&
                session.can(
                  selection.organizationId!,
                  Permission.wineCatalogWrite,
                )) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/app/cellar'),
                child: const Text('Set up the cellar'),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Recent activity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (session.auditEvents.isEmpty)
              const Text(
                'No audited actions yet. Creating the organization is the first record.',
              )
            else
              for (final event in session.auditEvents)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(event.action),
                  subtitle: Text(
                    const VenueClock().format(
                      event.createdAt,
                      venue?.timezone ?? 'UTC',
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class TeamPage extends ConsumerStatefulWidget {
  const TeamPage({super.key});

  @override
  ConsumerState<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends ConsumerState<TeamPage> {
  final _email = TextEditingController();
  var _role = AppRole.server.key;
  var _orgWide = false;
  var _busy = false;
  String? _error;
  String? _issuedToken;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(tenantControllerProvider);
    final selection = ref.watch(workspaceControllerProvider);
    return tenant.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _Retry(
        message: error is AppFailure
            ? error.message
            : 'Team could not be loaded.',
        onRetry: () => ref.read(tenantControllerProvider.notifier).refresh(),
      ),
      data: (session) {
        final orgId = selection.organizationId;
        if (orgId == null) {
          return const Center(child: Text('Create an organization first.'));
        }
        if (!session.can(orgId, Permission.membershipRead) &&
            !session.can(orgId, Permission.membershipInvite)) {
          return const Center(
            child: Text('You do not have permission to view the team.'),
          );
        }
        final members = session.membersFor(orgId);
        final invites = session.invites.where(
          (item) => item.organizationId == orgId,
        );
        final requests = session.joinRequests.where(
          (item) => item.organizationId == orgId,
        );
        final actor = session.isPlatformAdmin
            ? AppRole.organizationOwner
            : const CapabilityChecker().strongest(
                session.ownMemberships
                    .where((item) => item.organizationId == orgId)
                    .map((item) => AppRole.byKey(item.roleKey))
                    .whereType<AppRole>(),
              );
        final assignable = actor == null
            ? <AppRole>[]
            : AppRole.assignableBy(actor);
        final canInvite = session.can(orgId, Permission.membershipInvite);
        final canApprove = session.can(orgId, Permission.membershipApprove);
        final canAssign = session.can(orgId, Permission.membershipAssignRole);
        final orgWideActor =
            session.isPlatformAdmin ||
            session.ownMemberships.any(
              (item) => item.organizationId == orgId && item.venueId == null,
            );
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Team', style: Theme.of(context).textTheme.headlineMedium),
            if (_error != null) ...[
              const SizedBox(height: 12),
              StatusBanner(message: _error!),
            ],
            if (_issuedToken != null) ...[
              const SizedBox(height: 12),
              StatusBanner(
                message: 'Invite created. Copy this code now. It is not stored again.',
                tone: BannerTone.success,
              ),
              const SizedBox(height: 8),
              SelectableText(_issuedToken!),
              TextButton(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: _issuedToken!)),
                child: const Text('Copy invite code'),
              ),
            ],
            const SizedBox(height: 16),
            Text('Members', style: Theme.of(context).textTheme.titleLarge),
            for (final member in members)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  member.displayName ?? member.email ?? member.userId,
                ),
                subtitle: Text(
                  AppRole.byKey(member.roleKey)?.label ?? member.roleKey,
                ),
                trailing:
                    canAssign &&
                        actor != null &&
                        member.userId != session.userId
                    ? DropdownButton<String>(
                        value: member.roleKey,
                        items: [
                          for (final role in assignable)
                            DropdownMenuItem(
                              value: role.key,
                              child: Text(role.label),
                            ),
                        ],
                        onChanged: (value) async {
                          if (value == null || value == member.roleKey) return;
                          try {
                            await ref
                                .read(tenantControllerProvider.notifier)
                                .assignRole(
                                  membershipId: member.id,
                                  roleKey: value,
                                );
                          } on AppFailure catch (failure) {
                            setState(() => _error = failure.message);
                          }
                        },
                      )
                    : null,
              ),
            if (canInvite && assignable.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Invite', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              TextField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: assignable.any((role) => role.key == _role)
                    ? _role
                    : assignable.first.key,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  for (final role in assignable)
                    DropdownMenuItem(value: role.key, child: Text(role.label)),
                ],
                onChanged: (value) => setState(() => _role = value ?? _role),
              ),
              if (orgWideActor)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Organization-wide'),
                  value: _orgWide,
                  onChanged: (value) => setState(() => _orgWide = value),
                ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final emailError = FieldValidator.email(_email.text);
                        if (emailError != null) {
                          setState(() => _error = emailError);
                          return;
                        }
                        setState(() {
                          _busy = true;
                          _error = null;
                          _issuedToken = null;
                        });
                        try {
                          final result = await ref
                              .read(tenantControllerProvider.notifier)
                              .submitInvite(
                                organizationId: orgId,
                                venueId: _orgWide ? null : selection.venueId,
                                email: _email.text.trim(),
                                roleKey: _role,
                              );
                          switch (result) {
                            case InviteCreated(:final token):
                              setState(() => _issuedToken = token);
                            case InviteAlreadyOpen():
                              setState(
                                () => _error = 'An open invite already exists for that email and role.',
                              );
                            case InviteQueued():
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Invite saved on this device. It will send when the connection returns.',
                                    ),
                                  ),
                                );
                              }
                          }
                        } on AppFailure catch (failure) {
                          setState(() => _error = failure.message);
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                child: Text(_busy ? 'Sending' : 'Create invite'),
              ),
            ],
            if (canApprove) ...[
              const SizedBox(height: 24),
              Text(
                'Join requests',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (requests.isEmpty) const Text('No pending requests.'),
              for (final request in requests)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    request.displayName ?? request.email ?? 'Request',
                  ),
                  subtitle: Text(
                    AppRole.byKey(request.requestedRoleKey)?.label ??
                        request.requestedRoleKey,
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Approve',
                        onPressed: () => ref
                            .read(tenantControllerProvider.notifier)
                            .reviewJoin(requestId: request.id, approve: true),
                        icon: const Icon(Icons.check),
                      ),
                      IconButton(
                        tooltip: 'Decline',
                        onPressed: () => ref
                            .read(tenantControllerProvider.notifier)
                            .reviewJoin(requestId: request.id, approve: false),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 24),
            Text('Open invites', style: Theme.of(context).textTheme.titleLarge),
            if (invites.isEmpty) const Text('No open invites.'),
            for (final invite in invites)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(invite.email),
                subtitle: Text(
                  AppRole.byKey(invite.roleKey)?.label ?? invite.roleKey,
                ),
                trailing: canInvite
                    ? TextButton(
                        onPressed: () => ref
                            .read(tenantControllerProvider.notifier)
                            .revokeInvite(invite.id),
                        child: const Text('Revoke'),
                      )
                    : null,
              ),
          ],
        );
      },
    );
  }
}

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final email = auth is AuthSignedIn ? auth.email : '';
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(email),
        const SizedBox(height: 16),
        if (_error != null) StatusBanner(message: _error!),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Display name'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            final error = FieldValidator.displayName(_name.text);
            if (error != null) {
              setState(() => _error = error);
              return;
            }
            try {
              await ref
                  .read(tenantControllerProvider.notifier)
                  .updateDisplayName(_name.text.trim());
              setState(() => _error = null);
            } on AppFailure catch (failure) {
              setState(() => _error = failure.message);
            }
          },
          child: const Text('Save name'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusBanner(message: message),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
