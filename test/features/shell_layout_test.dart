import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sociao/features/shell/presentation/app_bottom_nav.dart';

/// Regression: the bottom bar once expanded to the full screen height (a
/// `Center` inside the row), leaving the page body with zero height.
void main() {
  testWidgets('bottom nav stays short and leaves room for the body', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(key: Key('body')),
          bottomNavigationBar: AppBottomNav(
            currentIndex: 0,
            onSelected: (_) {},
            onCreate: () {},
          ),
        ),
      ),
    );

    final nav = tester.getSize(find.byType(AppBottomNav));
    final body = tester.getSize(find.byKey(const Key('body')));
    expect(nav.height, lessThan(140));
    expect(body.height, greaterThan(600));
  });
}
