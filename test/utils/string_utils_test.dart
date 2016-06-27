import 'package:atom/utils/string_utils.dart';
import 'package:test/test.dart';

main() => defineTests();

defineTests() {
  group('string_utils diff', () {
    test('diff same', () {
      expect(simpleDiff('a', 'a').first, new Edit(0, 0, ''));
    });

    test('same', () {
      expect(simpleDiff('a', 'a').first, new Edit(0, 0, ''));
    });

    test('first empty', () {
      expect(simpleDiff('', 'a').first, new Edit(0, 0, 'a'));
    });

    test('second empty', () {
      expect(simpleDiff('a', '').first, new Edit(0, 1, ''));
    });

    test('addition', () {
      expect(simpleDiff('abde', 'abcde').first, new Edit(2, 0, 'c'));
    });

    test('deletion', () {
      expect(simpleDiff('abcde', 'abde').first, new Edit(2, 1, ''));
    });
  });
}
