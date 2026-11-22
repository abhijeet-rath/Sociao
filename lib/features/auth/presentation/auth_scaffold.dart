import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';

/// Shared layout for Login and Create Account: left-aligned title + subtitle,
/// form children, footer link and terms text (see reference screens 01/02).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    required this.footerQuestion,
    required this.footerAction,
    required this.onFooterTap,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final String footerQuestion;
  final String footerAction;
  final VoidCallback onFooterTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.maxContentWidth,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  48,
                  AppSpacing.page,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 32),
                    ...children,
                    const SizedBox(height: 28),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '$footerQuestion ',
                            style: theme.textTheme.bodyLarge,
                          ),
                          InkWell(
                            onTap: onFooterTap,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                footerAction,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: AppColors.blue,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.blue,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'By signing up, you agree to our Terms of Service and Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
