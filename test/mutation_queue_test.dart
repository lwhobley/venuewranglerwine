import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:venue_wrangler/core/offline/mutation_queue.dart';

void main() {
  test('queued invites survive a new store instance', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final queue = SharedPreferencesMutationQueue(preferences);
    await queue.enqueue(
      kind: 'invite',
      payload: {'email': 'host@cellar.test', 'roleKey': 'host'},
    );
    final reloaded = SharedPreferencesMutationQueue(preferences);
    final pending = await reloaded.pending(kind: 'invite');
    expect(pending, hasLength(1));
    expect(pending.single.payload['email'], 'host@cellar.test');
  });
}
