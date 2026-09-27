import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/permissions/permission.dart';
import '../../../core/widgets/status_banner.dart';
import '../../onboarding/application/tenant_controller.dart';
import '../../onboarding/application/workspace_controller.dart';
import '../application/allocation_controller.dart';
import '../application/cellar_controller.dart';
import '../domain/allocation_rules.dart';

class AllocationPage extends ConsumerStatefulWidget {
  const AllocationPage({super.key});

  @override
  ConsumerState<AllocationPage> createState() => _AllocationPageState();
}

class _AllocationPageState extends ConsumerState<AllocationPage> {
  final _memberName = TextEditingController();
  final _campaignName = TextEditingController();
  final _releaseOn = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _pickupQuantity = TextEditingController(text: '1');
  var _tier = 'standard';
  String? _campaignId;
  String? _memberId;
  String? _itemId;
  String? _error;
  String? _message;
  var _busy = false;

  @override
  void dispose() {
    _memberName.dispose();
    _campaignName.dispose();
    _releaseOn.dispose();
    _quantity.dispose();
    _pickupQuantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(workspaceControllerProvider);
    final membership = ref.watch(tenantControllerProvider).value;
    final orgId = selection.organizationId;
    if (selection.venueId == null || orgId == null) {
      return const Center(child: Text('Create a venue before allocating wine.'));
    }
    if (!(membership?.can(orgId, Permission.wineAllocationManage) ?? false)) {
      return const Center(child: Text('You do not have permission to allocate wine.'));
    }
    final desk = ref.watch(allocationDeskProvider);
    final wines = ref.watch(cellarControllerProvider).value?.wines ?? const [];
    return desk.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _AllocMessage(
        message: error is AppFailure ? error.message : 'Allocations could not be loaded.',
        onRetry: () => ref.invalidate(allocationDeskProvider),
      ),
      data: (data) {
        final campaignId = data.campaigns.any((item) => item.id == _campaignId)
            ? _campaignId
            : data.campaigns.firstOrNull?.id;
        final memberId = data.members.any((item) => item.id == _memberId)
            ? _memberId
            : data.members.firstOrNull?.id;
        final itemId = wines.any((item) => item.itemId == _itemId) ? _itemId : wines.firstOrNull?.itemId;
        final campaign = data.campaigns.where((item) => item.id == campaignId).firstOrNull;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Allocations', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('Reserving a release moves bottles out of house stock. A transfer cannot take them again.'),
            if (_error != null) ...[const SizedBox(height: 12), StatusBanner(message: _error!)],
            if (_message != null) ...[
              const SizedBox(height: 12),
              StatusBanner(message: _message!, tone: BannerTone.success),
            ],
            const SizedBox(height: 16),
            Text('Member', style: Theme.of(context).textTheme.titleLarge),
            TextField(controller: _memberName, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _tier,
              decoration: const InputDecoration(labelText: 'Tier'),
              items: const [
                DropdownMenuItem(value: 'standard', child: Text('Standard')),
                DropdownMenuItem(value: 'reserve', child: Text('Reserve')),
                DropdownMenuItem(value: 'founding', child: Text('Founding')),
              ],
              onChanged: (value) => setState(() => _tier = value ?? _tier),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(() => ref.read(allocationDeskProvider.notifier).createMember(
                        name: _memberName.text.trim(),
                        tier: _tier,
                      )),
              child: const Text('Add member'),
            ),
            const SizedBox(height: 24),
            Text('Release', style: Theme.of(context).textTheme.titleLarge),
            TextField(controller: _campaignName, decoration: const InputDecoration(labelText: 'Release name')),
            const SizedBox(height: 12),
            TextField(
              controller: _releaseOn,
              decoration: const InputDecoration(labelText: 'Release date', helperText: 'YYYY-MM-DD'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      final id = await ref.read(allocationDeskProvider.notifier).createCampaign(
                        name: _campaignName.text.trim(),
                        releaseOn: _releaseOn.text.trim(),
                      );
                      setState(() => _campaignId = id);
                    }),
              child: const Text('Create release'),
            ),
            if (data.campaigns.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: campaignId,
                decoration: const InputDecoration(labelText: 'Release'),
                items: [
                  for (final item in data.campaigns)
                    DropdownMenuItem(value: item.id, child: Text('${item.name} · ${item.status}')),
                ],
                onChanged: (value) => setState(() => _campaignId = value),
              ),
            ],
            if (campaign?.status == 'draft' && memberId != null && itemId != null) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: memberId,
                decoration: const InputDecoration(labelText: 'Member'),
                items: [
                  for (final member in data.members)
                    DropdownMenuItem(value: member.id, child: Text(member.name)),
                ],
                onChanged: (value) => setState(() => _memberId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: itemId,
                decoration: const InputDecoration(labelText: 'Wine'),
                items: [
                  for (final wine in wines)
                    DropdownMenuItem(value: wine.itemId, child: Text(wine.label)),
                ],
                onChanged: (value) => setState(() => _itemId = value),
              ),
              const SizedBox(height: 12),
              TextField(controller: _quantity, decoration: const InputDecoration(labelText: 'Bottles')),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => ref.read(allocationDeskProvider.notifier).addLine(
                          campaignId: campaignId!,
                          memberId: memberId,
                          itemId: itemId,
                          quantity: _quantity.text.trim(),
                        )),
                child: const Text('Add allocation line'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final holds = await ref.read(allocationDeskProvider.notifier).reserve(campaignId!);
                        setState(() => _message = 'Reserved. $holds hold${holds == 1 ? '' : 's'} posted.');
                      }),
                child: const Text('Reserve available bottles'),
              ),
            ],
            if (campaignId != null) ...[
              const SizedBox(height: 24),
              Text('Readiness', style: Theme.of(context).textTheme.titleLarge),
              _Readiness(
                campaignId: campaignId,
                pickupQuantity: _pickupQuantity,
                busy: _busy,
                onPickup: (lineId, reserved, fulfilled) => _run(() async {
                  final quantity = int.tryParse(_pickupQuantity.text.trim()) ?? 0;
                  if (!canPickup(reserved: reserved, fulfilled: fulfilled, quantity: quantity)) {
                    throw const ValidationFailure('Pickup cannot exceed the bottles still reserved.');
                  }
                  await ref.read(allocationDeskProvider.notifier).pickup(
                    campaignId: campaignId,
                    lineId: lineId,
                    quantity: _pickupQuantity.text.trim(),
                  );
                  setState(() => _message = 'Pickup recorded. Those bottles are member-held.');
                }),
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

class _Readiness extends ConsumerWidget {
  const _Readiness({
    required this.campaignId,
    required this.pickupQuantity,
    required this.busy,
    required this.onPickup,
  });

  final String campaignId;
  final TextEditingController pickupQuantity;
  final bool busy;
  final Future<void> Function(String lineId, int reserved, int fulfilled) onPickup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(allocationReadinessProvider(campaignId));
    return lines.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => StatusBanner(message: error is AppFailure ? error.message : 'Readiness failed.'),
      data: (items) {
        if (items.isEmpty) return const Text('No lines on this release yet.');
        return Column(
          children: [
            for (final line in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${line.memberName} · ${line.label.isEmpty ? line.sku : line.label}'),
                subtitle: Text(
                  'Need ${line.required} · reserved ${line.reserved} · picked up ${line.fulfilled} · short ${line.shortage}',
                ),
                trailing: line.status == 'reserved' && line.reserved != line.fulfilled
                    ? TextButton(
                        onPressed: busy
                            ? null
                            : () => onPickup(
                                  line.lineId,
                                  int.parse(line.reserved),
                                  int.parse(line.fulfilled),
                                ),
                        child: const Text('Pick up'),
                      )
                    : null,
              ),
            TextField(
              controller: pickupQuantity,
              decoration: const InputDecoration(labelText: 'Pickup bottles'),
            ),
          ],
        );
      },
    );
  }
}

class _AllocMessage extends StatelessWidget {
  const _AllocMessage({required this.message, required this.onRetry});

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
