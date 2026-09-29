import 'package:flutter/material.dart';

import '../../../core/widgets/hospitality_design.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/permissions/permission.dart';
import '../../../core/widgets/status_banner.dart';
import '../../onboarding/application/tenant_controller.dart';
import '../../onboarding/application/workspace_controller.dart';
import '../application/ops_controller.dart';
import '../domain/ops_rules.dart';
import '../domain/pos_gateway.dart';

class BusinessPage extends ConsumerStatefulWidget {
  const BusinessPage({super.key});

  @override
  ConsumerState<BusinessPage> createState() => _BusinessPageState();
}

class _BusinessPageState extends ConsumerState<BusinessPage> {
  final _eventName = TextEditingController();
  final _beo = TextEditingController();
  final _message = TextEditingController();
  final _accessToken = TextEditingController();
  final _clientId = TextEditingController();
  final _clientSecret = TextEditingController();
  final _merchantId = TextEditingController();
  final _shopDomain = TextEditingController();
  final _webhookUrl = TextEditingController();
  final _webhookSecret = TextEditingController();
  final _sku = TextEditingController();
  final _externalSku = TextEditingController();
  final _localSku = TextEditingController();
  String? _error;
  String? _notice;
  String? _csv;
  String _provider = 'square';
  var _sandbox = false;
  List<Map<String, dynamic>> _events = const [];
  List<Map<String, dynamic>> _connections = const [];
  List<Map<String, dynamic>> _squareLocations = const [];
  List<Map<String, dynamic>> _unmappedItems = const [];
  String? _squareConnectionId;
  String? _squareLocationId;
  String? _savedSquareLocationId;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selection = ref.read(workspaceControllerProvider);
      if (selection.organizationId != null && selection.venueId != null) {
        _loadIntegrations(selection.organizationId!, selection.venueId!);
      }
    });
  }

  @override
  void dispose() {
    _eventName.dispose();
    _beo.dispose();
    _message.dispose();
    _accessToken.dispose();
    _clientId.dispose();
    _clientSecret.dispose();
    _merchantId.dispose();
    _shopDomain.dispose();
    _webhookUrl.dispose();
    _webhookSecret.dispose();
    _sku.dispose();
    _externalSku.dispose();
    _localSku.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(workspaceControllerProvider, (previous, next) {
      if (previous?.organizationId != next.organizationId ||
          previous?.venueId != next.venueId) {
        if (next.organizationId != null && next.venueId != null) {
          _loadIntegrations(next.organizationId!, next.venueId!);
        }
      }
    });
    final selection = ref.watch(workspaceControllerProvider);
    final membership = ref.watch(tenantControllerProvider).value;
    final orgId = selection.organizationId;
    final venueId = selection.venueId;
    if (orgId == null || venueId == null) {
      return const Center(child: Text('Open a venue first.'));
    }
    final canEvent = membership?.can(orgId, Permission.eventManage) ?? false;
    final canChat = membership?.can(orgId, Permission.chatWrite) ?? false;
    final canReport =
        membership?.can(orgId, Permission.reportOperational) ?? false;
    final canIntegration =
        membership?.can(orgId, Permission.integrationManage) ?? false;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const WorkspaceHeading(
          title: 'A thriving venue',
          subtitle: 'Plan your events. Understand your business.',
          icon: Icons.insights_outlined,
        ),
        if (_error != null) StatusBanner(message: _error!),
        if (_notice != null)
          StatusBanner(message: _notice!, tone: BannerTone.success),
        if (canEvent) ...[
          TextField(
            controller: _eventName,
            decoration: const InputDecoration(labelText: 'Event name'),
          ),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    await ref
                        .read(opsRepositoryProvider)
                        .createEvent(
                          organizationId: orgId,
                          venueId: venueId,
                          name: _eventName.text.trim(),
                          guestCount: 40,
                          startsAt: DateTime.now().toUtc().add(
                            const Duration(days: 14),
                          ),
                        );
                    await _load(venueId);
                  }),
            child: const Text('Create inquiry'),
          ),
          for (final event in _events) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${event['name']} · ${event['stage']}'),
              trailing: TextButton(
                onPressed: () => _run(() async {
                  final next = nextEventStage(event['stage'] as String);
                  if (next == null) {
                    throw const ValidationFailure(
                      'This event is already closed.',
                    );
                  }
                  await ref
                      .read(opsRepositoryProvider)
                      .advanceEvent(event['id'] as String);
                  await _load(venueId);
                }),
                child: const Text('Advance'),
              ),
            ),
            TextField(
              controller: _beo,
              decoration: const InputDecoration(labelText: 'BEO note'),
            ),
            TextButton(
              onPressed: () => _run(() async {
                final version = await ref
                    .read(opsRepositoryProvider)
                    .addBeo(
                      eventId: event['id'] as String,
                      body: _beo.text.trim(),
                    );
                setState(
                  () => _notice =
                      'BEO version $version saved. Earlier versions stay.',
                );
              }),
              child: const Text('Save BEO version'),
            ),
          ],
        ],
        if (canChat)
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    final repo = ref.read(opsRepositoryProvider);
                    final channels = await repo.channels(venueId);
                    final channelId = channels.isEmpty
                        ? await repo.createChannel(
                            venueId: venueId,
                            name: 'floor',
                          )
                        : channels.first['id'] as String;
                    await repo.postMessage(
                      channelId: channelId,
                      body: _message.text.trim().isEmpty
                          ? 'Service note'
                          : _message.text.trim(),
                    );
                    setState(() => _notice = 'Message posted.');
                  }),
            child: const Text('Post to floor channel'),
          ),
        TextField(
          controller: _message,
          decoration: const InputDecoration(labelText: 'Channel message'),
        ),
        if (canIntegration) ..._posFields(orgId, venueId),
        if (canReport)
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    if (!reportAllowed(status: 'trial', entitled: true)) {
                      throw const PermissionFailure(
                        'Reports need an active plan.',
                      );
                    }
                    final rows = await ref
                        .read(opsRepositoryProvider)
                        .report(venueId);
                    final csv = toCsv([
                      ['metric', 'value'],
                      for (final row in rows)
                        [row['metric'].toString(), row['value'].toString()],
                    ]);
                    setState(() => _csv = csv);
                    await Clipboard.setData(ClipboardData(text: csv));
                  }),
            child: const Text('Export operational report'),
          ),
        if (_csv != null) SelectableText(_csv!),
      ],
    );
  }

  List<Widget> _posFields(String orgId, String venueId) {
    final pull = pullPosProviders.contains(_provider);
    return [
      DropdownButton<String>(
        value: _provider,
        items: [
          for (final key in posProviders)
            DropdownMenuItem(value: key, child: Text(key)),
        ],
        onChanged: (value) => setState(() => _provider = value ?? _provider),
      ),
      if (_provider == 'toast') ...[
        TextField(
          controller: _clientId,
          decoration: const InputDecoration(labelText: 'Toast client id'),
        ),
        TextField(
          controller: _clientSecret,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Toast client secret'),
        ),
      ] else if (_provider == 'shopify') ...[
        TextField(
          controller: _shopDomain,
          decoration: const InputDecoration(labelText: 'Shop domain'),
        ),
        TextField(
          controller: _accessToken,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Admin access token'),
        ),
      ] else if (pull) ...[
        if (_provider == 'clover')
          TextField(
            controller: _merchantId,
            decoration: const InputDecoration(labelText: 'Merchant id'),
          ),
        TextField(
          controller: _accessToken,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Access token'),
        ),
      ],
      TextField(
        controller: _webhookUrl,
        decoration: InputDecoration(
          labelText: pull ? '86 callback URL' : 'Outbound webhook URL',
        ),
      ),
      TextField(
        controller: _webhookSecret,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Webhook secret'),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Sandbox'),
        value: _sandbox,
        onChanged: (value) => setState(() => _sandbox = value ?? false),
      ),
      FilledButton(
        onPressed: _busy
            ? null
            : () => _run(() async {
                await ref
                    .read(opsRepositoryProvider)
                    .connectPos(
                      organizationId: orgId,
                      providerKey: _provider,
                      accessToken: _accessToken.text.trim(),
                      clientId: _clientId.text.trim(),
                      clientSecret: _clientSecret.text.trim(),
                      merchantId: _merchantId.text.trim(),
                      shopDomain: _shopDomain.text.trim(),
                      webhookUrl: _webhookUrl.text.trim(),
                      webhookSecret: _webhookSecret.text.trim(),
                      sandbox: _sandbox,
                    );
                _clearSecrets();
                await _loadIntegrations(orgId, venueId);
                setState(() => _notice = 'POS handshake succeeded.');
              }),
        child: const Text('Connect POS'),
      ),
      for (final connection in _connections)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            '${connection['provider_key']} · ${connection['status']}',
          ),
          trailing: connection['status'] == 'connected'
              ? Wrap(
                  spacing: 8,
                  children: [
                    if (salesPullProviders.contains(connection['provider_key']))
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                await ref
                                    .read(opsRepositoryProvider)
                                    .ingestPos(
                                      connectionId: connection['id'] as String,
                                      venueId: venueId,
                                    );
                                await _loadUnmapped(
                                  connection['id'] as String,
                                  venueId,
                                );
                                setState(
                                  () => _notice = _unmappedItems.isEmpty
                                      ? 'Sales pull finished.'
                                      : 'Sales pull finished. Map unmatched items below, then pull again.',
                                );
                              }),
                        child: const Text('Pull sales'),
                      ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              await ref
                                  .read(opsRepositoryProvider)
                                  .saveIntegration(
                                    organizationId: orgId,
                                    providerKey:
                                        connection['provider_key'] as String,
                                    status: 'disconnected',
                                  );
                              await _loadIntegrations(orgId, venueId);
                            }),
                      child: const Text('Disconnect'),
                    ),
                  ],
                )
              : null,
        ),
      if (_squareConnectionId != null) ...[
        const SizedBox(height: 16),
        Text(
          'Square location for this venue',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          _savedSquareLocationId == null
              ? 'Choose a Square location before pulling sales.'
              : 'Mapped location: $_savedSquareLocationId',
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => _run(() async {
                  final locations = await ref
                      .read(opsRepositoryProvider)
                      .squareLocations(_squareConnectionId!);
                  setState(() {
                    _squareLocations = locations;
                    _squareLocationId =
                        locations.any(
                          (row) => row['id'] == _savedSquareLocationId,
                        )
                        ? _savedSquareLocationId
                        : null;
                  });
                }),
          child: const Text('Load Square locations'),
        ),
        if (_squareLocations.isNotEmpty)
          DropdownButton<String>(
            value: _squareLocationId,
            hint: const Text('Select location'),
            items: [
              for (final row in _squareLocations)
                DropdownMenuItem(
                  value: row['id'] as String,
                  child: Text(row['name'] as String),
                ),
            ],
            onChanged: (value) => setState(() => _squareLocationId = value),
          ),
        FilledButton(
          onPressed: _busy || _squareLocationId == null
              ? null
              : () => _run(() async {
                  await ref
                      .read(opsRepositoryProvider)
                      .savePosVenueMap(
                        connectionId: _squareConnectionId!,
                        venueId: venueId,
                        externalLocationId: _squareLocationId!,
                      );
                  setState(() {
                    _savedSquareLocationId = _squareLocationId;
                    _notice = 'Square location mapped to this venue.';
                  });
                }),
          child: const Text('Save location mapping'),
        ),
        const SizedBox(height: 16),
        Text(
          'Square item mapping',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final row in _unmappedItems)
          ListTile(
            title: Text('${row['name']} · ${row['external_sku']}'),
            subtitle: Text('${row['line_count']} unmatched sale lines'),
            onTap: () => _externalSku.text = row['external_sku'] as String,
          ),
        TextField(
          controller: _externalSku,
          decoration: const InputDecoration(
            labelText: 'Square catalog item ID',
          ),
        ),
        TextField(
          controller: _localSku,
          decoration: const InputDecoration(labelText: 'Local wine SKU'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () => _run(() async {
                  await ref
                      .read(opsRepositoryProvider)
                      .savePosItemMap(
                        connectionId: _squareConnectionId!,
                        externalSku: _externalSku.text.trim(),
                        localSku: _localSku.text.trim(),
                      );
                  setState(
                    () => _notice =
                        'Item mapped. Pull sales again to reconcile it.',
                  );
                }),
          child: const Text('Save item mapping'),
        ),
      ],
      TextField(
        controller: _sku,
        decoration: const InputDecoration(labelText: 'SKU to 86'),
      ),
      FilledButton(
        onPressed: _busy
            ? null
            : () => _run(() async {
                final sku = _sku.text.trim();
                if (sku.isEmpty) {
                  throw const ValidationFailure('Enter the SKU to 86.');
                }
                final targets = _connections.where(
                  (row) => row['status'] == 'connected',
                );
                if (targets.isEmpty) {
                  throw const ValidationFailure(
                    'Connect a POS before sending an 86.',
                  );
                }
                for (final connection in targets) {
                  await ref
                      .read(opsRepositoryProvider)
                      .push86(
                        connectionId: connection['id'] as String,
                        sku: sku,
                        externalSku: sku,
                        available: false,
                      );
                }
                setState(() => _notice = '86 sent.');
              }),
        child: const Text('Send 86'),
      ),
    ];
  }

  void _clearSecrets() {
    _accessToken.clear();
    _clientId.clear();
    _clientSecret.clear();
    _merchantId.clear();
    _shopDomain.clear();
    _webhookUrl.clear();
    _webhookSecret.clear();
  }

  Future<void> _loadIntegrations(String organizationId, String venueId) async {
    final repository = ref.read(opsRepositoryProvider);
    final rows = await repository.integrations(organizationId);
    final square = rows.where(
      (row) => row['provider_key'] == 'square' && row['status'] == 'connected',
    );
    final squareId = square.isEmpty ? null : square.first['id'] as String;
    final savedLocation = squareId == null
        ? null
        : await repository.posVenueLocation(
            connectionId: squareId,
            venueId: venueId,
          );
    final unmatched = squareId == null
        ? <Map<String, dynamic>>[]
        : await repository.posUnmappedItems(
            connectionId: squareId,
            venueId: venueId,
          );
    if (mounted) {
      setState(() {
        _connections = rows;
        _squareConnectionId = squareId;
        _savedSquareLocationId = savedLocation;
        _squareLocationId = savedLocation;
        _unmappedItems = unmatched;
        if (squareId == null) _squareLocations = const [];
      });
    }
  }

  Future<void> _loadUnmapped(String connectionId, String venueId) async {
    final rows = await ref
        .read(opsRepositoryProvider)
        .posUnmappedItems(connectionId: connectionId, venueId: venueId);
    if (mounted) setState(() => _unmappedItems = rows);
  }

  Future<void> _load(String venueId) async {
    final events = await ref.read(opsRepositoryProvider).events(venueId);
    if (mounted) setState(() => _events = events);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AppFailure catch (failure) {
      setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
