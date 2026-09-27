import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/permissions/permission.dart';
import '../../../core/widgets/status_banner.dart';
import '../../onboarding/application/tenant_controller.dart';
import '../../onboarding/application/workspace_controller.dart';
import '../application/cellar_controller.dart';
import '../application/service_controller.dart';
import '../domain/service_rules.dart';

class ServicePage extends ConsumerStatefulWidget {
  const ServicePage({super.key});

  @override
  ConsumerState<ServicePage> createState() => _ServicePageState();
}

class _ServicePageState extends ConsumerState<ServicePage> {
  final _listName = TextEditingController(text: 'By the glass');
  final _pourMl = TextEditingController(text: '150');
  String? _itemId;
  String? _error;
  String? _message;
  var _busy = false;

  @override
  void dispose() {
    _listName.dispose();
    _pourMl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(workspaceControllerProvider);
    final membership = ref.watch(tenantControllerProvider).value;
    final orgId = selection.organizationId;
    if (selection.venueId == null || orgId == null) {
      return const Center(child: Text('Create a venue before service.'));
    }
    if (!(membership?.can(orgId, Permission.wineCatalogRead) ?? false)) {
      return const Center(child: Text('You do not have permission to view the list.'));
    }
    final canPublish = membership?.can(orgId, Permission.wineListPublish) ?? false;
    final canPour = membership?.can(orgId, Permission.wineMovementWrite) ?? false;
    final wines = ref.watch(cellarControllerProvider).value?.wines ?? const [];
    final desk = ref.watch(serviceDeskProvider);
    return desk.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ServiceMessage(
        message: error is AppFailure ? error.message : 'The service list could not be loaded.',
        onRetry: () => ref.invalidate(serviceDeskProvider),
      ),
      data: (data) {
        final itemId = wines.any((wine) => wine.itemId == _itemId) ? _itemId : wines.firstOrNull?.itemId;
        final listId = data.board.isEmpty ? null : data.board.first.listId;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Service', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('A glass is available only from house bottles or an open bottle that can still cover the pour.'),
            if (_error != null) ...[const SizedBox(height: 12), StatusBanner(message: _error!)],
            if (_message != null) ...[
              const SizedBox(height: 12),
              StatusBanner(message: _message!, tone: BannerTone.success),
            ],
            if (canPublish && data.board.isEmpty) ...[
              const SizedBox(height: 16),
              TextField(controller: _listName, decoration: const InputDecoration(labelText: 'List name')),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => ref.read(serviceDeskProvider.notifier).createList(
                          name: _listName.text.trim(),
                          kind: 'glass',
                          threshold: 1,
                        )),
                child: const Text('Create glass list'),
              ),
            ],
            if (canPublish && listId != null && itemId != null) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: itemId,
                decoration: const InputDecoration(labelText: 'Wine'),
                items: [
                  for (final wine in wines) DropdownMenuItem(value: wine.itemId, child: Text(wine.label)),
                ],
                onChanged: (value) => setState(() => _itemId = value),
              ),
              const SizedBox(height: 12),
              TextField(controller: _pourMl, decoration: const InputDecoration(labelText: 'Pour ml')),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => ref.read(serviceDeskProvider.notifier).addItem(
                          listId: listId,
                          itemId: itemId,
                          pourMl: int.tryParse(_pourMl.text.trim()),
                        )),
                child: const Text('Add to list'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => ref.read(serviceDeskProvider.notifier).publish(
                          listId: listId,
                          published: !data.board.first.published,
                        )),
                child: Text(data.board.first.published ? 'Unpublish' : 'Publish'),
              ),
            ],
            const SizedBox(height: 24),
            Text('Availability', style: Theme.of(context).textTheme.titleLarge),
            if (data.board.isEmpty) const Text('No list items yet.'),
            for (final item in data.board)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.label.isEmpty ? item.sku : item.label),
                subtitle: Text(
                  item.available
                      ? 'Available · ${item.houseBottles} house · ${item.openRemainingMl} ml open'
                      : '86 · ${item.unavailableReason} · ${item.houseBottles} house',
                ),
                trailing: canPublish
                    ? TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() => ref.read(serviceDeskProvider.notifier).set86(
                                  listItemId: item.listItemId,
                                  eightySixed: !item.manual86,
                                )),
                        child: Text(item.manual86 ? 'Clear 86' : '86'),
                      )
                    : null,
              ),
            if (canPour) ...[
              const SizedBox(height: 16),
              Text('Open bottles', style: Theme.of(context).textTheme.titleLarge),
              if (itemId != null)
                FilledButton(
                  onPressed: _busy ? null : () => _run(() => ref.read(serviceDeskProvider.notifier).openBottle(itemId)),
                  child: const Text('Open one house bottle'),
                ),
              for (final bottle in data.openBottles)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${bottle.remainingMl} ml left of ${bottle.openedMl}'),
                  trailing: TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            final pour = int.tryParse(_pourMl.text.trim()) ?? 0;
                            if (remainingAfterPour(remainingMl: bottle.remainingMl, pourMl: pour) == null) {
                              throw const ValidationFailure('That pour is larger than the open bottle.');
                            }
                            final left = await ref.read(serviceDeskProvider.notifier).pour(
                              openBottleId: bottle.id,
                              pourMl: pour,
                              reason: 'glass',
                            );
                            setState(() => _message = left == 0 ? 'Bottle finished.' : '$left ml left.');
                          }),
                    child: const Text('Pour'),
                  ),
                ),
            ],
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

class _ServiceMessage extends StatelessWidget {
  const _ServiceMessage({required this.message, required this.onRetry});

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
