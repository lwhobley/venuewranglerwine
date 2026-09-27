import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/permissions/app_role.dart';
import '../../../core/time/venue_clock.dart';
import '../../../core/widgets/status_banner.dart';
import '../application/tenant_controller.dart';
import '../domain/tenant_models.dart';
import '../domain/tenant_repository.dart';
import '../domain/validators.dart';
import 'auth_frame.dart';

class CreateOrganizationPage extends ConsumerStatefulWidget {
  const CreateOrganizationPage({super.key});

  @override
  ConsumerState<CreateOrganizationPage> createState() => _CreateOrganizationPageState();
}

class _CreateOrganizationPageState extends ConsumerState<CreateOrganizationPage> {
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _legal = TextEditingController();
  var _slugEdited = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _legal.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nameError = FieldValidator.organizationName(_name.text);
    final slugError = FieldValidator.slug(_slug.text);
    if (nameError != null || slugError != null) {
      setState(() => _error = nameError ?? slugError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(tenantControllerProvider.notifier).createOrganization(
        name: _name.text.trim(),
        slug: _slug.text.trim(),
        legalName: _legal.text.trim().isEmpty ? null : _legal.text.trim(),
      );
    } on AppFailure catch (failure) {
      setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      title: 'Create the organization',
      subtitle: 'This is the tenant boundary. Venues and wine inventory live under it.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) StatusBanner(message: _error!),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Organization name'),
            onChanged: (value) {
              if (_slugEdited) return;
              _slug.text = FieldValidator.slugFromName(value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _slug,
            decoration: const InputDecoration(labelText: 'Slug'),
            onChanged: (_) => _slugEdited = true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _legal,
            decoration: const InputDecoration(labelText: 'Legal name (optional)'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Creating' : 'Create organization'),
          ),
          TextButton(
            onPressed: () => context.go('/onboarding/join'),
            child: const Text('Have a venue code? Request to join'),
          ),
          TextButton(
            onPressed: () => context.go('/invite'),
            child: const Text('Accept an invite'),
          ),
        ],
      ),
    );
  }
}

class CreateVenuePage extends ConsumerStatefulWidget {
  const CreateVenuePage({super.key});

  @override
  ConsumerState<CreateVenuePage> createState() => _CreateVenuePageState();
}

class _CreateVenuePageState extends ConsumerState<CreateVenuePage> {
  final _name = TextEditingController();
  final _city = TextEditingController();
  var _timezone = 'America/New_York';
  var _style = 'wine_club';
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = ref.read(tenantControllerProvider).value;
    final orgId = session?.ownMemberships.firstOrNull?.organizationId;
    if (orgId == null) {
      setState(() => _error = 'Create an organization first.');
      return;
    }
    final nameError = FieldValidator.organizationName(_name.text);
    if (nameError != null) {
      setState(() => _error = nameError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(tenantControllerProvider.notifier).createVenue(
        CreateVenueRequest(
          organizationId: orgId,
          name: _name.text.trim(),
          slug: FieldValidator.slugFromName(_name.text),
          timezone: _timezone,
          currencyCode: 'USD',
          serviceStyle: _style,
          city: _city.text.trim(),
        ),
      );
      if (mounted) context.go('/app/home');
    } on AppFailure catch (failure) {
      setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      title: 'Open the venue',
      subtitle: 'A wine club starts as an opening venue. Cellar mapping comes next.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) StatusBanner(message: _error!),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Venue name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _city,
            decoration: const InputDecoration(labelText: 'City'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _timezone,
            decoration: const InputDecoration(labelText: 'Timezone'),
            items: [
              for (final zone in hospitalityTimeZones)
                DropdownMenuItem(value: zone, child: Text(zone)),
            ],
            onChanged: (value) => setState(() => _timezone = value ?? _timezone),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _style,
            decoration: const InputDecoration(labelText: 'Service style'),
            items: const [
              DropdownMenuItem(value: 'wine_club', child: Text('Wine club')),
              DropdownMenuItem(value: 'restaurant', child: Text('Restaurant')),
              DropdownMenuItem(value: 'club', child: Text('Club')),
              DropdownMenuItem(value: 'event_venue', child: Text('Event venue')),
              DropdownMenuItem(value: 'bar', child: Text('Bar')),
            ],
            onChanged: (value) => setState(() => _style = value ?? _style),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Saving' : 'Create venue'),
          ),
        ],
      ),
    );
  }
}

class JoinVenuePage extends ConsumerStatefulWidget {
  const JoinVenuePage({super.key});

  @override
  ConsumerState<JoinVenuePage> createState() => _JoinVenuePageState();
}

class _JoinVenuePageState extends ConsumerState<JoinVenuePage> {
  final _code = TextEditingController();
  final _message = TextEditingController();
  VenueLookup? _lookup;
  var _role = AppRole.server.key;
  var _busy = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _code.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _lookupVenue() async {
    setState(() {
      _busy = true;
      _error = null;
      _lookup = null;
    });
    try {
      final found = await ref.read(tenantControllerProvider.notifier).lookupVenue(_code.text);
      setState(() {
        _lookup = found;
        _error = found == null ? 'No venue uses that code.' : null;
      });
    } on AppFailure catch (failure) {
      setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _request() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(tenantControllerProvider.notifier).requestJoin(
        code: _code.text,
        roleKey: _role,
        message: _message.text,
      );
      setState(() => _success = 'Request sent. A manager must approve it.');
    } on AppFailure catch (failure) {
      setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = AppRole.values.where((role) => role != AppRole.organizationOwner);
    return AuthFrame(
      title: 'Request to join',
      subtitle: 'Enter the venue code from a manager. This does not grant access yet.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) StatusBanner(message: _error!),
          if (_success != null) StatusBanner(message: _success!, tone: BannerTone.success),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Venue code'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _busy ? null : _lookupVenue, child: const Text('Find venue')),
          if (_lookup != null) ...[
            const SizedBox(height: 16),
            Text('${_lookup!.venueName} · ${_lookup!.organizationName}'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Requested role'),
              items: [
                for (final role in roles)
                  DropdownMenuItem(value: role.key, child: Text(role.label)),
              ],
              onChanged: (value) => setState(() => _role = value ?? _role),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              decoration: const InputDecoration(labelText: 'Note to the manager'),
              maxLength: 500,
            ),
            FilledButton(onPressed: _busy ? null : _request, child: const Text('Send request')),
          ],
          TextButton(
            onPressed: () => context.go('/onboarding/organization'),
            child: const Text('Create an organization instead'),
          ),
        ],
      ),
    );
  }
}

class AcceptInvitePage extends ConsumerStatefulWidget {
  const AcceptInvitePage({super.key, this.initialToken});

  final String? initialToken;

  @override
  ConsumerState<AcceptInvitePage> createState() => _AcceptInvitePageState();
}

class _AcceptInvitePageState extends ConsumerState<AcceptInvitePage> {
  late final TextEditingController _token;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _token = TextEditingController(text: widget.initialToken ?? '');
  }

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_token.text.trim().length < 32) {
      setState(() => _error = 'Paste the full invite code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(tenantControllerProvider.notifier).acceptInvite(_token.text.trim());
    } on AppFailure catch (failure) {
      setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      title: 'Accept invite',
      subtitle: 'Sign in with the email the invite was issued to.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) StatusBanner(message: _error!),
          TextField(
            controller: _token,
            decoration: const InputDecoration(labelText: 'Invite code'),
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _accept,
            child: Text(_busy ? 'Checking' : 'Accept invite'),
          ),
        ],
      ),
    );
  }
}
