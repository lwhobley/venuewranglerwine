import 'package:flutter/material.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/status_banner.dart';
import '../domain/validators.dart';

class CredentialForm extends StatefulWidget {
  const CredentialForm({
    super.key,
    required this.primaryLabel,
    required this.onSubmit,
    this.showDisplayName = false,
    this.enforcePasswordRules = false,
    this.secondary,
  });

  final String primaryLabel;
  final Future<void> Function(String email, String password, String displayName) onSubmit;
  final bool showDisplayName;
  final bool enforcePasswordRules;
  final Widget? secondary;

  @override
  State<CredentialForm> createState() => _CredentialFormState();
}

class _CredentialFormState extends State<CredentialForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_email.text, _password.text, _name.text);
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            StatusBanner(message: _error!),
            const SizedBox(height: 12),
          ],
          if (widget.showDisplayName)
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Display name'),
              validator: (value) => FieldValidator.displayName(value ?? ''),
            ),
          if (widget.showDisplayName) const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (value) => FieldValidator.email(value ?? ''),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: true,
            autofillHints: widget.enforcePasswordRules
                ? const [AutofillHints.newPassword]
                : const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'Password'),
            validator: (value) => widget.enforcePasswordRules
                ? FieldValidator.signUpPassword(value ?? '')
                : FieldValidator.signInPassword(value ?? ''),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Working' : widget.primaryLabel),
          ),
          if (widget.secondary != null) ...[
            const SizedBox(height: 8),
            widget.secondary!,
          ],
        ],
      ),
    );
  }
}
