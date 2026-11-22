import 'package:flutter_test/flutter_test.dart';
import 'package:sociao/core/utils/formatters.dart';
import 'package:sociao/core/utils/validators.dart';

void main() {
  group('Formatters', () {
    test('count groups thousands', () {
      expect(Formatters.count(1450), '1,450');
      expect(Formatters.count(20), '20');
    });
    test('compact matches reference style', () {
      expect(Formatters.compact(490), '490');
      expect(Formatters.compact(12800), '12,8k');
      expect(Formatters.compact(2000), '2k');
    });
    test('timeAgo', () {
      expect(
        Formatters.timeAgo(DateTime.now().subtract(const Duration(minutes: 2))),
        '2m ago',
      );
    });
  });

  group('Validators', () {
    test('email', () {
      expect(Validators.email('name@gmail.com'), isNull);
      expect(Validators.email('nope'), isNotNull);
      expect(Validators.email(''), isNotNull);
    });
    test('password needs 8 chars, letter and number', () {
      expect(Validators.password('abc12345'), isNull);
      expect(Validators.password('short1'), isNotNull);
      expect(Validators.password('onlyletters'), isNotNull);
      expect(Validators.password('12345678'), isNotNull);
    });
    test('fullName and username', () {
      expect(Validators.fullName('  '), isNotNull);
      expect(Validators.username('gustavo.levin'), isNull);
      expect(Validators.username('A'), isNotNull);
    });
  });
}
