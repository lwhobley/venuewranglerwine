import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/hospitality_design.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/money/decimal_amount.dart';
import '../../../core/permissions/permission.dart';
import '../../../core/widgets/status_banner.dart';
import '../../onboarding/application/tenant_controller.dart';
import '../../onboarding/application/workspace_controller.dart';
import '../application/cellar_controller.dart';
import '../domain/cellar_rules.dart';

class CellarPage extends ConsumerStatefulWidget {
  const CellarPage({super.key});

  @override
  ConsumerState<CellarPage> createState() => _CellarPageState();
}

class _CellarPageState extends ConsumerState<CellarPage> {
  final _roomName = TextEditingController();
  final _roomCode = TextEditingController(text: 'CELLAR-A');
  final _unitName = TextEditingController();
  final _unitCode = TextEditingController(text: 'RACK-01');
  String? _roomId;
  String? _templateKey;
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _roomName.dispose();
    _roomCode.dispose();
    _unitName.dispose();
    _unitCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gate = _gate(ref, Permission.wineCatalogRead);
    if (gate != null) return gate;
    final canWrite = _can(ref, Permission.wineCatalogWrite);
    final cellar = ref.watch(cellarControllerProvider);
    return cellar.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _Retry(
        message: error is AppFailure
            ? error.message
            : 'The cellar could not be loaded.',
        onRetry: () => ref.read(cellarControllerProvider.notifier).refresh(),
      ),
      data: (snapshot) {
        final rooms = snapshot.rooms
            .where((room) => room.kind == 'room')
            .toList();
        final roomId = rooms.any((room) => room.id == _roomId)
            ? _roomId
            : rooms.firstOrNull?.id;
        final templateKey =
            snapshot.templates.any((item) => item.key == _templateKey)
            ? _templateKey
            : snapshot.templates.firstOrNull?.key;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const WorkspaceHeading(
              title: 'The cellar',
              subtitle: 'Every bottle has a place. Make it easy to find.',
              icon: Icons.wine_bar_outlined,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                if (canWrite)
                  OutlinedButton(
                    onPressed: () => context.go('/app/import'),
                    child: const Text('Import inventory & locations'),
                  ),
                OutlinedButton(
                  onPressed: () => context.go('/app/cellar/import'),
                  child: const Text('Import wines'),
                ),
                OutlinedButton(
                  onPressed: () => context.go('/app/cellar/receive'),
                  child: const Text('Receive'),
                ),
                OutlinedButton(
                  onPressed: () => context.go('/app/cellar/counts'),
                  child: const Text('Count'),
                ),
                OutlinedButton(
                  onPressed: () => context.go('/app/cellar/service'),
                  child: const Text('Service'),
                ),
                if (_can(ref, Permission.wineMovementWrite))
                  OutlinedButton(
                    onPressed: () => context.go('/app/cellar/move'),
                    child: const Text('Move'),
                  ),
                if (_can(ref, Permission.wineAllocationManage))
                  OutlinedButton(
                    onPressed: () => context.go('/app/cellar/allocations'),
                    child: const Text('Allocate'),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              StatusBanner(message: _error!),
            ],
            if (snapshot.stagingId != null) ...[
              const SizedBox(height: 16),
              Text(
                'Staging holds ${snapshot.staged.fold<int>(0, (sum, lot) => sum + int.parse(lot.quantity))} bottles.',
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Locations & rooms',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final location in snapshot.rooms.where(
              (location) =>
                  location.kind == 'concourse' ||
                  location.kind == 'outlet' ||
                  location.kind == 'zone',
            ))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(location.name),
                subtitle: Text(
                  '${location.kind} · ${location.code}${location.parentId == null ? '' : ' · under ${snapshot.rooms.where((parent) => parent.id == location.parentId).firstOrNull?.name ?? 'parent location'}'}',
                ),
              ),
            if (rooms.isEmpty) const Text('No cellar room yet.'),
            for (final room in rooms)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(room.name),
                subtitle: Text(
                  room.code +
                      (room.parentId == null
                          ? ''
                          : ' · under ${snapshot.rooms.where((parent) => parent.id == room.parentId).firstOrNull?.name ?? 'parent location'}'),
                ),
              ),
            if (canWrite) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _roomName,
                decoration: const InputDecoration(labelText: 'Room name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _roomCode,
                decoration: const InputDecoration(labelText: 'Room code'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => ref
                            .read(cellarControllerProvider.notifier)
                            .createRoom(
                              name: _roomName.text.trim(),
                              code: _roomCode.text.trim(),
                            ),
                      ),
                child: const Text('Add room'),
              ),
              const SizedBox(height: 24),
              Text(
                'Place a rack',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (rooms.isEmpty)
                const Text('Add a room before placing a rack.')
              else if (snapshot.templates.isEmpty)
                const Text('Rack templates are not available yet.')
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: roomId,
                  decoration: const InputDecoration(labelText: 'Room'),
                  items: [
                    for (final room in rooms)
                      DropdownMenuItem(
                        value: room.id,
                        child: Text('${room.code} · ${room.name}'),
                      ),
                  ],
                  onChanged: (value) => setState(() => _roomId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: templateKey,
                  decoration: const InputDecoration(labelText: 'Template'),
                  items: [
                    for (final template in snapshot.templates)
                      DropdownMenuItem(
                        value: template.key,
                        child: Text(
                          '${template.label} · ${template.rows}x${template.columns}',
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _templateKey = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _unitName,
                  decoration: const InputDecoration(labelText: 'Rack name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _unitCode,
                  decoration: const InputDecoration(labelText: 'Rack code'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy || roomId == null || templateKey == null
                      ? null
                      : () => _run(
                          () => ref
                              .read(cellarControllerProvider.notifier)
                              .placeUnit(
                                locationId: roomId,
                                templateKey: templateKey,
                                name: _unitName.text.trim(),
                                code: _unitCode.text.trim(),
                              ),
                        ),
                  child: const Text('Place rack'),
                ),
              ],
            ],
            const SizedBox(height: 24),
            Text('Mapped slots', style: Theme.of(context).textTheme.titleLarge),
            if (snapshot.slots.isEmpty)
              const Text(
                'Placing a rack creates addressable slots. Those slots are not deleted when stock is in them.',
              )
            else
              for (final unit in snapshot.units) ...[
                const SizedBox(height: 8),
                Text(unit.code),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final slot in snapshot.slots.where(
                      (item) => item.unitId == unit.id,
                    ))
                      Chip(
                        label: Text(
                          '${slot.locationCode}  ${slot.onHand}/${slot.capacityBottles}',
                        ),
                      ),
                  ],
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

class WineImportPage extends ConsumerStatefulWidget {
  const WineImportPage({super.key});

  @override
  ConsumerState<WineImportPage> createState() => _WineImportPageState();
}

class _WineImportPageState extends ConsumerState<WineImportPage> {
  final _csv = TextEditingController();
  WineImportPreview? _preview;
  String? _message;
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _csv.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gate = _gate(ref, Permission.wineCatalogWrite);
    if (gate != null) return gate;
    final cellar = ref.watch(cellarControllerProvider);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Import wines', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'SKU is the idempotent key. A second import updates the profile and does not change on-hand quantity.',
        ),
        const SizedBox(height: 12),
        if (_error != null) StatusBanner(message: _error!),
        if (_message != null)
          StatusBanner(message: _message!, tone: BannerTone.success),
        TextField(
          controller: _csv,
          minLines: 8,
          maxLines: 14,
          decoration: const InputDecoration(labelText: 'CSV'),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () async {
                final sample = await rootBundle.loadString(
                  'assets/opening_club_wines.csv',
                );
                setState(() {
                  _csv.text = sample;
                  _preview = parseWineCsv(sample);
                });
              },
              child: const Text('Load opening sample'),
            ),
            OutlinedButton(
              onPressed: () =>
                  setState(() => _preview = parseWineCsv(_csv.text)),
              child: const Text('Preview'),
            ),
          ],
        ),
        if (_preview != null) ...[
          const SizedBox(height: 16),
          Text(
            '${_preview!.validRows.length} ready, ${_preview!.invalidRows.length} rejected',
          ),
          for (final row in _preview!.rows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(row.sku.isEmpty ? 'Row ${row.line}' : row.sku),
              subtitle: Text(row.error ?? '${row.producer} ${row.cuvee}'),
            ),
          FilledButton(
            onPressed: _busy || _preview!.validRows.isEmpty
                ? null
                : () async {
                    setState(() {
                      _busy = true;
                      _error = null;
                      _message = null;
                    });
                    try {
                      final result = await ref
                          .read(cellarControllerProvider.notifier)
                          .importWines(_preview!.validRows);
                      setState(() {
                        _message =
                            'Imported ${result.imported}, updated ${result.updated}.';
                        _error = result.errors.isEmpty
                            ? null
                            : result.errors.join('\n');
                      });
                    } on AppFailure catch (failure) {
                      setState(() => _error = failure.message);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: Text(_busy ? 'Importing' : 'Import valid rows'),
          ),
        ],
        const SizedBox(height: 16),
        cellar.maybeWhen(
          data: (snapshot) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Catalog', style: Theme.of(context).textTheme.titleLarge),
              if (snapshot.wines.isEmpty) const Text('No inventory items yet.'),
              for (final wine in snapshot.wines)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(wine.label),
                  subtitle: Text(
                    wine.catalogName == null
                        ? '${wine.sku} · ${wine.wineType} · ${wine.bottleMl} ml'
                        : wine.sku,
                  ),
                ),
            ],
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class ReceivePage extends ConsumerStatefulWidget {
  const ReceivePage({super.key});

  @override
  ConsumerState<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends ConsumerState<ReceivePage> {
  final _vendorName = TextEditingController();
  final _quantity = TextEditingController(text: '6');
  final _cost = TextEditingController(text: '24.0000');
  final _putAwayQuantity = TextEditingController(text: '1');
  String? _vendorId;
  String? _itemId;
  String? _lotId;
  String? _slotId;
  String? _error;
  String? _message;
  var _busy = false;

  @override
  void dispose() {
    _vendorName.dispose();
    _quantity.dispose();
    _cost.dispose();
    _putAwayQuantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gate = _gate(ref, Permission.wineCatalogRead);
    if (gate != null) return gate;
    final canReceive = _can(ref, Permission.wineReceive);
    final canPurchase = _can(ref, Permission.winePurchase);
    final canMove = _can(ref, Permission.wineMovementWrite);
    final cellar = ref.watch(cellarControllerProvider);
    return cellar.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _Retry(
        message: error is AppFailure
            ? error.message
            : 'Receiving could not be loaded.',
        onRetry: () => ref.read(cellarControllerProvider.notifier).refresh(),
      ),
      data: (snapshot) {
        if (snapshot.wines.isEmpty) {
          return _Empty(
            message: 'Import the wine catalog before receiving.',
            action: 'Import wines',
            onAction: () => context.go('/app/cellar/import'),
          );
        }
        final vendorId = snapshot.vendors.any((item) => item.id == _vendorId)
            ? _vendorId
            : snapshot.vendors.firstOrNull?.id;
        final itemId = snapshot.wines.any((item) => item.itemId == _itemId)
            ? _itemId!
            : snapshot.wines.first.itemId;
        final lotId = snapshot.staged.any((item) => item.lotId == _lotId)
            ? _lotId
            : snapshot.staged.firstOrNull?.lotId;
        final slotId = snapshot.slots.any((item) => item.id == _slotId)
            ? _slotId
            : snapshot.slots.firstOrNull?.id;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Receiving',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'A receipt lands in staging. Put-away is a separate movement into a mapped slot.',
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              StatusBanner(message: _error!),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              StatusBanner(message: _message!, tone: BannerTone.success),
            ],
            if (canPurchase) ...[
              const SizedBox(height: 16),
              Text('Vendor', style: Theme.of(context).textTheme.titleLarge),
              TextField(
                controller: _vendorName,
                decoration: const InputDecoration(labelText: 'Vendor name'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => ref
                            .read(cellarControllerProvider.notifier)
                            .createVendor(name: _vendorName.text.trim()),
                      ),
                child: const Text('Add vendor'),
              ),
            ],
            if (snapshot.vendors.isNotEmpty)
              for (final vendor in snapshot.vendors) Text(vendor.name),
            if (canReceive && snapshot.vendors.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Receive to staging',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              DropdownButtonFormField<String>(
                initialValue: vendorId,
                decoration: const InputDecoration(labelText: 'Vendor'),
                items: [
                  for (final vendor in snapshot.vendors)
                    DropdownMenuItem(
                      value: vendor.id,
                      child: Text(vendor.name),
                    ),
                ],
                onChanged: (value) => setState(() => _vendorId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: itemId,
                decoration: const InputDecoration(labelText: 'Wine'),
                items: [
                  for (final wine in snapshot.wines)
                    DropdownMenuItem(
                      value: wine.itemId,
                      child: Text(wine.label),
                    ),
                ],
                onChanged: (value) => setState(() => _itemId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quantity,
                decoration: const InputDecoration(labelText: 'Bottles'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cost,
                decoration: const InputDecoration(labelText: 'Unit cost'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy || vendorId == null
                    ? null
                    : () => _run(() async {
                        DecimalAmount.parse(_cost.text);
                        DecimalAmount.parse(_quantity.text, scale: 3);
                        await ref
                            .read(cellarControllerProvider.notifier)
                            .receive(
                              vendorId: vendorId,
                              itemId: itemId,
                              quantity: _quantity.text.trim(),
                              unitCost: DecimalAmount.parse(_cost.text)
                                  .toString(),
                            );
                        setState(() => _message = 'Received into staging.');
                      }),
                child: const Text('Receive'),
              ),
            ],
            const SizedBox(height: 24),
            Text('Staging', style: Theme.of(context).textTheme.titleLarge),
            if (snapshot.staged.isEmpty)
              const Text('Nothing is waiting to be put away.'),
            for (final lot in snapshot.staged)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(lot.label),
                subtitle: Text('${lot.quantity} in staging'),
              ),
            if (canMove &&
                snapshot.staged.isNotEmpty &&
                snapshot.slots.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: lotId,
                decoration: const InputDecoration(labelText: 'Staged lot'),
                items: [
                  for (final lot in snapshot.staged)
                    DropdownMenuItem(
                      value: lot.lotId,
                      child: Text('${lot.label} · ${lot.quantity}'),
                    ),
                ],
                onChanged: (value) => setState(() => _lotId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: slotId,
                decoration: const InputDecoration(
                  labelText: 'Destination slot',
                ),
                items: [
                  for (final slot in snapshot.slots)
                    DropdownMenuItem(
                      value: slot.id,
                      child: Text(
                        '${slot.locationCode} · ${slot.onHand}/${slot.capacityBottles}',
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _slotId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _putAwayQuantity,
                decoration: const InputDecoration(labelText: 'Bottles to move'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy || lotId == null || slotId == null
                    ? null
                    : () => _run(() async {
                        final lot = snapshot.staged.firstWhere(
                          (item) => item.lotId == lotId,
                        );
                        final slot = snapshot.slots.firstWhere(
                          (item) => item.id == slotId,
                        );
                        final error = putAwayError(
                          staged: DecimalAmount.parse(lot.quantity, scale: 3),
                          requested: DecimalAmount.parse(
                            _putAwayQuantity.text.trim(),
                            scale: 3,
                          ),
                          slotOnHand: DecimalAmount.parse(
                            slot.onHand,
                            scale: 3,
                          ),
                          slotCapacity: slot.capacityBottles,
                        );
                        if (error != null) throw ValidationFailure(error);
                        await ref
                            .read(cellarControllerProvider.notifier)
                            .putAway(
                              lotId: lotId,
                              slotId: slotId,
                              quantity: _putAwayQuantity.text.trim(),
                            );
                        setState(
                          () => _message = 'Put away ${slot.locationCode}.',
                        );
                      }),
                child: const Text('Put away'),
              ),
            ] else if (snapshot.staged.isNotEmpty && snapshot.slots.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Place a rack before put-away. Staging stock stays where it is.',
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
      setState(
        () => _error = 'Use a decimal cost and a whole-bottle quantity.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

Widget? _gate(WidgetRef ref, String permission) {
  final selection = ref.watch(workspaceControllerProvider);
  final session = ref.watch(tenantControllerProvider).value;
  if (selection.venueId == null) {
    return const _Empty(
      message: 'Create a venue before opening the cellar.',
      action: '',
      onAction: null,
    );
  }
  if (session == null || selection.organizationId == null) {
    return const Center(child: CircularProgressIndicator());
  }
  if (!session.can(selection.organizationId!, permission)) {
    return const Center(
      child: Text('You do not have permission to open the cellar.'),
    );
  }
  return null;
}

bool _can(WidgetRef ref, String permission) {
  final selection = ref.watch(workspaceControllerProvider);
  final session = ref.watch(tenantControllerProvider).value;
  if (session == null || selection.organizationId == null) return false;
  return session.can(selection.organizationId!, permission);
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

class _Empty extends StatelessWidget {
  const _Empty({
    required this.message,
    required this.action,
    required this.onAction,
  });

  final String message;
  final String action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (onAction != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onAction, child: Text(action)),
            ],
          ],
        ),
      ),
    );
  }
}
