import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/floor_models.dart';

class FloorCanvas extends StatefulWidget {
  const FloorCanvas({
    super.key,
    required this.plan,
    required this.tables,
    required this.objects,
    required this.selected,
    required this.editing,
    required this.onSelect,
    required this.onMove,
    required this.onMoveStart,
    required this.onMoveEnd,
    required this.onDrop,
    this.backgroundUrl,
    this.partyLabels = const {},
  });
  final FloorRow plan;
  final List<FloorRow> tables, objects;
  final Set<String> selected;
  final bool editing;
  final String? backgroundUrl;
  final Map<String, String> partyLabels;
  final void Function(String id) onSelect;
  final void Function(String id, Offset position) onMove;
  final VoidCallback onMoveStart;
  final void Function(String id) onMoveEnd;
  final void Function(String kind, Offset position) onDrop;
  @override
  State<FloorCanvas> createState() => _FloorCanvasState();
}

class _FloorCanvasState extends State<FloorCanvas> {
  final camera = TransformationController();
  final viewportKey = GlobalKey();
  String? fitted;
  Offset? dragOffset;
  @override
  void dispose() {
    camera.dispose();
    super.dispose();
  }

  Size get room => Size(
    floorNumber(widget.plan, 'width', 1200),
    floorNumber(widget.plan, 'height', 800),
  );
  Offset scene(Offset global) => camera.toScene(
    (viewportKey.currentContext!.findRenderObject() as RenderBox).globalToLocal(
      global,
    ),
  );
  void startDrag(FloorRow row, DragStartDetails details) {
    dragOffset =
        scene(details.globalPosition) -
        Offset(floorNumber(row, 'x'), floorNumber(row, 'y'));
    widget.onMoveStart();
  }

  void updateDrag(String id, DragUpdateDetails details) {
    if (dragOffset != null) {
      widget.onMove(id, scene(details.globalPosition) - dragOffset!);
    }
  }

  void endDrag(String id) {
    dragOffset = null;
    widget.onMoveEnd(id);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final fitKey =
          '${widget.plan['id']}/${room.width}/${room.height}/${constraints.maxWidth}';
      if (fitted != fitKey) {
        fitted = fitKey;
        final scale =
            math.min(
              constraints.maxWidth / room.width,
              constraints.maxHeight / room.height,
            ) *
            .95;
        camera.value = Matrix4.identity()
          ..translateByDouble(8, 8, 0, 1)
          ..scaleByDouble(scale, scale, 1, 1);
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xffede9e0),
                  border: Border.all(color: const Color(0xffd7cebf)),
                ),
                child: DragTarget<String>(
                  key: viewportKey,
                  onWillAcceptWithDetails: (_) => widget.editing,
                  onAcceptWithDetails: (d) =>
                      widget.onDrop(d.data, scene(d.offset)),
                  builder: (_, _, _) => InteractiveViewer(
                    transformationController: camera,
                    constrained: false,
                    minScale: .05,
                    maxScale: 4,
                    boundaryMargin: const EdgeInsets.all(300),
                    child: SizedBox(
                      width: room.width,
                      height: room.height,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _FloorGrid(widget.tables),
                            ),
                          ),
                          if (widget.backgroundUrl != null)
                            Positioned(
                              left: floorNumber(widget.plan, 'background_x'),
                              top: floorNumber(widget.plan, 'background_y'),
                              width: floorNumber(
                                widget.plan,
                                'background_width',
                                room.width,
                              ),
                              height: floorNumber(
                                widget.plan,
                                'background_height',
                                room.height,
                              ),
                              child: IgnorePointer(
                                child: Transform.rotate(
                                  angle:
                                      floorNumber(
                                        widget.plan,
                                        'background_angle',
                                      ) *
                                      math.pi /
                                      180,
                                  child: Opacity(
                                    opacity: floorNumber(
                                      widget.plan,
                                      'background_opacity',
                                      .45,
                                    ).clamp(0, 1),
                                    child: Image.network(
                                      widget.backgroundUrl!,
                                      fit: BoxFit.fill,
                                      errorBuilder: (_, _, _) => const Center(
                                        child: Text(
                                          'Reference image unavailable. Upload it again.',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          for (final o in widget.objects) node(o, false),
                          for (final t in widget.tables) node(t, true),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Zoom out',
                    onPressed: () => zoom(.8),
                    icon: const Icon(Icons.remove),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    tooltip: 'Fit room',
                    onPressed: () => setState(() => fitted = null),
                    icon: const Icon(Icons.fit_screen),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    tooltip: 'Zoom in',
                    onPressed: () => zoom(1.25),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
  void zoom(double factor) {
    final scale = camera.value.getMaxScaleOnAxis();
    if (scale * factor < .05 || scale * factor > 4) return;
    camera.value = camera.value.clone()..scaleByDouble(factor, factor, 1, 1);
  }

  Widget node(FloorRow row, bool table) {
    final id = row['id'] as String;
    final selected = widget.selected.contains(id);
    final w = floorNumber(row, 'width', 100),
        h = floorNumber(row, 'height', 80);
    final status = row['status'] as String? ?? 'available';
    final label = row['label'] as String? ?? '';
    final text = table
        ? '$label · ${row['capacity']} seats · ${floorStatuses[status]}'
        : '${row['kind']} $label';
    return Positioned(
      left: floorNumber(row, 'x'),
      top: floorNumber(row, 'y'),
      width: w,
      height: h,
      child: Transform.rotate(
        angle: floorNumber(row, 'angle') * math.pi / 180,
        child: Semantics(
          label: text,
          button: true,
          selected: selected,
          child: GestureDetector(
            // Axis recognizers claim table drags before the surrounding page scroll.
            // Global positions preserve movement in both dimensions after either axis wins.
            onHorizontalDragStart: widget.editing
                ? (d) => startDrag(row, d)
                : null,
            onHorizontalDragUpdate: widget.editing
                ? (d) => updateDrag(id, d)
                : null,
            onHorizontalDragEnd: widget.editing ? (_) => endDrag(id) : null,
            onVerticalDragStart: widget.editing
                ? (d) => startDrag(row, d)
                : null,
            onVerticalDragUpdate: widget.editing
                ? (d) => updateDrag(id, d)
                : null,
            onVerticalDragEnd: widget.editing ? (_) => endDrag(id) : null,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey('floor-$id'),
                onTap: table || widget.editing
                    ? () => widget.onSelect(id)
                    : null,
                borderRadius: BorderRadius.circular(
                  row['shape'] == 'round' ? 100 : 10,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: table
                        ? floorStatusColor(status).withValues(alpha: .17)
                        : switch (row['kind']) {
                            'chair' => const Color(0xffd1b789),
                            'wall' => const Color(0xff647078),
                            'door' => const Color(0xffd9e8de),
                            _ => Colors.transparent,
                          },
                    border: Border.all(
                      color: selected
                          ? const Color(0xff161c26)
                          : table
                          ? floorStatusColor(status)
                          : const Color(0xff756a59),
                      width: selected ? 4 : 2,
                    ),
                    borderRadius: BorderRadius.circular(
                      row['shape'] == 'round' ? 100 : 10,
                    ),
                  ),
                  child: Center(
                    child: table
                        ? Padding(
                            padding: const EdgeInsets.all(4),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text('${row['capacity']} seats'),
                                  Text(floorStatuses[status] ?? status),
                                  if (row['group_id'] != null)
                                    const Icon(Icons.link, size: 16),
                                  if (row['accessible'] == true)
                                    const Icon(Icons.accessible, size: 16),
                                  if (widget.partyLabels[id] != null)
                                    Text(
                                      widget.partyLabels[id]!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          )
                        : row['kind'] == 'chair'
                        ? const Icon(Icons.chair_alt, size: 20)
                        : row['kind'] == 'door'
                        ? const Icon(Icons.door_front_door, size: 20)
                        : Text(
                            label,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloorGrid extends CustomPainter {
  _FloorGrid(this.tables);
  final List<FloorRow> tables;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xfffcfaf6),
    );
    final grid = Paint()
      ..color = const Color(0xffe6dfd3)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final grouped = <String, List<FloorRow>>{};
    for (final t in tables) {
      if (t['group_id'] != null) (grouped[t['group_id']] ??= []).add(t);
    }
    final link = Paint()
      ..color = const Color(0xff72706a)
      ..strokeWidth = 4;
    for (final unit in grouped.values) {
      for (var i = 1; i < unit.length; i++) {
        Offset center(FloorRow t) => Offset(
          floorNumber(t, 'x') + floorNumber(t, 'width') / 2,
          floorNumber(t, 'y') + floorNumber(t, 'height') / 2,
        );
        canvas.drawLine(center(unit.first), center(unit[i]), link);
      }
    }
  }

  @override
  bool shouldRepaint(_FloorGrid oldDelegate) => true;
}
