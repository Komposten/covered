import 'package:covered/src/js/utilities.dart';
import 'package:test/test.dart';

main() {
  group('OffsetToLineConverter_', () {
    String text;
    OffsetToLineConverter converter;

    setUpAll(() {
      text = 'Line: A prequel\nLine 1\nLine: The second\n\nLine: Beyond';
      converter = OffsetToLineConverter(text);
    });

    group('getLine_', () {
      test('negativeOffset_throwArgumentError', () {
        expect(() => converter.getLine(-1), throwsArgumentError);
      });

      test('offsetAfterTextEnd_throwArgumentError', () {
        expect(() => converter.getLine(text.length + 1), throwsArgumentError);
      });

      test('increasingOffsets', () {
        expect(converter.getLine(0), 0);
        expect(converter.getLine(10), 0);
        expect(converter.getLine(18), 1);
        expect(converter.getLine(49), 4);
      });

      test('decreasingOffsets', () {
        expect(converter.getLine(49), 4);
        expect(converter.getLine(18), 1);
        expect(converter.getLine(10), 0);
        expect(converter.getLine(0), 0);
      });

      test('alternatingOffsets', () {
        expect(converter.getLine(0), 0);
        expect(converter.getLine(18), 1);
        expect(converter.getLine(49), 4);
        expect(converter.getLine(10), 0);
      });
    });

    group('getColumn_', () {
      test('negativeOffset_throwArgumentError', () {
        expect(() => converter.getLine(-1), throwsArgumentError);
      });

      test('offsetAfterTextEnd_throwArgumentError', () {
        expect(() => converter.getLine(text.length + 1), throwsArgumentError);
      });

      test('offsetOnFirstLine', () {
        expect(converter.getColumn(0), 0);
        expect(converter.getColumn(5), 5);
        expect(converter.getColumn(8), 8);
      });

      test('offsetOnOtherLines', () {
        expect(converter.getColumn(15), 15); //15 is a newline character
        expect(
            converter.getColumn(16), 0); //16 is right after a newline character
        expect(converter.getColumn(28), 5);
        expect(converter.getColumn(49), 8);
        expect(converter.getColumn(text.length), 12);
      });
    });
  });
}
