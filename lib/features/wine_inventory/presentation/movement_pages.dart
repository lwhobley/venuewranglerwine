import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/money/decimal_amount.dart';
import '../../../core/permissions/permission.dart';
import '../../../core/time/venue_clock.dart';
import '../../../core/widgets/status_banner.dart';
import '../../onboarding/application/tenant_controller.dart';
import '../../onboarding/application/workspace_controller.dart';
import '../application/movement_controller.dart';
import '../domain/movement_rules.dart';

class MovementPage extends ConsumerStatefulWidget {
  const MovementPage({super.key});

  @override
  ConsumerState<MovementPage> createState() => _MovementPageState();
}

class _MovementPageState extends ConsumerState<MovementPage> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _holder = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  var _kind = 'service_bar';
  String? _sourceKey;
  String? _destinationId;
  String? _error;
  String? _message;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _holder.dispose();
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(workspaceControllerProvider);
    final membership = ref.watch(tenantControllerProvider).value;
    final orgId = selection.organizationId;
    if (selection.venueId == null || orgId == null) {
      return const Center(child: Text('Create a venue before moving wine.'));
    }
    final canMove = membership?.can(orgId, Permission.wineMovementWrite) ?? false;
    final canCreate = membership?.can(orgId, Permission.wineCatalogWrite) ?? false;
    if (!canMove && !canCreate) {
      return const Center(child: Text('You do not have permission to move wine.'));
    }
    final desk = ref.watch(movementDeskProvider);
    return desk.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _MoveMessage(
        message: error is AppFailure ? error.message : 'Movements could not be loaded.',
        onRetry: () => ref.invalidate(movementDeskProvider),
      ),
      data: (data) {
        final sourceKey = data.movable.any((item) => '${item.lotId}|${item.slotId}' == _sourceKey)
            ? _sourceKey
            : data.movable.firstOrNull == null
            ? null
            : '${data.movable.first.lotId}|${data.movable.first.slotId}';
        final destinationId = data.destinations.any((item) => item.id == _destinationId)
            ? _destinationId
            : data.destinations.firstOrNull?.id;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Move wine', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('A transfer leaves reserve only if that lot has the bottles in the source slot.'),
            if (_error != null) ...[const SizedBox(height: 12), StatusBanner(message: _error!)],
            if (_message != null) ...[
              const SizedBox(height: 12),
              StatusBanner(message: _message!, tone: BannerTone.success),
            ],
            if (canCreate) ...[
              const SizedBox(height: 16),
              Text('Destination', style: Theme.of(context).textTheme.titleLarge),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Kind'),
                items: const [
                  DropdownMenuItem(value: 'service_bar', child: Text('Service bar')),
                  DropdownMenuItem(value: 'event_staging', child: Text('Event hold')),
                  DropdownMenuItem(value: 'member_locker', child: Text('Member locker')),
                ],
                onChanged: (value) => setState(() => _kind = value ?? _kind),
              ),
              const SizedBox(height: 12),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              TextField(controller: _code, decoration: const InputDecoration(labelText: 'Code')),
              if (_kind == 'member_locker') ...[
                const SizedBox(height: 12),
                TextField(controller: _holder, decoration: const InputDecoration(labelText: 'Member name')),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final holderError = serviceLocationError(kind: _kind, holderLabel: _holder.text);
                        if (holderError != null) throw ValidationFailure(holderError);
                        await ref.read(movementDeskProvider.notifier).createDestination(
                          kind: _kind,
                          name: _name.text.trim(),
                          code: _code.text.trim(),
                          holderLabel: _kind == 'member_locker' ? _holder.text.trim() : null,
                        );
                      }),
                child: const Text('Add destination'),
              ),
            ],
            if (data.destinations.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final location in data.destinations)
                Text('${location.code} · ${location.name}${location.holderLabel == null ? '' : ' · ${location.holderLabel}'}'),
            ],
            if (canMove && data.movable.isNotEmpty && data.destinations.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Transfer', style: Theme.of(context).textTheme.titleLarge),
              DropdownButtonFormField<String>(
                initialValue: sourceKey,
                decoration: const InputDecoration(labelText: 'Source lot'),
                items: [
                  for (final lot in data.movable)
                    DropdownMenuItem(
                      value: '${lot.lotId}|${lot.slotId}',
                      child: Text('${lot.label} · ${lot.locationCode} · ${lot.quantity}'),
                    ),
                ],
                onChanged: (value) => setState(() => _sourceKey = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: destinationId,
                decoration: const InputDecoration(labelText: 'Destination'),
                items: [
                  for (final location in data.destinations)
                    DropdownMenuItem(value: location.id, child: Text('${location.code} · ${location.name}')),
                ],
                onChanged: (value) => setState(() => _destinationId = value),
              ),
              const SizedBox(height: 12),
              TextField(controller: _quantity, decoration: const InputDecoration(labelText: 'Bottles')),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy || sourceKey == null || destinationId == null
                    ? null
                    : () => _run(() async {
                        final lot = data.movable.firstWhere(
                          (item) => '${item.lotId}|${item.slotId}' == sourceKey,
                        );
                        final error = transferError(
                          available: DecimalAmount.parse(lot.quantity, scale: 3),
                          requested: DecimalAmount.parse(_quantity.text.trim(), scale: 3),
                        );
                        if (error != null) throw ValidationFailure(error);
                        final result = await ref.read(movementDeskProvider.notifier).transfer(
                          lotId: lot.lotId,
                          sourceSlotId: lot.slotId,
                          destinationLocationId: destinationId,
                          quantity: _quantity.text.trim(),
                        );
                        setState(() {
                          _message =
                              'Moved ${result.sourceBefore} to ${result.sourceAfter} in the slot. Destination is now ${result.destinationAfter}.';
                        });
                      }),
                child: const Text('Transfer'),
              ),
            ] else if (canMove && data.movable.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('Put wine into a mapped slot before transferring it.'),
              ),
            const SizedBox(height: 24),
            Text('Ledger', style: Theme.of(context).textTheme.titleLarge),
            if (data.recent.isEmpty) const Text('No transfers yet.'),
            for (final transfer in data.recent)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${transfer.quantity} · ${transfer.sourceCode} → ${transfer.destinationName}'),
                subtitle: Text(
                  '${transfer.reason} · ${transfer.sourceBefore} to ${transfer.sourceAfter} · ${const VenueClock().format(transfer.createdAt, 'UTC')}',
                ),
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
    } on FormatException {
      setState(() => _error = 'Enter a whole number of bottles.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _MoveMessage extends StatelessWidget {
  const _MoveMessage({required this.message, required this.onRetry});

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
