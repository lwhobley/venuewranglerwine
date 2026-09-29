import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';

class VenueGeofenceFields extends StatefulWidget {
  const VenueGeofenceFields({
    super.key,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });
  final TextEditingController address, latitude, longitude, radius;
  @override
  State<VenueGeofenceFields> createState() => _VenueGeofenceFieldsState();
}

class _VenueGeofenceFieldsState extends State<VenueGeofenceFields> {
  bool _busy = false;
  String? _message;
  Future<void> _lookup() async {
    final address = widget.address.text.trim();
    if (address.isEmpty) {
      setState(() => _message = 'Enter the full venue address first.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final matches = await Geocoding().locationFromAddress(address);
      if (!mounted) return;
      if (widget.address.text.trim() != address) {
        setState(() => _message = 'The address changed. Look it up again.');
        return;
      }
      if (matches.isEmpty) {
        throw const FormatException();
      }
      final match = matches.first;
      widget.latitude.text = match.latitude.toStringAsFixed(7);
      widget.longitude.text = match.longitude.toStringAsFixed(7);
      setState(
        () => _message = 'Review the coordinates before creating the venue. Adjust them if the address points to the wrong entrance.',
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Address lookup is unavailable. Enter confirmed latitude and longitude for this address.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: widget.address,
        decoration: const InputDecoration(
          labelText: 'Full venue address',
          hintText: 'Street, city, state, postal code, country',
        ),
        onChanged: (_) {
          widget.latitude.clear();
          widget.longitude.clear();
        },
      ),
      const SizedBox(height: 12),
      if (!kIsWeb &&
          {
            TargetPlatform.android,
            TargetPlatform.iOS,
            TargetPlatform.macOS,
          }.contains(defaultTargetPlatform))
        OutlinedButton.icon(
          onPressed: _busy ? null : _lookup,
          icon: const Icon(Icons.location_on_outlined),
          label: Text(_busy ? 'Finding address…' : 'Find address location'),
        ),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(_message!),
        ),
      const Text(
        'Clock-in and clock-out require a location inside this venue boundary. Confirm the address coordinates below.',
      ),
      const SizedBox(height: 12),
      TextField(
        controller: widget.latitude,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        decoration: const InputDecoration(labelText: 'Venue latitude'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: widget.longitude,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        decoration: const InputDecoration(labelText: 'Venue longitude'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: widget.radius,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Clock radius (feet)',
          helperText: '1–1,000 feet; default 1,000',
        ),
      ),
    ],
  );
}
