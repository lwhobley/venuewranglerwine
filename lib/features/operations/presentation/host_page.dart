import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/permissions/permission.dart';
import '../../../core/widgets/status_banner.dart';
import '../../onboarding/application/tenant_controller.dart';
import '../../onboarding/application/workspace_controller.dart';
import '../../wine_inventory/application/cellar_controller.dart';
import '../application/ops_controller.dart';
import '../domain/ops_rules.dart';

class HostPage extends ConsumerStatefulWidget {
  const HostPage({super.key});

  @override
  ConsumerState<HostPage> createState() => _HostPageState();
}

class _HostPageState extends ConsumerState<HostPage> {
  final _guestName = TextEditingController();
  final _allergies = TextEditingController();
  final _seating = TextEditingController();
  final _tableLabel = TextEditingController();
  final _party = TextEditingController(text: '2');
  String? _guestId;
  String? _wineId;
  String? _error;
  List<Map<String, dynamic>> _board = const [];
  List<Map<String, dynamic>> _guests = const [];
  List<Map<String, dynamic>> _tables = const [];
  var _busy = false;

  @override
  void dispose() {
    _guestName.dispose();
    _allergies.dispose();
    _seating.dispose();
    _tableLabel.dispose();
    _party.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(workspaceControllerProvider);
    final membership = ref.watch(tenantControllerProvider).value;
    final orgId = selection.organizationId;
    final venueId = selection.venueId;
    if (orgId == null || venueId == null) return const Center(child: Text('Create a venue first.'));
    final canWrite = membership?.can(orgId, Permission.guestWrite) ?? false;
    final canSeatGuest = membership?.can(orgId, Permission.reservationSeat) ?? false;
    final canDesign = membership?.can(orgId, Permission.floorDesign) ?? false;
    final wines = ref.watch(cellarControllerProvider).value?.wines ?? const [];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Host stand', style: Theme.of(context).textTheme.headlineMedium),
        if (_error != null) ...[const SizedBox(height: 12), StatusBanner(message: _error!)],
        const SizedBox(height: 12),
        FilledButton(onPressed: () => _load(venueId), child: const Text('Refresh book')),
        if (canWrite) ...[
          const SizedBox(height: 16),
          TextField(controller: _guestName, decoration: const InputDecoration(labelText: 'Guest name')),
          TextField(controller: _allergies, decoration: const InputDecoration(labelText: 'Allergies')),
          TextField(controller: _seating, decoration: const InputDecoration(labelText: 'Seating preference')),
          FilledButton(
            onPressed: _busy ? null : () => _run(() async {
              final repo = ref.read(opsRepositoryProvider);
              final id = await repo.createGuest(
                organizationId: orgId,
                venueId: venueId,
                name: _guestName.text.trim(),
                allergies: _allergies.text.trim(),
                seating: _seating.text.trim(),
                vip: false,
              );
              if (_wineId != null) await repo.setFavorite(guestId: id, itemId: _wineId!);
              await _load(venueId);
            }),
            child: const Text('Save guest'),
          ),
          if (wines.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: wines.any((wine) => wine.itemId == _wineId) ? _wineId : wines.first.itemId,
              decoration: const InputDecoration(labelText: 'Favorite wine'),
              items: [for (final wine in wines) DropdownMenuItem(value: wine.itemId, child: Text(wine.label))],
              onChanged: (value) => setState(() => _wineId = value),
            ),
        ],
        if (canDesign) ...[
          TextField(controller: _tableLabel, decoration: const InputDecoration(labelText: 'Table label')),
          FilledButton(
            onPressed: _busy ? null : () => _run(() async {
              await ref.read(opsRepositoryProvider).createTable(
                organizationId: orgId,
                venueId: venueId,
                label: _tableLabel.text.trim(),
                capacity: 4,
              );
              await _load(venueId);
            }),
            child: const Text('Add table'),
          ),
        ],
        if (canWrite && _guests.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            initialValue: _guests.any((row) => row['id'] == _guestId) ? _guestId : _guests.first['id'] as String,
            items: [for (final row in _guests) DropdownMenuItem(value: row['id'] as String, child: Text(row['display_name'] as String))],
            onChanged: (value) => setState(() => _guestId = value),
            decoration: const InputDecoration(labelText: 'Guest'),
          ),
          TextField(controller: _party, decoration: const InputDecoration(labelText: 'Party size')),
          FilledButton(
            onPressed: _busy ? null : () => _run(() async {
              await ref.read(opsRepositoryProvider).createReservation(
                organizationId: orgId,
                venueId: venueId,
                guestId: _guestId ?? _guests.first['id'] as String,
                partySize: int.parse(_party.text.trim()),
                reservedAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
              );
              await _load(venueId);
            }),
            child: const Text('Book reservation'),
          ),
        ],
        const SizedBox(height: 16),
        for (final row in _board)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${row['guest_name']} · ${row['party_size']}'),
            subtitle: Text(
              '${row['reservation_status']} · ${row['allergies'] ?? 'no allergies'} · ${row['favorite_wine'] ?? 'no favorite wine'}',
            ),
            trailing: canSeatGuest && row['reservation_status'] == 'booked'
                ? TextButton(
                    onPressed: _tables.isEmpty
                        ? null
                        : () => _run(() async {
                            final table = _tables.cast<Map<String, dynamic>>().firstWhere(
                              (item) => item['status'] == 'available' || item['status'] == 'reserved',
                              orElse: () => _tables.first,
                            );
                            final party = row['party_size'] as int;
                            final capacity = table['capacity'] as int;
                            if (!canSeat(
                              reservationStatus: 'booked',
                              tableStatus: table['status'] as String,
                              party: party,
                              capacity: capacity,
                            )) {
                              throw const ValidationFailure('That table cannot take this party.');
                            }
                            await ref.read(opsRepositoryProvider).seat(
                              reservationId: row['reservation_id'] as String,
                              tableId: table['id'] as String,
                            );
                            await _load(venueId);
                          }),
                    child: const Text('Seat'),
                  )
                : canSeatGuest && row['reservation_status'] == 'seated'
                ? TextButton(
                    onPressed: () => _run(() async {
                      await ref.read(opsRepositoryProvider).completeReservation(row['reservation_id'] as String);
                      await _load(venueId);
                    }),
                    child: const Text('Complete'),
                  )
                : null,
          ),
        for (final table in _tables.where((row) => row['status'] == 'dirty'))
          TextButton(
            onPressed: () => _run(() async {
              await ref.read(opsRepositoryProvider).clearTable(table['id'] as String);
              await _load(venueId);
            }),
            child: Text('Clear ${table['label']}'),
          ),
      ],
    );
  }

  Future<void> _load(String venueId) async {
    final repo = ref.read(opsRepositoryProvider);
    final board = await repo.hostBoard(venueId);
    final guests = await repo.guests(venueId);
    final tables = await repo.tables(venueId);
    if (mounted) {
      setState(() {
        _board = board;
        _guests = guests;
        _tables = tables;
      });
    }
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
