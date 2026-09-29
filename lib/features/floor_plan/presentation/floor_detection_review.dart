import 'package:flutter/material.dart';

import '../data/floor_detection.dart';

Future<List<({FloorSuggestion suggestion, String label, int capacity})>?>
reviewFloorSuggestions(
  BuildContext context,
  List<FloorSuggestion> suggestions,
  String imageUrl,
  Set<String> existing,
) =>
    showDialog<
      List<({FloorSuggestion suggestion, String label, int capacity})>
    >(
      context: context,
      builder: (_) => _DetectionReview(suggestions, imageUrl, existing),
    );

class _DetectionReview extends StatefulWidget {
  const _DetectionReview(this.suggestions, this.imageUrl, this.existing);
  final List<FloorSuggestion> suggestions;
  final String imageUrl;
  final Set<String> existing;
  @override
  State<_DetectionReview> createState() => _DetectionReviewState();
}

class _DetectionReviewState extends State<_DetectionReview> {
  final form = GlobalKey<FormState>();
  late final enabled = List.filled(widget.suggestions.length, true);
  late final usedLabels = widget.existing.map((e) => e.toLowerCase()).toSet();
  late final labels = List.generate(widget.suggestions.length, (i) {
    var name = widget.suggestions[i].label ?? 'T${i + 1}';
    var n = i + 1;
    while (usedLabels.contains(name.toLowerCase())) {
      name = 'T${++n}';
    }
    usedLabels.add(name.toLowerCase());
    return TextEditingController(text: name);
  });
  late final seats = List.generate(
    widget.suggestions.length,
    (_) => TextEditingController(text: '4'),
  );
  @override
  void dispose() {
    for (final c in labels.followedBy(seats)) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Review ${widget.suggestions.length} suggested tables'),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'These are suggestions, not a verified layout. Remove chairs, fixtures, or other objects mistaken for tables. Check each label and seat count before adding.',
              ),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 1.5,
                child: LayoutBuilder(
                  builder: (context, box) => Stack(
                    children: [
                      Positioned.fill(
                        child: Image.network(
                          widget.imageUrl,
                          fit: BoxFit.fill,
                          errorBuilder: (_, _, _) => const SizedBox(),
                        ),
                      ),
                      for (var i = 0; i < widget.suggestions.length; i++)
                        if (enabled[i])
                          Positioned(
                            left: widget.suggestions[i].x * box.maxWidth,
                            top: widget.suggestions[i].y * box.maxHeight,
                            width: widget.suggestions[i].width * box.maxWidth,
                            height:
                                widget.suggestions[i].height * box.maxHeight,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.blue,
                                  width: 2,
                                ),
                                color: Colors.blue.withValues(alpha: .12),
                              ),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < widget.suggestions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: enabled[i],
                        onChanged: (v) =>
                            setState(() => enabled[i] = v ?? false),
                        title: Text(
                          'Suggestion ${i + 1} · ${widget.suggestions[i].shape}',
                        ),
                        subtitle: Text(
                          widget.suggestions[i].confidence < .5
                              ? 'Table-label estimate · check its boundaries'
                              : 'Outline / surface estimate · check its boundaries',
                        ),
                      ),
                      if (enabled[i])
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: labels[i],
                                decoration: const InputDecoration(
                                  labelText: 'Table label',
                                ),
                                validator: (v) {
                                  final text = v?.trim() ?? '';
                                  if (text.isEmpty || text.length > 80) {
                                    return 'Enter a label';
                                  }
                                  if (widget.existing.any(
                                        (e) =>
                                            e.toLowerCase() ==
                                            text.toLowerCase(),
                                      ) ||
                                      List.generate(
                                        labels.length,
                                        (j) => j,
                                      ).any(
                                        (j) =>
                                            j != i &&
                                            enabled[j] &&
                                            labels[j].text
                                                    .trim()
                                                    .toLowerCase() ==
                                                text.toLowerCase(),
                                      )) {
                                    return 'Use a unique label';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 100,
                              child: TextFormField(
                                controller: seats[i],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Seats',
                                ),
                                validator: (v) {
                                  final n = int.tryParse(v ?? '');
                                  return n == null || n < 1 || n > 20
                                      ? 'Use 1–20'
                                      : null;
                                },
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Keep image only'),
      ),
      FilledButton(
        onPressed: () {
          if (!form.currentState!.validate()) return;
          Navigator.pop(context, [
            for (var i = 0; i < widget.suggestions.length; i++)
              if (enabled[i])
                (
                  suggestion: widget.suggestions[i],
                  label: labels[i].text.trim(),
                  capacity: int.parse(seats[i].text),
                ),
          ]);
        },
        child: const Text('Add reviewed tables'),
      ),
    ],
  );
}
