import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sociao/core/theme/app_theme.dart';
import 'package:sociao/features/auth/data/auth_repository.dart';
import 'package:sociao/features/auth/presentation/login_screen.dart';
import 'package:sociao/features/auth/presentation/signup_screen.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

Widget _app(Widget screen, AuthRepository repo) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(theme: AppTheme.light, home: screen),
);

bool _enabled(WidgetTester tester, String label) {
  final button = tester.widget<FilledButton>(
    find.ancestor(of: find.text(label), matching: find.byType(FilledButton)),
  );
  return button.onPressed != null;
}

void main() {
  testWidgets('login button is disabled until email and password are valid', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const LoginScreen(), _MockAuthRepo()));
    await tester.pump();
    expect(_enabled(tester, 'Login'), isFalse);

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    await tester.pump();
    expect(_enabled(tester, 'Login'), isFalse);

    await tester.enterText(find.byType(TextFormField).first, 'a@b.com');
    await tester.pump();
    expect(_enabled(tester, 'Login'), isTrue);
  });

  testWidgets('password field can be shown and hidden', (tester) async {
    await tester.pumpWidget(_app(const LoginScreen(), _MockAuthRepo()));
    EditableText field() => tester.widget<EditableText>(
      find.descendant(
        of: find.byType(TextFormField).last,
        matching: find.byType(EditableText),
      ),
    );
    expect(field().obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(field().obscureText, isFalse);
  });

  testWidgets('sign up enforces password rules', (tester) async {
    await tester.pumpWidget(_app(const SignupScreen(), _MockAuthRepo()));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Gustavo Levin');
    await tester.enterText(fields.at(1), 'g@levin.com');
    await tester.enterText(fields.at(2), 'short');
    await tester.pump();
    expect(_enabled(tester, 'Create Account'), isFalse);

    await tester.enterText(fields.at(2), 'longenough1');
    await tester.pump();
    expect(_enabled(tester, 'Create Account'), isTrue);
  });
}
