import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:venue_wrangler/core/errors/app_failure.dart';
import 'package:venue_wrangler/core/errors/failure_mapper.dart';
import 'package:venue_wrangler/core/money/decimal_amount.dart';
import 'package:venue_wrangler/core/networking/retry_policy.dart';
import 'package:venue_wrangler/core/permissions/app_role.dart';
import 'package:venue_wrangler/core/permissions/capability_checker.dart';
import 'package:venue_wrangler/core/permissions/permission.dart';
import 'package:venue_wrangler/core/time/venue_clock.dart';
import 'package:venue_wrangler/features/onboarding/application/tenant_controller.dart';
import 'package:venue_wrangler/features/onboarding/domain/validators.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('signup password requires length, a letter, and a number', () {
    expect(FieldValidator.signUpPassword('short1'), isNotNull);
    expect(FieldValidator.signUpPassword('longpassword'), isNotNull);
    expect(FieldValidator.signUpPassword('longpassword1'), isNull);
  });

  test('slug is derived and validated', () {
    expect(FieldValidator.slugFromName('The Cellar Club'), 'the-cellar-club');
    expect(FieldValidator.slug('the-cellar-club'), isNull);
    expect(FieldValidator.slug('No'), isNotNull);
  });

  test('owner can invite a sommelier but a server cannot invite an owner', () {
    const checker = CapabilityChecker();
    expect(
      checker.can(role: AppRole.organizationOwner, permission: Permission.membershipInvite),
      isTrue,
    );
    expect(
      checker.canAssign(actor: AppRole.server, target: AppRole.organizationOwner),
      isFalse,
    );
    expect(
      checker.canAssign(actor: AppRole.organizationOwner, target: AppRole.beverageDirector),
      isTrue,
    );
  });

  test('a deny override blocks a granted permission', () {
    const checker = CapabilityChecker();
    expect(
      checker.can(
        role: AppRole.generalManager,
        permission: Permission.wineCostRead,
        overrides: const {Permission.wineCostRead: PermissionEffect.deny},
      ),
      isFalse,
    );
  });

  test('auditor can read cost and cannot write inventory', () {
    const checker = CapabilityChecker();
    expect(checker.can(role: AppRole.auditor, permission: Permission.wineCostRead), isTrue);
    expect(checker.can(role: AppRole.auditor, permission: Permission.wineMovementWrite), isFalse);
    expect(checker.can(role: AppRole.inventoryCounter, permission: Permission.wineCountApprove), isFalse);
  });

  test('decimal amounts never use binary floating point', () {
    final left = DecimalAmount.parse('12.1250');
    final right = DecimalAmount.parse('0.0001');
    expect(left.plus(right).toString(), '12.1251');
    expect(() => DecimalAmount.parse('1.12345'), throwsFormatException);
  });

  test('venue clock renders UTC instants in the venue zone', () {
    const clock = VenueClock();
    final utc = DateTime.utc(2026, 9, 27, 16, 30);
    expect(clock.format(utc, 'America/New_York'), contains('12:30'));
    expect(clock.isKnownZone('America/Not_A_Place'), isFalse);
  });

  test('retry policy backs off and skips unsafe posts', () {
    const policy = RetryPolicy(baseDelay: Duration(milliseconds: 100));
    expect(policy.delayForAttempt(1), const Duration(milliseconds: 100));
    expect(policy.delayForAttempt(3), const Duration(milliseconds: 400));
    expect(
      policy.shouldRetry(attempt: 1, method: 'POST', statusCode: 500, transportError: false),
      isFalse,
    );
    expect(
      policy.shouldRetry(
        attempt: 1,
        method: 'POST',
        statusCode: 500,
        transportError: false,
        idempotent: true,
      ),
      isTrue,
    );
  });

  test('database errors become user-safe failures', () {
    expect(mapFailure(Exception('permission_denied')), isA<PermissionFailure>());
    expect(mapFailure(Exception('slug_taken')).message, contains('already in use'));
  });

  test('invite tokens are long enough for the server minimum', () {
    expect(generateInviteToken().length, greaterThanOrEqualTo(32));
  });
}
