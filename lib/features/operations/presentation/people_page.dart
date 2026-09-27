import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/permissions/permission.dart';
import '../../../core/widgets/status_banner.dart';
import '../../onboarding/application/tenant_controller.dart';
import '../../onboarding/application/workspace_controller.dart';
import '../application/ops_controller.dart';
import '../domain/ops_rules.dart';

class PeoplePage extends ConsumerStatefulWidget {
  const PeoplePage({super.key});

  @override
  ConsumerState<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends ConsumerState<PeoplePage> {
  final _log = TextEditingController();
  final _docTitle = TextEditingController();
  final _docBody = TextEditingController();
  String? _error;
  String? _message;
  List<Map<String, dynamic>> _shifts = const [];
  var _clockedIn = false;
  List<Map<String, dynamic>> _runs = const [];
  List<Map<String, dynamic>> _logs = const [];
  List<Map<String, dynamic>> _docs = const [];
  var _busy = false;

  @override
  void dispose() {
    _log.dispose();
    _docTitle.dispose();
    _docBody.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(workspaceControllerProvider);
    final membership = ref.watch(tenantControllerProvider).value;
    final auth = ref.watch(authControllerProvider);
    final orgId = selection.organizationId;
    final venueId = selection.venueId;
    if (orgId == null || venueId == null || auth is! AuthSignedIn) {
      return const Center(child: Text('Open a venue first.'));
    }
    final canPublish = membership?.can(orgId, Permission.schedulePublish) ?? false;
    final canClock = membership?.can(orgId, Permission.timeclockSelf) ?? false;
    final canChecklist = membership?.can(orgId, Permission.checklistExecute) ?? false;
    final canManageList = membership?.can(orgId, Permission.checklistManage) ?? false;
    final canLog = membership?.can(orgId, Permission.logbookWrite) ?? false;
    final canDocs = membership?.can(orgId, Permission.documentManage) ?? false;
    final canReadDocs = membership?.can(orgId, Permission.documentRead) ?? false;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('People', style: Theme.of(context).textTheme.headlineMedium),
        if (_error != null) StatusBanner(message: _error!),
        if (_message != null) StatusBanner(message: _message!, tone: BannerTone.success),
        FilledButton(onPressed: () => _load(venueId, auth.userId), child: const Text('Refresh')),
        if (canPublish)
          FilledButton(
            onPressed: _busy ? null : () => _run(() async {
              final start = DateTime.now().toUtc().add(const Duration(hours: 2));
              final end = start.add(const Duration(hours: 6));
              if (!shiftWindowValid(start, end)) throw const ValidationFailure('Shift end must be after the start.');
              await ref.read(opsRepositoryProvider).createShift(
                organizationId: orgId,
                venueId: venueId,
                roleKey: 'server',
                startsAt: start,
                endsAt: end,
              );
              final published = await ref.read(opsRepositoryProvider).publishShifts(venueId);
              setState(() => _message = 'Published $published shift${published == 1 ? '' : 's'}.');
              await _load(venueId, auth.userId);
            }),
            child: const Text('Add and publish a server shift'),
          ),
        for (final shift in _shifts)
          Text('${shift['role_key']} · ${shift['status']} · ${shift['starts_at']}'),
        if (canClock)
          FilledButton(
            onPressed: _busy ? null : () => _run(() async {
              final repo = ref.read(opsRepositoryProvider);
              if (canClockIn(openEntry: _clockedIn)) {
                await repo.clockIn(venueId);
              } else {
                await repo.clockOut(venueId);
              }
              await _load(venueId, auth.userId);
            }),
            child: Text(_clockedIn ? 'Clock out' : 'Clock in'),
          ),
        if (canManageList)
          FilledButton(
            onPressed: _busy ? null : () => _run(() async {
              final id = await ref.read(opsRepositoryProvider).createChecklist(
                organizationId: orgId,
                venueId: venueId,
                name: 'Opening',
                itemLabel: 'Walk the floor',
              );
              await ref.read(opsRepositoryProvider).startChecklist(id);
              await _load(venueId, auth.userId);
            }),
            child: const Text('Start opening checklist'),
          ),
        if (canChecklist)
          for (final run in _runs)
            TextButton(
              onPressed: () => _run(() async {
                final items = await ref.read(opsRepositoryProvider).checklistItems(run['template_id'] as String);
                if (items.isEmpty) return;
                await ref.read(opsRepositoryProvider).completeItem(runId: run['id'] as String, itemId: items.first['id'] as String);
                await _load(venueId, auth.userId);
              }),
              child: const Text('Complete next checklist item'),
            ),
        if (canLog) ...[
          TextField(controller: _log, decoration: const InputDecoration(labelText: 'Handoff note')),
          FilledButton(
            onPressed: _busy ? null : () => _run(() async {
              await ref.read(opsRepositoryProvider).writeLog(venueId, _log.text.trim());
              await _load(venueId, auth.userId);
            }),
            child: const Text('Save logbook handoff'),
          ),
        ],
        for (final entry in _logs) Text(entry['body'] as String),
        if (canDocs) ...[
          TextField(controller: _docTitle, decoration: const InputDecoration(labelText: 'Document title')),
          TextField(controller: _docBody, decoration: const InputDecoration(labelText: 'Document body')),
          FilledButton(
            onPressed: _busy ? null : () => _run(() async {
              await ref.read(opsRepositoryProvider).createDocument(
                organizationId: orgId,
                venueId: venueId,
                title: _docTitle.text.trim(),
                body: _docBody.text.trim(),
              );
              await _load(venueId, auth.userId);
            }),
            child: const Text('Add document'),
          ),
        ],
        if (canReadDocs)
          for (final doc in _docs)
            TextButton(
              onPressed: () => _run(() => ref.read(opsRepositoryProvider).acknowledge(doc['id'] as String)),
              child: Text('Acknowledge ${doc['title']}'),
            ),
      ],
    );
  }

  Future<void> _load(String venueId, String userId) async {
    final repo = ref.read(opsRepositoryProvider);
    final shifts = await repo.shifts(venueId);
    final open = await repo.openClock(venueId, userId);
    final runs = await repo.openRuns(venueId);
    final logs = await repo.logbook(venueId);
    final docs = await repo.documents(venueId);
    if (!mounted) return;
    setState(() {
      _shifts = shifts;
      _clockedIn = open.isNotEmpty;
      _runs = runs;
      _logs = logs;
      _docs = docs;
    });
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
