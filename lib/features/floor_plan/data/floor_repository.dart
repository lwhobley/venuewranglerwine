import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../domain/floor_models.dart';

final floorRepositoryProvider = Provider(
  (ref) => FloorRepository(Supabase.instance.client),
);

class FloorRepository {
  FloorRepository(this.client);
  final SupabaseClient client;
  Future<FloorSnapshot> snapshot(String org, String venue) => _guard(
    () async => FloorSnapshot(
      Map<String, dynamic>.from(
        await client.rpc(
          'floor_snapshot',
          params: {'p_org': org, 'p_venue': venue},
        ) as Map,
      ),
    ),
  );
  Future<void> command(
    String org,
    String venue,
    String id,
    String action,
    FloorRow payload,
  ) => _guard(() async {
    await client.rpc(
      'floor_command',
      params: {
        'p_org': org,
        'p_venue': venue,
        'p_command': id,
        'p_action': action,
        'p_payload': payload,
      },
    );
  });
  Future<String> upload(String path, Uint8List png) => _guard(() async {
    await client.storage
        .from('floor-plan-images')
        .uploadBinary(
          path,
          png,
          fileOptions: const FileOptions(contentType: 'image/png'),
        );
    return path;
  });
  Future<String> imageUrl(String path) => _guard(
    () => client.storage.from('floor-plan-images').createSignedUrl(path, 3600),
  );
  Future<Uint8List> referenceBytes(String path) =>
      _guard(() => client.storage.from('floor-plan-images').download(path));
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      const messages = {
        'floor_stale': 'The floor changed on another device. Refresh before saving your changes.',
        'floor_in_use': 'That table or room has an active party or assignment. Finish or move the party first.',
        'floor_scope': 'Choose tables and a plan from this venue.',
        'floor_choose_tables': 'Choose a table or combination in one room.',
        'floor_combine_first':
            'Combine these tables before seating one party across them.',
        'floor_combine_invalid':
            'Combine two to eight clean, unassigned tables in the same room.',
        'floor_booking_conflict':
            'These tables have another party or an overlapping reservation.',
        'floor_accessibility': 'Choose an accessible table for this party.',
        'floor_server_invalid': 'Choose an active team member at this venue.',
        'floor_out_of_bounds': 'Keep furniture inside the room boundary.',
        'floor_image_not_found':
            'Upload the reference image to this room before saving.',
        'table_occupied': 'Complete or transfer the seated party before changing table status.',
        'table_unavailable':
            'These tables must be clean and ready before seating.',
        'party_exceeds_capacity':
            'Choose tables with enough seats for this party.',
        'command_reuse': 'This retry no longer matches the original action.',
      };
      for (final entry in messages.entries) {
        if (e.toString().contains(entry.key)) {
          throw ValidationFailure(entry.value);
        }
      }
      if (e is PostgrestException && e.code == '23505') {
        throw const ValidationFailure(
          'Use a unique table label in this venue.',
        );
      }
      if (e is PostgrestException &&
          ['23514', '22023', '22P02'].contains(e.code)) {
        throw const ValidationFailure(
          'Check the layout and seating values before saving.',
        );
      }
      throw mapFailure(e);
    }
  }
}
