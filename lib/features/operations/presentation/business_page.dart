import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/permissions/permission.dart';
import '../../../core/widgets/status_banner.dart';
import '../../onboarding/application/tenant_controller.dart';
import '../../onboarding/application/workspace_controller.dart';
import '../application/ops_controller.dart';
import '../domain/ops_rules.dart';

class BusinessPage extends ConsumerStatefulWidget {
  const BusinessPage({super.key});

  @override
  ConsumerState<BusinessPage> createState() => _BusinessPageState();
}

class _BusinessPageState extends ConsumerState<BusinessPage> {
  final _eventName = TextEditingController();
  final _beo = TextEditingController();
  final _message = TextEditingController();
  String? _error;
  String? _notice;
  String? _csv;
  List<Map<String, dynamic>> _events = const [];
  var _busy = false;

  @override
  void dispose() {
    _eventName.dispose();
    _beo.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(workspaceControllerProvider);
    final membership = ref.watch(tenantControllerProvider).value;
    final orgId = selection.organizationId;
    final venueId = selection.venueId;
    if (orgId == null || venueId == null) return const Center(child: Text('Open a venue first.'));
    final canEvent = membership?.can(orgId, Permission.eventManage) ?? false;
    final canChat = membership?.can(orgId, Permission.chatWrite) ?? false;
    final canReport = membership?.can(orgId, Permission.reportOperational) ?? false;
    final canIntegration = membership?.can(orgId, Permission.integrationManage) ?? false;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Business', style: Theme.of(context).textTheme.headlineMedium),
        if (_error != null) StatusBanner(message: _error!),
        if (_notice != null) StatusBanner(message: _notice!, tone: BannerTone.success),
        if (canEvent) ...[
          TextField(controller: _eventName, decoration: const InputDecoration(labelText: 'Event name')),
          FilledButton(
            onPressed: _busy ? null : () => _run(() async {
              await ref.read(opsRepositoryProvider).createEvent(
                organizationId: orgId,
                venueId: venueId,
                name: _eventName.text.trim(),
                guestCount: 40,
                startsAt: DateTime.now().toUtc().add(const Duration(days: 14)),
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
                  if (next == null) throw const ValidationFailure('This event is already closed.');
                  await ref.read(opsRepositoryProvider).advanceEvent(event['id'] as String);
                  await _load(venueId);
                }),
                child: const Text('Advance'),
              ),
            ),
            TextField(controller: _beo, decoration: const InputDecoration(labelText: 'BEO note')),
            TextButton(
              onPressed: () => _run(() async {
                final version = await ref.read(opsRepositoryProvider).addBeo(
                  eventId: event['id'] as String,
                  body: _beo.text.trim(),
                );
                setState(() => _notice = 'BEO version $version saved. Earlier versions stay.');
              }),
              child: const Text('Save BEO version'),
            ),
          ],
        ],
        if (canChat)
          FilledButton(
            onPressed: _busy ? null : () => _run(() async {
              final repo = ref.read(opsRepositoryProvider);
              final channels = await repo.channels(venueId);
              final channelId = channels.isEmpty
                  ? await repo.createChannel(venueId: venueId, name: 'floor')
                  : channels.first['id'] as String;
              await repo.postMessage(channelId: channelId, body: _message.text.trim().isEmpty ? 'Service note' : _message.text.trim());
              setState(() => _notice = 'Message posted.');
            }),
            child: const Text('Post to floor channel'),
          ),
        TextField(controller: _message, decoration: const InputDecoration(labelText: 'Channel message')),
        if (canIntegration)
          FilledButton(
            onPressed: _busy ? null : () => _run(() => ref.read(opsRepositoryProvider).saveIntegration(
              organizationId: orgId,
              providerKey: 'pos_generic',
              status: 'connected',
            )),
            child: const Text('Mark generic POS connection'),
          ),
        if (canReport)
          FilledButton(
            onPressed: _busy ? null : () => _run(() async {
              if (!reportAllowed(status: 'trial', entitled: true)) {
                throw const PermissionFailure('Reports need an active plan.');
              }
              final rows = await ref.read(opsRepositoryProvider).report(venueId);
              final csv = toCsv([
                ['metric', 'value'],
                for (final row in rows) [row['metric'].toString(), row['value'].toString()],
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
