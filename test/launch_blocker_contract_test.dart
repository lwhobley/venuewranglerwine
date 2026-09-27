import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File('supabase/migrations/20260927001000_launch_blockers.sql').readAsStringSync();
  final counts = File('supabase/migrations/20260927000300_phase3_counts.sql').readAsStringSync();
  final service = File('supabase/migrations/20260927000600_phase6_service.sql').readAsStringSync();
  final pickup = File('supabase/migrations/20260927000500_phase5_allocations.sql').readAsStringSync();

  test('venue reads use scoped permission, not organization-wide permission', () {
    expect(sql.contains('function public.venue_visible'), isTrue);
    expect(sql.contains('venue_visible(organization_id, venue_id'), isTrue);
    expect(sql.contains("revoke all on function public.set_plan"), isTrue);
    expect(sql.contains('member_holdings'), isTrue);
    expect(sql.contains('self_approval_denied'), isTrue);
  });

  test('counts freeze each lot and refuse a pooled multi-lot entry', () {
    expect(counts.contains('b.lot_id'), isTrue);
    expect(counts.contains('group by b.slot_id, b.item_id'), isFalse);
    expect(counts.contains('lot_required'), isTrue);
  });

  test('opening a bottle reduces the lot total and pickup does not pool members', () {
    expect(service.contains('quantity_on_hand = quantity_on_hand - 1'), isTrue);
    expect(pickup.contains("ownership_class = 'member'"), isFalse);
  });
}
