import 'package:covered/src/js/utilities.dart';
import 'package:test/test.dart';

main() {
  group('base64Decode_', () {
    test('allValidChars_decode', () {
      var actual = base64Decode(base64_alphabet);
      var expected = <int>[];
      for (int i = 0; i < 64; i++) {
        expected.add(i);
      }

      expect(actual, containsAllInOrder(expected));
    });

    test('invalidInput_throwArgumentError', () {
      expect(() => base64Decode('!'), throwsArgumentError);
    });
  });

  group('vlqDecode_', () {
    test('singleSextet', () {
      expect(vlqDecode([30]), [15],
          reason: '011110 (30) should decode to positive 1111 (15)');
      expect(vlqDecode([31]), [-15],
          reason: '011111 (30) should decode to negative 1111 (-15)');
      expect(vlqDecode([22]), [11],
          reason: '010110 (22) should decode to positive 1011 (11)');
      expect(vlqDecode([23]), [-11],
          reason: '010111 (23) should decode to negative 1011 (-11)');
    });

    test('singleOctet_ignoreFirstTwoBits', () {
      expect(vlqDecode([214]), [11],
          reason: '11010110 (214) should decode to positive 1011 (11)');
    });

    test('lastHasContinuationBitSet_throwArgumentError', () {
      expect(() => vlqDecode([32]), throwsArgumentError);
    });

    test('multipleSeparateSextets', () {
      expect(vlqDecode([30, 31, 22, 23]), [15, -15, 11, -11]);
    });

    test('multipleContinuedSextets', () {
      expect(vlqDecode([32, 44, 9]), [4800]);
      expect(vlqDecode([33, 44, 9]), [-4800]);
    });

    test('multipleContinuedSeparateSextets', () {
      expect(vlqDecode([32, 44, 9, 33, 44, 9]), [4800, -4800]);
    });

    test('tooManyContinuedSextets', () {
      var _11sequences = [62, 63, 63, 63, 63, 63, 63, 63, 63, 63, 31];
      var _11sequences3Bits = [62, 63, 63, 63, 63, 63, 63, 63, 63, 63, 63, 7];
      var _11sequences4Bits = [62, 63, 63, 63, 63, 63, 63, 63, 63, 63, 63, 15];
      var _12sequences = [62, 63, 63, 63, 63, 63, 63, 63, 63, 63, 63, 31];

      expect(vlqDecode(_11sequences), [18014398509481983]);
      expect(vlqDecode(_11sequences3Bits), [144115188075855871]);
      expect(() => vlqDecode(_11sequences4Bits), throwsArgumentError);
      expect(() => vlqDecode(_12sequences), throwsArgumentError);
    });
  });

  test('temp', () {
    var vlqs = base64Decode('AAOCmBAAKCAAC0BAA0BcAAMAAAuBiCAAI');
    var ints = vlqDecode(vlqs);
    print(ints);
  });
}
