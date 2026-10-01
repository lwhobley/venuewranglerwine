import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/status_banner.dart';
import '../domain/validators.dart';
import 'auth_frame.dart';
import 'credential_form.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Opening workspace'),
          ],
        ),
      ),
    );
  }
}

class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      title: 'Connect the workspace',
      subtitle: kReleaseMode
          ? 'This build is missing its workspace configuration. Install a newer build.'
          : 'Venue Wrangler talks to Supabase. It does not sign you in locally.',
      child: kReleaseMode
          ? const SizedBox.shrink()
          : const SelectableText(
              'flutter run -d chrome --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_ANON_KEY=your-anon-key',
            ),
    );
  }
}

class SignInPage extends ConsumerWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuthFrame(
      title: 'Sign in',
      subtitle: 'Use the email for your venue membership.',
      child: CredentialForm(
        primaryLabel: 'Sign in',
        onSubmit: (email, password, _) async {
          await ref.read(authControllerProvider.notifier).signIn(email: email, password: password);
        },
        secondary: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton(onPressed: () => context.go('/sign-up'), child: const Text('Create an account')),
            TextButton(
              onPressed: () => context.go('/reset-password'),
              child: const Text('Reset password'),
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpPage extends ConsumerWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuthFrame(
      title: 'Create an account',
      subtitle: 'You will become the owner of any organization you create.',
      child: CredentialForm(
        primaryLabel: 'Create account',
        showDisplayName: true,
        enforcePasswordRules: true,
        onSubmit: (email, password, name) async {
          final created = await ref.read(authControllerProvider.notifier).signUp(
            email: email,
            password: password,
            displayName: name,
          );
          if (!created && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Check your email to confirm the account, then sign in.')),
            );
          }
        },
        secondary: TextButton(
          onPressed: () => context.go('/sign-in'),
          child: const Text('Already have an account'),
        ),
      ),
    );
  }
}

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _email = TextEditingController();
  String? _message;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = FieldValidator.email(_email.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _error = null;
      _message = null;
    });
    try {
      final origin = Uri.base.origin;
      await ref.read(authControllerProvider.notifier).requestPasswordReset(
        email: _email.text,
        redirectTo: '$origin/auth/recovery',
      );
      setState(() => _message = 'If that email has an account, a reset link is on its way.');
    } on AppFailure catch (failure) {
      setState(() => _error = failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      title: 'Reset password',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) StatusBanner(message: _error!),
          if (_message != null) StatusBanner(message: _message!, tone: BannerTone.success),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _submit, child: const Text('Send reset link')),
          TextButton(onPressed: () => context.go('/sign-in'), child: const Text('Back to sign in')),
        ],
      ),
    );
  }
}

class VerifyEmailPage extends ConsumerWidget {
  const VerifyEmailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final email = auth is AuthSignedIn ? auth.email : '';
    return AuthFrame(
      title: 'Confirm your email',
      subtitle: email.isEmpty ? null : 'A confirmation was sent to $email.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: () => ref.read(authControllerProvider.notifier).resendVerification(),
            child: const Text('Resend confirmation'),
          ),
          TextButton(
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class RecoveryPage extends ConsumerStatefulWidget {
  const RecoveryPage({super.key});

  @override
  ConsumerState<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends ConsumerState<RecoveryPage> {
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = FieldValidator.signUpPassword(_password.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    try {
      await ref.read(authControllerProvider.notifier).updatePassword(_password.text);
    } on AppFailure catch (failure) {
      setState(() => _error = failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final startup = ref.watch(startupErrorProvider);
    return AuthFrame(
      title: 'Choose a new password',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (startup != null)
            const StatusBanner(message: 'The workspace connection failed. Check the Supabase URL and key.'),
          if (_error != null) StatusBanner(message: _error!),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _submit, child: const Text('Update password')),
        ],
      ),
    );
  }
}


