import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/permissions/permission.dart';
import '../../../core/time/venue_clock.dart';
import '../../../core/widgets/status_banner.dart';
import '../../onboarding/application/tenant_controller.dart';
import '../../onboarding/application/workspace_controller.dart';
import '../application/cellar_controller.dart';
import '../application/count_controller.dart';
import '../domain/count_repository.dart';
import '../domain/count_rules.dart';

class CountSessionsPage extends ConsumerStatefulWidget {
  const CountSessionsPage({super.key});

  @override
  ConsumerState<CountSessionsPage> createState() => _CountSessionsPageState();
}

class _CountSessionsPageState extends ConsumerState<CountSessionsPage> {
  var _kind = 'spot';
  var _mode = 'blind';
  String? _error;
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(workspaceControllerProvider);
    final session = ref.watch(tenantControllerProvider).value;
    if (selection.venueId == null) {
      return const Center(child: Text('Create a venue before counting.'));
    }
    final orgId = selection.organizationId;
    if (orgId == null) {
      return const Center(child: Text('Create a venue before counting.'));
    }
    final canCount = session?.can(orgId, Permission.wineCountExecute) ?? false;
    if (!canCount && !(session?.can(orgId, Permission.wineCountReview) ?? false) && !(session?.can(orgId, Permission.wineCountApprove) ?? false)) {
      return const Center(child: Text('You do not have permission to count.'));
    }
    final sessions = ref.watch(countSessionsProvider);
    final cellar = ref.watch(cellarControllerProvider).value;
    final rooms = cellar?.rooms.where((room) => room.kind == 'room').toList() ?? const [];
    return sessions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _CountMessage(
        message: error is AppFailure ? error.message : 'Counts could not be loaded.',
        onRetry: () => ref.invalidate(countSessionsProvider),
      ),
      data: (items) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Counts', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('Expected quantity is frozen when the session starts. A blind count does not show it.'),
            if (_error != null) ...[const SizedBox(height: 12), StatusBanner(message: _error!)],
            if (canCount) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Count type'),
                items: [for (final kind in countKinds) DropdownMenuItem(value: kind, child: Text(kind))],
                onChanged: (value) => setState(() => _kind = value ?? _kind),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _mode,
                decoration: const InputDecoration(labelText: 'Mode'),
                items: const [
                  DropdownMenuItem(value: 'blind', child: Text('Blind')),
                  DropdownMenuItem(value: 'expected', child: Text('Show expected')),
                ],
                onChanged: (value) => setState(() => _mode = value ?? _mode),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() {
                          _busy = true;
                          _error = null;
                        });
                        try {
                          final id = await ref.read(countSessionsProvider.notifier).start(
                            kind: _kind,
                            mode: _mode,
                            locationId: rooms.length == 1 ? rooms.first.id : null,
                          );
                          if (context.mounted) context.go('/app/cellar/counts/$id');
                        } on AppFailure catch (failure) {
                          setState(() => _error = failure.message);
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                child: const Text('Start count'),
              ),
            ],
            const SizedBox(height: 24),
            if (items.isEmpty) const Text('No count sessions yet.'),
            for (final item in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${item.kind} · ${item.mode}'),
                subtitle: Text('${item.status} · ${item.countedLines} counted · ${item.openLines} open'),
                trailing: Text(const VenueClock().format(item.createdAt, 'UTC')),
                onTap: () => context.go(
                  item.status == 'in_progress'
                      ? '/app/cellar/counts/${item.id}'
                      : '/app/cellar/counts/${item.id}/review',
                ),
              ),
          ],
        );
      },
    );
  }
}

class CountModePage extends ConsumerStatefulWidget {
  const CountModePage({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<CountModePage> createState() => _CountModePageState();
}

class _CountModePageState extends ConsumerState<CountModePage> {
  final _location = TextEditingController();
  final _sku = TextEditingController();
  final _reason = TextEditingController();
  var _quantity = 0;
  String? _lotId;
  List<CountLotChoice> _lots = const [];
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _location.dispose();
    _sku.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desk = ref.watch(countDeskProvider(widget.sessionId));
    final wines = ref.watch(cellarControllerProvider).value?.wines ?? const [];
    final query = _sku.text.trim().toLowerCase();
    final matches = query.isEmpty
        ? const <String>[]
        : wines
            .where((wine) => wine.sku.toLowerCase().contains(query) || wine.label.toLowerCase().contains(query))
            .take(5)
            .map((wine) => wine.sku)
            .toList();
    return desk.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _CountMessage(
        message: error is AppFailure ? error.message : 'This count could not be opened.',
        onRetry: () => ref.invalidate(countDeskProvider(widget.sessionId)),
      ),
      data: (data) {
        final pending = data.drafts.where((draft) => draft.syncStatus != 'synced').length;
        final syncLabel = data.lastSync == null
            ? 'Not synced yet'
            : 'Last sync ${const VenueClock().format(data.lastSync!, 'UTC')}';
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Count', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(syncLabel),
            if (pending > 0)
              StatusBanner(
                message: '$pending ${pending == 1 ? 'entry is' : 'entries are'} saved on this device.',
                tone: BannerTone.warning,
                actionLabel: 'Sync',
                onAction: () => _run(() => ref.read(countDeskProvider(widget.sessionId).notifier).sync()),
              ),
            if (_error != null) ...[const SizedBox(height: 12), StatusBanner(message: _error!)],
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Location code',
                helperText: 'Type the slot code, or paste the label payload vw:loc:CODE',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sku,
              decoration: const InputDecoration(labelText: 'Wine SKU'),
              onChanged: (_) => setState(() {}),
            ),
            for (final sku in matches)
              TextButton(
                onPressed: () => setState(() => _sku.text = sku),
                child: Text(sku),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      final lots = await ref.read(countRepositoryProvider).lotChoices(
                        sessionId: widget.sessionId,
                        locationCode: _location.text,
                        sku: _sku.text,
                      );
                      final parsed = parseLocationScan(_location.text);
                      if (parsed != null) {
                        final store = await ref.read(countDraftStoreProvider.future);
                        await store.saveLotChoices(
                          sessionId: widget.sessionId,
                          locationCode: parsed,
                          sku: _sku.text.trim().toUpperCase(),
                          lotIds: [for (final lot in lots) lot.lotId],
                        );
                      }
                      setState(() {
                        _lots = lots;
                        _lotId = lots.length == 1 ? lots.single.lotId : null;
                      });
                    }),
              child: const Text('Find lots'),
            ),
            if (_lots.length > 1) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _lots.any((lot) => lot.lotId == _lotId) ? _lotId : null,
                decoration: const InputDecoration(labelText: 'Lot'),
                items: [
                  for (final lot in _lots)
                    DropdownMenuItem(
                      value: lot.lotId,
                      child: Text(
                        lot.expectedQuantity == null ? lot.label : '${lot.label} · book ${lot.expectedQuantity}',
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _lotId = value),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  tooltip: 'Decrease',
                  onPressed: _quantity == 0 ? null : () => setState(() => _quantity -= 1),
                  icon: const Icon(Icons.remove),
                ),
                Text('$_quantity', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  tooltip: 'Increase',
                  onPressed: () => setState(() => _quantity += 1),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Note')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      await ref.read(countDeskProvider(widget.sessionId).notifier).saveLocal(
                        locationCode: _location.text,
                        sku: _sku.text,
                        quantity: '$_quantity',
                        reason: _reason.text,
                        lotId: _lotId,
                      );
                      await ref.read(countDeskProvider(widget.sessionId).notifier).sync();
                    }),
              child: const Text('Save count'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(() => ref.read(countDeskProvider(widget.sessionId).notifier).submit()),
              child: const Text('Submit for review'),
            ),
            const SizedBox(height: 24),
            Text('On this device', style: Theme.of(context).textTheme.titleLarge),
            for (final draft in data.drafts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${draft.locationCode} · ${draft.sku.isEmpty ? 'empty' : draft.sku}'),
                subtitle: Text('${draft.quantity} · ${draft.syncStatus}${draft.message == null ? '' : ' · ${draft.message}'}'),
              ),
          ],
        );
      },
    );
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

class CountReviewPage extends ConsumerWidget {
  const CountReviewPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(workspaceControllerProvider);
    final membership = ref.watch(tenantControllerProvider).value;
    final canReview = selection.organizationId != null &&
        (membership?.can(selection.organizationId!, Permission.wineCountReview) ?? false);
    final canApprove = selection.organizationId != null &&
        (membership?.can(selection.organizationId!, Permission.wineCountApprove) ?? false);
    final desk = ref.watch(countDeskProvider(sessionId));
    return desk.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _CountMessage(
        message: error is AppFailure ? error.message : 'The review could not be loaded.',
        onRetry: () => ref.invalidate(countDeskProvider(sessionId)),
      ),
      data: (data) {
        final status = data.sheet.isEmpty ? 'in_progress' : data.sheet.first.status;
        final blind = data.sheet.isNotEmpty && data.sheet.first.mode == 'blind';
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Count review', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(status),
            if (blind && !canReview && !canApprove)
              const Text('Expected quantity stays hidden on a blind count.'),
            const SizedBox(height: 12),
            for (final line in data.sheet)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(line.locationCode),
                subtitle: Text(_lineText(line, showExpected: !blind || canReview || canApprove)),
                trailing: line.conflict && canReview
                    ? TextButton(
                        onPressed: () => ref.read(countDeskProvider(sessionId).notifier).resolve(
                          lineId: line.lineId,
                          quantity: line.otherCountedQuantity ?? line.countedQuantity ?? '0',
                        ),
                        child: const Text('Keep other'),
                      )
                    : null,
              ),
            if (canApprove && status == 'submitted')
              FilledButton(
                onPressed: () async {
                  try {
                    final written = await ref.read(countDeskProvider(sessionId).notifier).approve();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Approved. $written adjustment${written == 1 ? '' : 's'} posted.')),
                      );
                    }
                  } on AppFailure catch (failure) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
                    }
                  }
                },
                child: const Text('Approve adjustments'),
              ),
            if (canReview && status == 'submitted')
              OutlinedButton(
                onPressed: () => ref.read(countDeskProvider(sessionId).notifier).reject(),
                child: const Text('Reject count'),
              ),
          ],
        );
      },
    );
  }

  String _lineText(CountSheetLine line, {required bool showExpected}) {
    final counted = line.countedQuantity ?? 'not counted';
    final expected = showExpected ? visibleExpected(blind: false, canReview: true, expected: line.expectedQuantity) : null;
    final conflict = line.conflict ? ' · conflict ${line.otherCountedQuantity}' : '';
    if (expected == null) return '${line.sku} · counted $counted$conflict';
    return '${line.sku} · expected $expected · counted $counted$conflict';
  }
}

class _CountMessage extends StatelessWidget {
  const _CountMessage({required this.message, required this.onRetry});

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
