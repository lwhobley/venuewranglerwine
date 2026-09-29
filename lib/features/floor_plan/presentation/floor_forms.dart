import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../workforce/domain/workforce_time.dart';
import '../domain/floor_models.dart';

class FloorField {
  const FloorField(
    this.key,
    this.label, {
    this.kind = 'text',
    this.required = false,
    this.min,
    this.max,
    this.choices = const {},
    this.lines = 1,
  });
  final String key, label, kind;
  final bool required;
  final double? min, max;
  final Map<String, String> choices;
  final int lines;
}

Future<FloorRow?> floorForm(
  BuildContext context,
  String title,
  List<FloorField> fields,
  FloorRow initial, {
  String zone = 'UTC',
}) => showDialog<FloorRow>(
  context: context,
  builder: (_) =>
      _FloorForm(title: title, fields: fields, initial: initial, zone: zone),
);

class _FloorForm extends StatefulWidget {
  const _FloorForm({
    required this.title,
    required this.fields,
    required this.initial,
    required this.zone,
  });
  final String title, zone;
  final List<FloorField> fields;
  final FloorRow initial;
  @override
  State<_FloorForm> createState() => _FloorFormState();
}

class _FloorFormState extends State<_FloorForm> {
  final form = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  late final FloorRow values = Map.of(widget.initial);
  bool saving = false;
  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      if (f.kind == 'bool' || f.kind == 'choice') continue;
      var text = '${values[f.key] ?? ''}';
      if (f.kind == 'instant' && text.isNotEmpty) {
        text = DateFormat('yyyy-MM-dd HH:mm').format(
          tz.TZDateTime.from(DateTime.parse(text), tz.getLocation(widget.zone)),
        );
      }
      controllers[f.key] = TextEditingController(text: text);
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? validate(FloorField f, String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) {
      return f.required ? 'Enter ${f.label.toLowerCase()}' : null;
    }
    if (f.kind == 'int' || f.kind == 'number') {
      final value = f.kind == 'int'
          ? int.tryParse(text)
          : double.tryParse(text);
      if (value == null ||
          !value.toDouble().isFinite ||
          (f.min != null && value < f.min!) ||
          (f.max != null && value > f.max!)) {
        return 'Enter ${f.kind == 'int' ? 'a whole number' : 'a number'}${f.min == null ? '' : ' from ${f.min!.toStringAsFixed(0)} to ${f.max!.toStringAsFixed(0)}'}';
      }
    }
    if (f.kind == 'instant') {
      try {
        final wall = DateFormat('yyyy-MM-dd HH:mm').parseStrict(text, true);
        if (wallTimeCandidates(wall, widget.zone).isEmpty) {
          return 'That time does not exist here because clocks change.';
        }
      } catch (_) {
        return 'Use YYYY-MM-DD HH:MM in ${widget.zone}';
      }
    }
    if (text.length > (f.max?.toInt() ?? 2000) && f.kind == 'text') {
      return 'Keep this under ${f.max?.toInt() ?? 2000} characters';
    }
    return null;
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    for (final f in widget.fields) {
      if (f.kind == 'choice') {
        if (values[f.key] == '') values[f.key] = null;
        continue;
      }
      if (f.kind == 'bool') {
        values[f.key] = values[f.key] == true;
        continue;
      }
      final text = controllers[f.key]!.text.trim();
      if (f.kind == 'int') {
        values[f.key] = text.isEmpty ? null : int.parse(text);
      } else if (f.kind == 'number') {
        values[f.key] = text.isEmpty ? null : double.parse(text);
      } else if (f.kind == 'instant') {
        if (text.isEmpty) {
          values[f.key] = null;
          continue;
        }
        final times = wallTimeCandidates(
          DateFormat('yyyy-MM-dd HH:mm').parseStrict(text, true),
          widget.zone,
        );
        DateTime? time = times.first;
        if (times.length > 1) {
          time = await showDialog<DateTime>(
            context: context,
            builder: (c) => SimpleDialog(
              title: const Text(
                'Clocks repeat this time. Choose which occurrence.',
              ),
              children: [
                for (var i = 0; i < times.length; i++)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(c, times[i]),
                    child: Text(
                      '${i == 0 ? 'First' : 'Second'} occurrence · ${times[i].toIso8601String()}',
                    ),
                  ),
              ],
            ),
          );
        }
        if (!mounted) return;
        if (time == null) {
          setState(() => saving = false);
          return;
        }
        values[f.key] = time.toUtc().toIso8601String();
      } else {
        values[f.key] = text;
      }
    }
    if (mounted) Navigator.pop(context, values);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in widget.fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: f.kind == 'bool'
                      ? SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(f.label),
                          value: values[f.key] == true,
                          onChanged: (v) => setState(() => values[f.key] = v),
                        )
                      : f.kind == 'choice'
                      ? DropdownButtonFormField<String>(
                          initialValue: f.choices.containsKey(values[f.key])
                              ? values[f.key] as String?
                              : f.required
                              ? null
                              : '',
                          isExpanded: true,
                          decoration: InputDecoration(labelText: f.label),
                          items: [
                            if (!f.required)
                              const DropdownMenuItem(
                                value: '',
                                child: Text('None'),
                              ),
                            for (final e in f.choices.entries)
                              DropdownMenuItem(
                                value: e.key,
                                child: Text(
                                  e.value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          validator: (v) =>
                              f.required && (v == null || v.isEmpty)
                              ? 'Choose ${f.label.toLowerCase()}'
                              : null,
                          onChanged: (v) => values[f.key] = v,
                        )
                      : TextFormField(
                          controller: controllers[f.key],
                          maxLines: f.lines,
                          keyboardType: f.kind == 'int' || f.kind == 'number'
                              ? const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                )
                              : null,
                          decoration: InputDecoration(
                            labelText: f.label,
                            helperText: f.kind == 'instant'
                                ? 'YYYY-MM-DD HH:MM · ${widget.zone}'
                                : null,
                          ),
                          validator: (raw) => validate(f, raw),
                        ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: saving ? null : save, child: const Text('Apply')),
    ],
  );
}
