import 'package:flutter_test/flutter_test.dart';

import 'package:sociao/app.dart';

void main() {
  testWidgets('shows setup message when env is missing', (tester) async {
    await tester.pumpWidget(const ConfigErrorApp(message: 'Missing env'));
    expect(find.text('Sociao setup required'), findsOneWidget);
    expect(find.text('Missing env'), findsOneWidget);
  });
}
