import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venue_wrangler/features/onboarding/presentation/credential_form.dart';

void main() {
  testWidgets('sign-in form rejects an empty email', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CredentialForm(primaryLabel: 'Sign in', onSubmit: (_, _, _) async {}),
        ),
      ),
    );
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('sign-up form rejects a weak password', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CredentialForm(
            primaryLabel: 'Create account',
            showDisplayName: true,
            enforcePasswordRules: true,
            onSubmit: (_, _, _) async {},
          ),
        ),
      ),
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Display name'), 'Ava Chen');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'ava@cellar.test');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'short');
    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(find.text('Use at least 10 characters.'), findsOneWidget);
  });
}
