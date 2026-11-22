import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import 'auth_controller.dart';
import 'auth_scaffold.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool get _valid =>
      Validators.fullName(_name.text) == null &&
      Validators.email(_email.text) == null &&
      Validators.password(_password.text) == null;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final needsConfirmation = await ref
        .read(authControllerProvider.notifier)
        .signUp(_name.text, _email.text, _password.text);
    if (!mounted) return;
    if (needsConfirmation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Check your email to confirm your account, then log in.',
          ),
        ),
      );
      context.go(AppRoutes.login);
    }
    // Otherwise a session exists and the router redirects to /home.
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('${next.error}')));
      }
    });
    final loading = ref.watch(authControllerProvider).isLoading;

    return AuthScaffold(
      title: 'Create Account',
      subtitle: 'Join Sociao and start connecting with people who inspire you.',
      footerQuestion: 'Already have an account?',
      footerAction: 'Log in',
      onFooterTap: () => context.go(AppRoutes.login),
      children: [
        Form(
          key: _formKey,
          onChanged: () => setState(() {}),
          child: Column(
            children: [
              AppTextField(
                label: 'Full Name',
                hint: 'Enter name',
                controller: _name,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: Validators.fullName,
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Email',
                hint: 'name@gmail.com',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Password',
                hint: 'Enter password',
                controller: _password,
                isPassword: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.password,
              ),
              const SizedBox(height: 28),
              AppButton(
                label: 'Create Account',
                isLoading: loading,
                onPressed: _valid ? _submit : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
