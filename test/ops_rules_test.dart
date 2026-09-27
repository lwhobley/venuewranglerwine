import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:venue_wrangler/features/operations/domain/ops_rules.dart';

void main() {
  test('a party can be seated only on an open table that fits', () {
    expect(
      canSeat(reservationStatus: 'booked', tableStatus: 'available', party: 4, capacity: 4),
      isTrue,
    );
    expect(
      canSeat(reservationStatus: 'booked', tableStatus: 'seated', party: 2, capacity: 4),
      isFalse,
    );
    expect(
      canSeat(reservationStatus: 'booked', tableStatus: 'available', party: 5, capacity: 4),
      isFalse,
    );
  });

  test('an event moves one stage at a time and a closed event stops', () {
    expect(nextEventStage('inquiry'), 'hold');
    expect(nextEventStage('live'), 'closed');
    expect(nextEventStage('closed'), isNull);
    expect(shiftWindowValid(DateTime.utc(2026, 1, 1, 10), DateTime.utc(2026, 1, 1, 16)), isTrue);
    expect(canClockIn(openEntry: true), isFalse);
  });

  test('reports require an entitled active or trial plan', () {
    expect(reportAllowed(status: 'trial', entitled: true), isTrue);
    expect(reportAllowed(status: 'expired', entitled: true), isFalse);
    expect(reportAllowed(status: 'active', entitled: false), isFalse);
    expect(toCsv([
      ['metric', 'value'],
      ['booked', '2'],
    ]), 'metric,value\nbooked,2');
  });

  test('host, people, and business mutations are functions', () {
    final host = File('supabase/migrations/20260927000700_phase7_host.sql').readAsStringSync();
    final people = File('supabase/migrations/20260927000800_phase8_people.sql').readAsStringSync();
    final business = File('supabase/migrations/20260927000900_phase9_business.sql').readAsStringSync();
    expect(host.contains('function public.seat_reservation'), isTrue);
    expect(host.contains('table_occupied'), isTrue);
    expect(host.contains('grant insert on public.reservations'), isFalse);
    expect(people.contains('function public.publish_shifts'), isTrue);
    expect(people.contains('already_clocked_in'), isTrue);
    expect(business.contains('function public.add_beo'), isTrue);
    expect(business.contains('plan_required'), isTrue);
    expect(business.contains('grant insert on public.messages'), isFalse);
  });
}
