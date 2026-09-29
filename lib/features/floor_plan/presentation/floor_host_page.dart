import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/hospitality_design.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/status_banner.dart';
import '../../operations/application/ops_controller.dart';
import '../../wine_inventory/application/cellar_controller.dart';
import '../data/floor_repository.dart';
import '../data/floor_reference.dart';
import '../data/floor_detection.dart';
import '../domain/floor_models.dart';
import 'floor_canvas.dart';
import 'floor_forms.dart';
import 'floor_detection_review.dart';

class FloorExitGuard {
  Future<bool> Function()? check;
  Future<bool> canLeave() async => await check?.call() ?? true;
}

final floorExitGuardProvider = Provider((ref) => FloorExitGuard());

class FloorHostPage extends ConsumerStatefulWidget {
  const FloorHostPage({
    super.key,
    required this.organization,
    required this.venue,
    required this.zone,
  });
  final String organization, venue, zone;
  @override
  ConsumerState<FloorHostPage> createState() => _FloorHostPageState();
}

class _FloorHostPageState extends ConsumerState<FloorHostPage> {
  FloorSnapshot? snapshot;
  FloorRow? draft;
  List<FloorRow> draftTables = [], draftObjects = [];
  String? planId, error, notice, backgroundUrl, progress;
  final selected = <String>{};
  final undo = <FloorRow>[], redo = <FloorRow>[];
  bool busy = false, editing = false, dirty = false, snap = true;
  String partyFilter = 'active', sectionFilter = '';
  ({String id, String action, FloorRow payload})? retry;
  Timer? clock;
  RealtimeChannel? live;
  Timer? refresh;
  late final FloorRepository repository;
  late final FloorExitGuard exitGuard;
  late final Future<bool> Function() exitCheck;
  int generation = 0;
  FloorRepository get repo => repository;
  FloorRow? get plan =>
      draft ?? snapshot?.plans.where((p) => p['id'] == planId).firstOrNull;
  List<FloorRow> get tables => editing
      ? draftTables
      : snapshot?.tables.where((t) => t['plan_id'] == planId).toList() ?? [];
  List<FloorRow> get objects => editing
      ? draftObjects
      : snapshot?.objects.where((o) => o['plan_id'] == planId).toList() ?? [];
  @override
  void initState() {
    super.initState();
    repository = ref.read(floorRepositoryProvider);
    exitGuard = ref.read(floorExitGuardProvider);
    exitCheck = () async =>
        repo.client.auth.currentUser == null ||
        !dirty ||
        await confirm(
          'Leave unsaved floor edits?',
          'Save the layout first, or leave and discard these edits.',
        );
    exitGuard.check = exitCheck;
    unawaited(load());
    clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    live = repo.client.channel('floor-${widget.venue}');
    for (final table in [
      'floor_tables',
      'floor_plans',
      'floor_objects',
      'reservations',
    ]) {
      live!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'venue_id',
          value: widget.venue,
        ),
        callback: (_) {
          refresh?.cancel();
          refresh = Timer(const Duration(milliseconds: 400), () {
            if (mounted && !editing && !busy) unawaited(load());
          });
        },
      );
    }
    live!.subscribe();
  }

  @override
  void dispose() {
    generation++;
    clock?.cancel();
    refresh?.cancel();
    if (identical(exitGuard.check, exitCheck)) exitGuard.check = null;
    if (live != null) unawaited(repo.client.removeChannel(live!));
    super.dispose();
  }

  Future<void> load() async {
    final ticket = ++generation;
    try {
      final data = await repo.snapshot(widget.organization, widget.venue);
      if (!mounted || ticket != generation) return;
      setState(() {
        snapshot = data;
        if (!data.plans.any((p) => p['id'] == planId)) {
          planId = data.plans.firstOrNull?['id'] as String?;
        }
        if (!editing) {
          selected.removeWhere((id) => !data.tables.any((t) => t['id'] == id));
        }
      });
      await image();
    } on AppFailure catch (e) {
      if (mounted && ticket == generation) setState(() => error = e.message);
    }
  }

  Future<void> image() async {
    final path = plan?['background_path'] as String?;
    if (path == null) {
      if (mounted) setState(() => backgroundUrl = null);
      return;
    }
    try {
      final url = await repo.imageUrl(path);
      if (mounted && plan?['background_path'] == path) {
        setState(() => backgroundUrl = url);
      }
    } on AppFailure catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> perform(
    String action,
    FloorRow payload, {
    String? commandId,
  }) async {
    if (busy) return;
    if (retry != null && commandId == null) {
      setState(
        () => error =
            'Retry the pending action or refresh before making another change.',
      );
      return;
    }
    final command = (
      id: commandId ?? const Uuid().v4(),
      action: action,
      payload: Map<String, dynamic>.from(
        jsonDecode(jsonEncode(payload)) as Map,
      ),
    );
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await repo.command(
        widget.organization,
        widget.venue,
        command.id,
        command.action,
        command.payload,
      );
      if (!mounted) return;
      setState(() {
        retry = null;
        if (action == 'save_layout' || action == 'archive_plan') {
          editing = false;
          dirty = false;
          draft = null;
          undo.clear();
          redo.clear();
        }
        notice = 'Saved';
      });
      await load();
    } on AppFailure catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        // Validation failures are definitive; ambiguous transport failures retain their original command ID.
        retry = e is ValidationFailure || e is PermissionFailure
            ? null
            : command;
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;
  FloorRow stateCopy() => Map<String, dynamic>.from(
    jsonDecode(
      jsonEncode({
        'plan': draft,
        'tables': draftTables,
        'objects': draftObjects,
      }),
    ) as Map,
  );
  void checkpoint() {
    undo.add(stateCopy());
    if (undo.length > 40) undo.removeAt(0);
    redo.clear();
  }

  void restore(FloorRow state) {
    setState(() {
      draft = Map<String, dynamic>.from(state['plan'] as Map);
      draftTables = (state['tables'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      draftObjects = (state['objects'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      dirty = true;
    });
    unawaited(image());
  }

  void startEditing() => setState(() {
    draft = Map.of(plan!);
    draftTables = tables.map((t) => Map<String, dynamic>.from(t)).toList();
    draftObjects = objects.map((o) => Map<String, dynamic>.from(o)).toList();
    editing = true;
    dirty = false;
    selected.clear();
    undo.clear();
    redo.clear();
  });
  Future<void> newRoom() async {
    if (editing &&
        dirty &&
        !await confirm(
          'Discard this draft?',
          'Save this room before starting another, or discard your unsaved edits.',
        )) {
      return;
    }
    if (!mounted) return;
    final values = await floorForm(
      context,
      'New room',
      const [
        FloorField('name', 'Room name', required: true, max: 80),
        FloorField(
          'width',
          'Canvas width',
          kind: 'int',
          required: true,
          min: 400,
          max: 4000,
        ),
        FloorField(
          'height',
          'Canvas height',
          kind: 'int',
          required: true,
          min: 300,
          max: 4000,
        ),
      ],
      {'name': 'Dining room', 'width': 1200, 'height': 800},
    );
    if (values == null || !mounted) return;
    setState(() {
      draft = {
        ...values,
        'id': const Uuid().v4(),
        'revision': 0,
        'background_opacity': .45,
        'background_x': 0,
        'background_y': 0,
        'background_width': values['width'],
        'background_height': values['height'],
        'background_angle': 0,
      };
      planId = draft!['id'] as String;
      draftTables = [];
      draftObjects = [];
      backgroundUrl = null;
      editing = true;
      dirty = true;
      selected.clear();
      undo.clear();
      redo.clear();
    });
  }

  void add(String kind, Offset position) {
    if (!editing || busy) return;
    if ((kind == 'chair' ||
                kind == 'wall' ||
                kind == 'door' ||
                kind == 'label') &&
            draftObjects.length >= 600 ||
        draftTables.length >= 200 &&
            !['chair', 'wall', 'door', 'label'].contains(kind)) {
      setState(
        () =>
            error = 'Use at most 200 tables and 600 drawing objects per room.',
      );
      return;
    }
    checkpoint();
    final table = !['chair', 'wall', 'door', 'label'].contains(kind);
    final id = const Uuid().v4();
    final size = table
        ? switch (kind) {
            'round' => const Size(90, 90),
            'booth' => const Size(140, 90),
            'bar' => const Size(200, 60),
            _ => const Size(110, 80),
          }
        : switch (kind) {
            'chair' => const Size(30, 30),
            'wall' => const Size(200, 20),
            'door' => const Size(70, 30),
            _ => const Size(140, 40),
          };
    final pos = clampFloorPosition(
      position,
      size,
      Size(floorNumber(draft!, 'width'), floorNumber(draft!, 'height')),
      snap: snap,
    );
    final row = <String, dynamic>{
      'id': id,
      'x': pos.dx,
      'y': pos.dy,
      'width': size.width,
      'height': size.height,
      'angle': 0,
    };
    if (table) {
      var n = 1;
      while ((snapshot?.tables ?? [])
          .followedBy(draftTables)
          .any((t) => t['label'].toString().toLowerCase() == 't$n')) {
        n++;
      }
      row.addAll({
        'label': 'T$n',
        'capacity': 4,
        'shape': kind,
        'status': 'available',
        'revision': 0,
        'section': '',
        'accessible': false,
        'notes': '',
        'plan_id': planId,
      });
    } else {
      row.addAll({
        'kind': kind,
        'label': kind == 'label' ? 'Section' : '',
        'table_id':
            kind == 'chair' &&
                selected.length == 1 &&
                draftTables.any((t) => t['id'] == selected.first)
            ? selected.first
            : null,
      });
    }
    setState(() {
      (table ? draftTables : draftObjects).add(row);
      selected
        ..clear()
        ..add(id);
      dirty = true;
    });
  }

  void move(String id, Offset target) {
    if (!editing || busy) return;
    final row = draftTables
        .followedBy(draftObjects)
        .where((r) => r['id'] == id)
        .firstOrNull;
    if (row == null) return;
    final pos = clampFloorPosition(
      target,
      Size(floorNumber(row, 'width'), floorNumber(row, 'height')),
      Size(floorNumber(draft!, 'width'), floorNumber(draft!, 'height')),
      snap: false,
    );
    final delta = pos - Offset(floorNumber(row, 'x'), floorNumber(row, 'y'));
    setState(() {
      row['x'] = pos.dx;
      row['y'] = pos.dy;
      for (final chair in draftObjects.where((c) => c['table_id'] == id)) {
        final next = clampFloorPosition(
          Offset(floorNumber(chair, 'x'), floorNumber(chair, 'y')) + delta,
          Size(floorNumber(chair, 'width'), floorNumber(chair, 'height')),
          Size(floorNumber(draft!, 'width'), floorNumber(draft!, 'height')),
          snap: false,
        );
        chair['x'] = next.dx;
        chair['y'] = next.dy;
      }
      dirty = true;
    });
  }

  void finishMove(String id) {
    if (!snap) return;
    final row = draftTables
        .followedBy(draftObjects)
        .where((r) => r['id'] == id)
        .firstOrNull;
    if (row != null) {
      move(
        id,
        clampFloorPosition(
          Offset(floorNumber(row, 'x'), floorNumber(row, 'y')),
          Size(floorNumber(row, 'width'), floorNumber(row, 'height')),
          Size(floorNumber(draft!, 'width'), floorNumber(draft!, 'height')),
        ),
      );
    }
  }

  Future<void> editSelected() async {
    if (selected.length != 1) return;
    final row = draftTables
        .followedBy(draftObjects)
        .firstWhere((r) => r['id'] == selected.first);
    final isTable = row.containsKey('capacity');
    final values = await floorForm(
      context,
      isTable ? 'Table details' : 'Drawing object',
      [
        FloorField(
          'label',
          isTable ? 'Table label' : 'Label',
          required: isTable,
          max: 80,
        ),
        if (isTable) ...[
          const FloorField(
            'capacity',
            'Seat capacity',
            kind: 'int',
            required: true,
            min: 1,
            max: 20,
          ),
          const FloorField(
            'shape',
            'Shape',
            kind: 'choice',
            required: true,
            choices: {
              'rectangle': 'Rectangle',
              'round': 'Round',
              'booth': 'Booth',
              'bar': 'Bar',
            },
          ),
          const FloorField('section', 'Section', max: 80),
          FloorField(
            'server_user_id',
            'Assigned server',
            kind: 'choice',
            choices: {
              for (final s in snapshot!.servers)
                s['id'] as String: s['name'] as String,
            },
          ),
          const FloorField('accessible', 'Accessible seating', kind: 'bool'),
          const FloorField('notes', 'Table notes', max: 1000, lines: 3),
        ] else if (row['kind'] == 'chair')
          FloorField(
            'table_id',
            'Attach chair to table',
            kind: 'choice',
            choices: {
              for (final t in draftTables)
                t['id'] as String: t['label'] as String,
            },
          ),
        const FloorField(
          'x',
          'Horizontal position',
          kind: 'number',
          required: true,
          min: 0,
          max: 4000,
        ),
        const FloorField(
          'y',
          'Vertical position',
          kind: 'number',
          required: true,
          min: 0,
          max: 4000,
        ),
        FloorField(
          'width',
          'Width',
          kind: 'number',
          required: true,
          min: isTable ? 24 : 12,
          max: 800,
        ),
        FloorField(
          'height',
          'Height',
          kind: 'number',
          required: true,
          min: isTable ? 24 : 12,
          max: 800,
        ),
        const FloorField(
          'angle',
          'Rotation in degrees',
          kind: 'number',
          required: true,
          min: -360,
          max: 360,
        ),
      ],
      row,
    );
    if (values == null || !mounted) return;
    if (floorNumber(values, 'x') + floorNumber(values, 'width') >
            floorNumber(draft!, 'width') ||
        floorNumber(values, 'y') + floorNumber(values, 'height') >
            floorNumber(draft!, 'height')) {
      setState(() => error = 'Keep this item inside the room.');
      return;
    }
    if (isTable &&
        draftTables.any(
          (t) =>
              t['id'] != row['id'] &&
              t['label'].toString().toLowerCase() ==
                  values['label'].toString().toLowerCase(),
        )) {
      setState(() => error = 'Use a unique table label.');
      return;
    }
    checkpoint();
    final target = Offset(floorNumber(values, 'x'), floorNumber(values, 'y'));
    move(row['id'] as String, target);
    setState(() {
      row.addAll(values);
      dirty = true;
    });
  }

  Future<void> upload() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'pdf'],
      );
      if (file == null || !mounted) return;
      setState(() => busy = true);
      final raster = await readFloorReference(
        file.name,
        await file.readAsBytes(),
        (count) async {
          final choice = await floorForm(
            context,
            'Choose diagram page',
            [
              FloorField(
                'page',
                'Page number',
                kind: 'int',
                required: true,
                min: 1,
                max: count.toDouble(),
              ),
            ],
            {'page': 1},
          );
          return choice?['page'] as int?;
        },
      );
      if (raster == null || !mounted) return;
      final path =
          '${widget.organization}/${widget.venue}/$planId/${const Uuid().v4()}.png';
      await repo.upload(path, raster.bytes);
      if (!mounted) return;
      checkpoint();
      setState(() {
        draft!['background_path'] = path;
        draft!['background_x'] = 0;
        draft!['background_y'] = 0;
        draft!['background_angle'] = 0;
        final fit = math.min(
          floorNumber(draft!, 'width') / raster.width,
          floorNumber(draft!, 'height') / raster.height,
        );
        draft!['background_width'] = raster.width * fit;
        draft!['background_height'] = raster.height * fit;
        dirty = true;
      });
      await image();
      await detectTables(raster.bytes);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is AppFailure
              ? e.message
              : e is FormatException
              ? e.message
              : 'This picture or diagram could not be loaded.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> detectTables([Uint8List? bytes]) async {
    if (!editing || draft == null || backgroundUrl == null) return;
    final alreadyBusy = busy;
    setState(() {
      busy = true;
      progress = 'Looking for tables and table numbers…';
    });
    try {
      final png =
          bytes ??
          await repo.referenceBytes(draft!['background_path'] as String);
      final suggestions = await suggestFloorTables(png);
      if (!mounted) return;
      setState(() => progress = null);
      if (suggestions.isEmpty) {
        setState(
          () => notice = 'No clear tables were detected. Keep the image as a reference and add tables from the palette.',
        );
        return;
      }
      final accepted = await reviewFloorSuggestions(
        context,
        suggestions,
        backgroundUrl!,
        (snapshot?.tables ?? [])
            .followedBy(draftTables)
            .map((t) => t['label'].toString())
            .toSet(),
      );
      if (accepted == null || accepted.isEmpty || !mounted) return;
      if (draftTables.length + accepted.length > 200) {
        setState(
          () => error =
              'Use at most 200 tables per room. Select fewer suggestions.',
        );
        return;
      }
      checkpoint();
      final room = Size(
        floorNumber(draft!, 'width'),
        floorNumber(draft!, 'height'),
      );
      final bw = floorNumber(draft!, 'background_width'),
          bh = floorNumber(draft!, 'background_height');
      final radians = floorNumber(draft!, 'background_angle') * math.pi / 180;
      for (final entry in accepted) {
        final candidate = entry.suggestion;
        final size = Size(
          (candidate.width * bw).clamp(24.0, math.min(800.0, room.width)),
          (candidate.height * bh).clamp(24.0, math.min(800.0, room.height)),
        );
        final cx = (candidate.x + candidate.width / 2) * bw - bw / 2;
        final cy = (candidate.y + candidate.height / 2) * bh - bh / 2;
        final center = Offset(
          floorNumber(draft!, 'background_x') +
              bw / 2 +
              cx * math.cos(radians) -
              cy * math.sin(radians),
          floorNumber(draft!, 'background_y') +
              bh / 2 +
              cx * math.sin(radians) +
              cy * math.cos(radians),
        );
        final position = clampFloorPosition(
          center - Offset(size.width / 2, size.height / 2),
          size,
          room,
          snap: false,
        );
        draftTables.add({
          'id': const Uuid().v4(),
          'plan_id': planId,
          'label': entry.label,
          'capacity': entry.capacity,
          'shape': candidate.shape,
          'x': position.dx,
          'y': position.dy,
          'width': size.width,
          'height': size.height,
          'angle': floorNumber(draft!, 'background_angle'),
          'status': 'available',
          'revision': 0,
          'section': '',
          'accessible': false,
          'notes': '',
        });
      }
      setState(() {
        dirty = true;
        notice =
            'Added ${accepted.length} reviewed tables. Adjust them on the floor, then save the layout.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => notice = 'Automatic detection could not finish. The reference image is available for manual tracing.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = alreadyBusy;
          progress = null;
        });
      }
    }
  }

  Future<void> adjustBackground() async {
    final values = await floorForm(context, 'Adjust reference image', const [
      FloorField(
        'background_x',
        'Horizontal position',
        kind: 'number',
        required: true,
        min: -4000,
        max: 4000,
      ),
      FloorField(
        'background_y',
        'Vertical position',
        kind: 'number',
        required: true,
        min: -4000,
        max: 4000,
      ),
      FloorField(
        'background_width',
        'Width',
        kind: 'number',
        required: true,
        min: 10,
        max: 8000,
      ),
      FloorField(
        'background_height',
        'Height',
        kind: 'number',
        required: true,
        min: 10,
        max: 8000,
      ),
      FloorField(
        'background_angle',
        'Rotation in degrees',
        kind: 'number',
        required: true,
        min: -360,
        max: 360,
      ),
      FloorField(
        'background_opacity',
        'Opacity (0 to 1)',
        kind: 'number',
        required: true,
        min: 0,
        max: 1,
      ),
    ], draft!);
    if (values != null && mounted) {
      checkpoint();
      setState(() {
        draft!.addAll(values);
        dirty = true;
      });
    }
  }

  Future<void> chairs() async {
    final table = draftTables
        .where((t) => selected.contains(t['id']))
        .firstOrNull;
    if (table == null) return;
    final id = table['id'];
    final count = table['capacity'] as int;
    if (draftObjects.length + count > 600) {
      setState(() => error = 'Use at most 600 drawing objects per room.');
      return;
    }
    checkpoint();
    setState(() {
      draftObjects.removeWhere(
        (o) => o['kind'] == 'chair' && o['table_id'] == id,
      );
      for (var i = 0; i < count; i++) {
        final angle = 2 * math.pi * i / count;
        final pos = clampFloorPosition(
          Offset(
            floorNumber(table, 'x') +
                floorNumber(table, 'width') / 2 +
                math.cos(angle) * (floorNumber(table, 'width') / 2 + 22) -
                15,
            floorNumber(table, 'y') +
                floorNumber(table, 'height') / 2 +
                math.sin(angle) * (floorNumber(table, 'height') / 2 + 22) -
                15,
          ),
          const Size(30, 30),
          Size(floorNumber(draft!, 'width'), floorNumber(draft!, 'height')),
          snap: false,
        );
        draftObjects.add({
          'id': const Uuid().v4(),
          'kind': 'chair',
          'table_id': id,
          'x': pos.dx,
          'y': pos.dy,
          'width': 30,
          'height': 30,
          'angle': angle * 180 / math.pi,
          'label': '',
        });
      }
      dirty = true;
    });
  }

  Future<void> guestProfile() async {
    final wines = ref.read(cellarControllerProvider).value?.wines ?? [];
    final values = await floorForm(context, 'New guest profile', [
      const FloorField('name', 'Guest name', required: true, max: 80),
      const FloorField('allergies', 'Allergies', max: 1000),
      const FloorField('seating', 'Seating preference', max: 1000),
      const FloorField('vip', 'VIP', kind: 'bool'),
      if (wines.isNotEmpty)
        FloorField(
          'wine',
          'Favorite wine',
          kind: 'choice',
          choices: {for (final w in wines) w.itemId: w.label},
        ),
    ], {});
    if (values == null || !mounted) return;
    setState(() => busy = true);
    try {
      final ops = ref.read(opsRepositoryProvider);
      final id = await ops.createGuest(
        organizationId: widget.organization,
        venueId: widget.venue,
        name: values['name'] as String,
        allergies: values['allergies'] as String,
        seating: values['seating'] as String,
        vip: values['vip'] as bool,
      );
      if (values['wine'] != null) {
        await ops.setFavorite(guestId: id, itemId: values['wine'] as String);
      }
      await load();
    } on AppFailure catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> partyForm(bool walkIn) async {
    final values = await floorForm(
      context,
      walkIn ? 'Add walk-in' : 'Book reservation',
      [
        FloorField(
          'guest_id',
          'Existing guest',
          kind: 'choice',
          choices: {
            for (final g in snapshot!.guests)
              g['id'] as String: g['name'] as String,
          },
        ),
        if (snapshot!.can('guest'))
          const FloorField('guest_name', 'New guest name', max: 80),
        const FloorField(
          'party_size',
          'Party size',
          kind: 'int',
          required: true,
          min: 1,
          max: 80,
        ),
        if (!walkIn)
          const FloorField(
            'reserved_at',
            'Reservation time',
            kind: 'instant',
            required: true,
          ),
        const FloorField(
          'duration_minutes',
          'Expected dining minutes',
          kind: 'int',
          required: true,
          min: 15,
          max: 480,
        ),
        if (walkIn)
          const FloorField(
            'quoted_wait_minutes',
            'Quoted wait minutes',
            kind: 'int',
            min: 0,
            max: 480,
          ),
        const FloorField('preferred_section', 'Preferred section', max: 80),
        const FloorField(
          'accessibility_requested',
          'Accessible seating required',
          kind: 'bool',
        ),
        const FloorField('high_chair', 'High chair needed', kind: 'bool'),
        const FloorField('notes', 'Party notes', max: 2000, lines: 3),
        if (snapshot!.can('guest')) ...const [
          FloorField('allergies', 'New guest allergies', max: 1000),
          FloorField(
            'seating_preference',
            'New guest seating preference',
            max: 1000,
          ),
        ],
        FloorField(
          'server_user_id',
          'Assigned server',
          kind: 'choice',
          choices: {
            for (final s in snapshot!.servers)
              s['id'] as String: s['name'] as String,
          },
        ),
      ],
      {
        'party_size': 2,
        'duration_minutes': 90,
        'reserved_at': DateTime.now()
            .toUtc()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      },
      zone: widget.zone,
    );
    if (values == null || !mounted) return;
    if (values['guest_id'] == null &&
        (values['guest_name'] as String? ?? '').trim().length < 2) {
      setState(
        () => error = 'Choose an existing guest or enter a new guest name of at least two characters.',
      );
      return;
    }
    await perform('create_party', {...values, 'walk_in': walkIn});
  }

  FloorRow revisions(List<FloorRow> unit) => {
    for (final t in unit) t['id'] as String: t['revision'],
  };
  List<FloorRow> get selectedUnit {
    final rows = <String, FloorRow>{};
    for (final id in selected) {
      for (final t in snapshot!.seatingUnit(id)) {
        rows[t['id'] as String] = t;
      }
    }
    return rows.values.toList();
  }

  Future<void> tableAction(String action, {String? status}) async {
    final unit = selectedUnit;
    if (unit.isEmpty) return;
    final payload = <String, dynamic>{
      'table_ids': unit.map((t) => t['id']).toList(),
      'revisions': revisions(unit),
      'status': ?status,
    };
    if (action == 'combine') {
      final values = await floorForm(
        context,
        'Combine tables',
        const [
          FloorField('label', 'Combination name', required: true, max: 80),
        ],
        {'label': unit.map((t) => t['label']).join(' + ')},
      );
      if (values == null || !mounted) return;
      payload['label'] = values['label'];
    }
    if (action == 'table_server') {
      final values = await floorForm(
        context,
        'Assign server',
        [
          FloorField(
            'server_user_id',
            'Server',
            kind: 'choice',
            choices: {
              for (final s in snapshot!.servers)
                s['id'] as String: s['name'] as String,
            },
          ),
        ],
        {'server_user_id': unit.first['server_user_id']},
      );
      if (values == null || !mounted) return;
      payload['server_user_id'] = values['server_user_id'];
    }
    await perform(action, payload);
  }

  Future<void> placeParty(FloorRow party, String action) async {
    final candidates = eligibleSeatingUnits(
      snapshot!,
      party,
      forAssignment: action == 'assign',
    );
    if (candidates.isEmpty) {
      setState(
        () => error = 'No clean table or combination has enough seats and an open time window. Configure or clear tables first.',
      );
      return;
    }
    final values = await floorForm(
      context,
      action == 'assign'
          ? 'Assign tables'
          : action == 'transfer'
          ? 'Move seated party'
          : 'Seat party',
      [
        FloorField(
          'table',
          'Table or combination',
          kind: 'choice',
          required: true,
          choices: {
            for (final t in candidates)
              t['id'] as String:
                  '${snapshot!.seatingUnit(t['id'] as String).map((x) => x['label']).join(' + ')} · ${snapshot!.seatingUnit(t['id'] as String).fold<int>(0, (n, x) => n + (x['capacity'] as int))} seats',
          },
        ),
        FloorField(
          'server_user_id',
          'Assigned server',
          kind: 'choice',
          choices: {
            for (final s in snapshot!.servers)
              s['id'] as String: s['name'] as String,
          },
        ),
      ],
      {
        'table': candidates.any((t) => selected.contains(t['id']))
            ? candidates.firstWhere((t) => selected.contains(t['id']))['id']
            : candidates.first['id'],
        'server_user_id': party['server_user_id'],
      },
    );
    if (values == null || !mounted) return;
    await perform(action, {
      'id': party['id'],
      'revision': party['revision'],
      'table_ids': [values['table']],
      'server_user_id': values['server_user_id'],
    });
  }

  Future<void> editParty(FloorRow party) async {
    final values = await floorForm(context, 'Party service details', [
      const FloorField(
        'quoted_wait_minutes',
        'Quoted wait minutes',
        kind: 'int',
        min: 0,
        max: 480,
      ),
      const FloorField('notes', 'Party notes', max: 2000, lines: 3),
      FloorField(
        'server_user_id',
        'Assigned server',
        kind: 'choice',
        choices: {
          for (final s in snapshot!.servers)
            s['id'] as String: s['name'] as String,
        },
      ),
    ], party);
    if (values != null && mounted) {
      await perform('edit_party', {
        'id': party['id'],
        'revision': party['revision'],
        'quoted_wait_minutes': values['quoted_wait_minutes'],
        'notes': values['notes'],
        'server_user_id': values['server_user_id'],
      });
    }
  }

  String venueTime(String instant) => DateFormat('MMM d, HH:mm').format(
    tz.TZDateTime.from(DateTime.parse(instant), tz.getLocation(widget.zone)),
  );
  Widget partyCard(FloorRow party) {
    final status = party['status'] as String;
    final seated = party['seated_at'] as String?,
        arrived = party['arrived_at'] as String?;
    final since = seated ?? arrived;
    final minutes = since == null
        ? null
        : DateTime.now()
              .toUtc()
              .difference(DateTime.parse(since))
              .inMinutes
              .clamp(0, 100000);
    final tableLabels = snapshot!.tables
        .where((t) => (party['table_ids'] as List? ?? []).contains(t['id']))
        .map((t) => t['label'])
        .join(' + ');
    final server = snapshot!.servers
        .where((s) => s['id'] == party['server_user_id'])
        .firstOrNull?['name'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${party['guest_name']} · ${party['party_size']} guests',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${status == 'waiting' ? 'Walk-in' : status} · ${venueTime(party['reserved_at'] as String)}${tableLabels.isEmpty ? '' : ' · $tableLabels'}',
            ),
            if (minutes != null)
              Text(
                '${status == 'seated' ? 'Seated' : 'Waiting'} $minutes min${party['quoted_wait_minutes'] == null ? '' : ' · quoted ${party['quoted_wait_minutes']} min'}${status == 'seated' ? ' · expected ${party['duration_minutes']} min' : ''}',
                style: TextStyle(
                  color:
                      status == 'seated' &&
                          minutes > (party['duration_minutes'] as int)
                      ? Colors.deepOrange
                      : null,
                ),
              ),
            if (server != null) Text('Server: $server'),
            if (party['allergies'] != null)
              Text(
                'Allergies: ${party['allergies']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xffa6473b),
                ),
              ),
            if ((party['seating_preference'] as String? ?? '').isNotEmpty)
              Text('Preference: ${party['seating_preference']}'),
            if ((party['preferred_section'] as String? ?? '').isNotEmpty)
              Text('Section: ${party['preferred_section']}'),
            if (party['accessibility_requested'] == true ||
                party['high_chair'] == true ||
                party['vip'] == true)
              Text(
                [
                  if (party['accessibility_requested'] == true)
                    'Accessible seating',
                  if (party['high_chair'] == true) 'High chair',
                  if (party['vip'] == true) 'VIP',
                ].join(' · '),
              ),
            if ((party['notes'] as String? ?? '').isNotEmpty)
              Text(party['notes'] as String),
            Wrap(
              spacing: 6,
              children: [
                if (snapshot!.can('seat') &&
                    ['booked', 'waiting'].contains(status)) ...[
                  TextButton(
                    onPressed: busy ? null : () => placeParty(party, 'seat'),
                    child: const Text('Seat'),
                  ),
                  if (arrived == null)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => perform('arrive', {
                              'id': party['id'],
                              'revision': party['revision'],
                            }),
                      child: const Text('Arrived'),
                    ),
                ],
                if (snapshot!.can('book') &&
                    ['booked', 'waiting'].contains(status)) ...[
                  TextButton(
                    onPressed: busy ? null : () => placeParty(party, 'assign'),
                    child: const Text('Assign table'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (await confirm(
                              'Cancel this party?',
                              'Release its assigned tables and cancel the booking.',
                            )) {
                              await perform('cancel', {
                                'id': party['id'],
                                'revision': party['revision'],
                              });
                            }
                          },
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => perform('no_show', {
                            'id': party['id'],
                            'revision': party['revision'],
                          }),
                    child: const Text('No-show'),
                  ),
                ],
                if (snapshot!.can('seat') && status == 'seated') ...[
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => placeParty(party, 'transfer'),
                    child: const Text('Move party'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (await confirm(
                              'Complete service?',
                              'The party leaves and all its tables become dirty.',
                            )) {
                              await perform('complete', {
                                'id': party['id'],
                                'revision': party['revision'],
                              });
                            }
                          },
                    child: const Text('Complete'),
                  ),
                ],
                if (snapshot!.can('book'))
                  TextButton(
                    onPressed: busy ? null : () => editParty(party),
                    child: const Text('Details'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget partyBook() {
    final parties = snapshot!.parties
        .where((p) => partyFilter == 'active' || p['status'] == partyFilter)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reservations & waitlist',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          children: [
            for (final entry in {
              'active': 'All active',
              'booked': 'Reservations',
              'waiting': 'Walk-ins',
              'seated': 'Seated',
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: partyFilter == entry.key,
                onSelected: (_) => setState(() => partyFilter = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (parties.isEmpty)
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'No parties in this view. Add a reservation or walk-in to start seating.',
            ),
          ),
        for (final p in parties) partyCard(p),
      ],
    );
  }

  Widget editor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in {
              'rectangle': 'Table',
              'round': 'Round table',
              'booth': 'Booth',
              'bar': 'Bar',
              'chair': 'Chair',
              'wall': 'Wall',
              'door': 'Door',
              'label': 'Section label',
            }.entries)
              Draggable<String>(
                data: k.key,
                feedback: Material(
                  color: Colors.transparent,
                  child: Chip(
                    label: Text(k.value),
                    avatar: const Icon(Icons.open_with),
                  ),
                ),
                child: OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => add(
                          k.key,
                          Offset(
                            floorNumber(draft!, 'width') / 2 - 55,
                            floorNumber(draft!, 'height') / 2 - 40,
                          ),
                        ),
                  icon: Icon(k.key == 'chair' ? Icons.chair_alt : Icons.add),
                  label: Text(k.value),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Drag a palette item onto the room, or tap to add it. Drag furniture to move it; select an item to resize, rotate or label it. Pinch to zoom.',
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: busy ? null : upload,
              icon: const Icon(Icons.upload_file),
              label: const Text('Picture / PDF'),
            ),
            if (draft!['background_path'] != null) ...[
              TextButton.icon(
                onPressed: busy ? null : () => detectTables(),
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Detect tables'),
              ),
              TextButton(
                onPressed: busy ? null : adjustBackground,
                child: const Text('Adjust reference'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () {
                        checkpoint();
                        setState(() {
                          draft!['background_path'] = null;
                          backgroundUrl = null;
                          dirty = true;
                        });
                      },
                child: const Text('Remove reference'),
              ),
            ],
            FilterChip(
              label: const Text('Snap to grid'),
              selected: snap,
              onSelected: (v) => setState(() => snap = v),
            ),
            IconButton(
              tooltip: 'Undo',
              onPressed: busy || undo.isEmpty
                  ? null
                  : () {
                      redo.add(stateCopy());
                      restore(undo.removeLast());
                    },
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: 'Redo',
              onPressed: busy || redo.isEmpty
                  ? null
                  : () {
                      undo.add(stateCopy());
                      restore(redo.removeLast());
                    },
              icon: const Icon(Icons.redo),
            ),
          ],
        ),
        if (selected.length == 1)
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: busy ? null : editSelected,
                child: const Text('Edit selected'),
              ),
              if (draftTables.any((t) => selected.contains(t['id'])))
                OutlinedButton(
                  onPressed: busy ? null : chairs,
                  child: const Text('Arrange chairs'),
                ),
              TextButton(
                onPressed: busy
                    ? null
                    : () {
                        checkpoint();
                        setState(() {
                          draftTables.removeWhere(
                            (t) => selected.contains(t['id']),
                          );
                          draftObjects.removeWhere(
                            (o) =>
                                selected.contains(o['id']) ||
                                selected.contains(o['table_id']),
                          );
                          selected.clear();
                          dirty = true;
                        });
                      },
                child: const Text('Remove selected'),
              ),
            ],
          ),
      ],
    );
  }

  Widget serviceSelection() {
    final unit = selectedUnit;
    if (unit.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Tap tables to view details, mark cleaning status, assign a server, or combine them.',
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${unit.map((t) => t['label']).join(' + ')} · ${unit.fold<int>(0, (n, t) => n + (t['capacity'] as int))} seats',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final t in unit)
              Text(
                '${t['label']} · ${floorStatuses[t['status']]}${(t['section'] as String).isEmpty ? '' : ' · ${t['section']}'}${t['accessible'] == true ? ' · accessible' : ''}${(t['notes'] as String).isEmpty ? '' : ' · ${t['notes']}'}',
              ),
            if (snapshot!.can('seat')) ...[
              Wrap(
                spacing: 6,
                children: [
                  for (final entry in floorStatuses.entries.where(
                    (e) => e.key != 'seated',
                  ))
                    TextButton(
                      onPressed: busy
                          ? null
                          : () =>
                                tableAction('table_status', status: entry.key),
                      child: Text(entry.value),
                    ),
                ],
              ),
              TextButton.icon(
                onPressed: busy ? null : () => tableAction('table_server'),
                icon: const Icon(Icons.person_outline),
                label: const Text('Assign server'),
              ),
            ],
            if (snapshot!.can('design'))
              Wrap(
                spacing: 8,
                children: [
                  if (unit.length >= 2 &&
                      unit.every((t) => t['group_id'] == null))
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => tableAction('combine'),
                      icon: const Icon(Icons.link),
                      label: const Text('Combine'),
                    ),
                  if (unit.any((t) => t['group_id'] != null))
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => tableAction('uncombine'),
                      icon: const Icon(Icons.link_off),
                      label: const Text('Separate'),
                    ),
                ],
              ),
            TextButton(
              onPressed: () => setState(selected.clear),
              child: const Text('Clear selection'),
            ),
          ],
        ),
      ),
    );
  }

  Widget floorPanel() {
    final current = plan;
    if (current == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.grid_view_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                'Your floor starts blank',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a room, place tables and chairs, or upload a picture or diagram and trace it. No sample layout is added.',
              ),
              if (snapshot!.can('design'))
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: FilledButton(
                    onPressed: busy ? null : newRoom,
                    child: const Text('Create room'),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    final labels = <String, String>{
      for (final p in snapshot!.parties.where((p) => p['status'] == 'seated'))
        for (final id in p['table_ids'] as List? ?? [])
          id as String: '${p['guest_name']} · ${p['party_size']}',
    };
    final viewTables = tables
        .where((t) => sectionFilter.isEmpty || t['section'] == sectionFilter)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (editing)
          editor()
        else
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final entry in floorStatuses.entries)
                Chip(
                  avatar: Icon(
                    Icons.circle,
                    size: 12,
                    color: floorStatusColor(entry.key),
                  ),
                  label: Text(
                    '${entry.value} ${tables.where((t) => t['status'] == entry.key).length}',
                  ),
                ),
            ],
          ),
        const SizedBox(height: 12),
        SizedBox(
          height: 500,
          child: FloorCanvas(
            key: ValueKey('$planId/$editing'),
            plan: current,
            tables: viewTables,
            objects: objects,
            selected: selected,
            editing: editing && !busy,
            backgroundUrl: backgroundUrl,
            partyLabels: labels,
            onMove: move,
            onMoveStart: checkpoint,
            onMoveEnd: finishMove,
            onDrop: add,
            onSelect: (id) => setState(() {
              if (editing) {
                selected
                  ..clear()
                  ..add(id);
              } else {
                final ids = snapshot!
                    .seatingUnit(id)
                    .map((t) => t['id'] as String)
                    .toList();
                if (ids.every(selected.contains)) {
                  selected.removeAll(ids);
                } else {
                  selected.addAll(ids);
                }
              }
            }),
          ),
        ),
        if (editing) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () => perform('save_layout', {
                        ...draft!,
                        'tables': draftTables,
                        'objects': draftObjects,
                      }),
                icon: const Icon(Icons.save_outlined),
                label: Text(busy ? 'Saving…' : 'Save layout'),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!dirty ||
                            await confirm(
                              'Discard layout edits?',
                              'Your last saved room will be restored.',
                            )) {
                          if (!mounted) return;
                          setState(() {
                            editing = false;
                            dirty = false;
                            draft = null;
                            selected.clear();
                          });
                          await load();
                        }
                      },
                child: const Text('Discard'),
              ),
            ],
          ),
          if (dirty) const Text('Unsaved layout edits'),
          if ((snapshot!.tables.where((t) => t['plan_id'] == null)).isNotEmpty)
            ExpansionTile(
              title: const Text('Unplaced imported tables'),
              children: [
                for (final t in snapshot!.tables.where(
                  (t) =>
                      t['plan_id'] == null &&
                      !draftTables.any((d) => d['id'] == t['id']),
                ))
                  ListTile(
                    title: Text('${t['label']} · ${t['capacity']} seats'),
                    trailing: TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              checkpoint();
                              setState(() {
                                draftTables.add({
                                  ...t,
                                  'plan_id': planId,
                                  'x': 80.0,
                                  'y': 80.0,
                                });
                                dirty = true;
                              });
                            },
                      child: const Text('Place in room'),
                    ),
                  ),
              ],
            ),
        ] else
          serviceSelection(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (snapshot == null) {
      return Center(
        child: error == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!),
                  TextButton(onPressed: load, child: const Text('Retry')),
                ],
              ),
      );
    }
    final sections = tables
        .map((t) => t['section'] as String)
        .where((s) => s.isNotEmpty)
        .toSet();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        WorkspaceHeading(
          title: 'Host & floor',
          subtitle: 'A warm welcome, a perfect place. · ${widget.zone}',
          icon: Icons.event_seat_outlined,
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: StatusBanner(message: error!),
          ),
        if (notice != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(notice!)),
        if (progress != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(progress!),
          ),
        if (retry != null)
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: busy
                    ? null
                    : () => perform(
                        retry!.action,
                        retry!.payload,
                        commandId: retry!.id,
                      ),
                child: const Text('Retry same action'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => retry = null);
                        await load();
                      },
                child: const Text('Refresh before deciding'),
              ),
            ],
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (snapshot!.can('book') && !editing) ...[
              FilledButton.icon(
                onPressed: busy ? null : () => partyForm(true),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Walk-in'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : () => partyForm(false),
                icon: const Icon(Icons.event_available),
                label: const Text('Reservation'),
              ),
            ],
            if (snapshot!.can('guest') && !editing)
              TextButton(
                onPressed: busy ? null : guestProfile,
                child: const Text('Guest profile'),
              ),
            if (snapshot!.can('design')) ...[
              if (!editing && plan != null)
                OutlinedButton.icon(
                  onPressed: busy ? null : startEditing,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit floor'),
                ),
              TextButton(
                onPressed: busy ? null : newRoom,
                child: const Text('New room'),
              ),
              if (editing)
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final values = await floorForm(
                            context,
                            'Room settings',
                            const [
                              FloorField(
                                'name',
                                'Room name',
                                required: true,
                                max: 80,
                              ),
                              FloorField(
                                'width',
                                'Width',
                                kind: 'int',
                                required: true,
                                min: 400,
                                max: 4000,
                              ),
                              FloorField(
                                'height',
                                'Height',
                                kind: 'int',
                                required: true,
                                min: 300,
                                max: 4000,
                              ),
                            ],
                            draft!,
                          );
                          if (values != null && mounted) {
                            checkpoint();
                            setState(() {
                              draft!.addAll(values);
                              dirty = true;
                            });
                          }
                        },
                  child: const Text('Room settings'),
                ),
            ],
            TextButton.icon(
              onPressed: busy || editing ? null : load,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
        if (!editing && snapshot!.plans.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final p in snapshot!.plans)
                  ChoiceChip(
                    label: Text(p['name'] as String),
                    selected: planId == p['id'],
                    onSelected: (_) {
                      setState(() {
                        planId = p['id'] as String;
                        selected.clear();
                        sectionFilter = '';
                      });
                      unawaited(image());
                    },
                  ),
              ],
            ),
          ),
        if (!editing && sections.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('All sections'),
                  selected: sectionFilter.isEmpty,
                  onSelected: (_) => setState(() => sectionFilter = ''),
                ),
                for (final s in sections)
                  ChoiceChip(
                    label: Text(s),
                    selected: sectionFilter == s,
                    onSelected: (_) => setState(() => sectionFilter = s),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (c, box) => box.maxWidth >= 1050 && !editing
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: floorPanel()),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: partyBook()),
                  ],
                )
              : Column(
                  children: [
                    floorPanel(),
                    if (!editing) ...[const SizedBox(height: 24), partyBook()],
                  ],
                ),
        ),
        if (!editing && snapshot!.can('design') && plan != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (await confirm(
                        'Remove this room?',
                        'This hides the room and its tables. Rooms with active parties or assignments cannot be removed.',
                      )) {
                        await perform('archive_plan', {
                          'id': planId,
                          'revision': plan!['revision'],
                        });
                      }
                    },
              child: const Text('Remove room'),
            ),
          ),
      ],
    );
  }
}
