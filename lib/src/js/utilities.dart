const base64_alphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
const continuation_bit = 0x20;

List<int> base64Decode(String input) {
  List<int> list = [];

  for (var i = 0; i < input.length; i++) {
    var decoded = base64_alphabet.indexOf(input[i]);
    if (decoded == -1) {
      throw ArgumentError(
          '[input] may only contain characters from the set [A-Za-z0-9+/]!');
    }

    list.add(decoded);
  }

  return list;
}

List<int> vlqDecode(List<int> sextets) {
  if (sextets.last & continuation_bit != 0) {
    throw ArgumentError(
        '[sextets] ends with an incomplete VLQ (continuation bit is set)!');
  }

  List<int> list = [];
  int current;
  int sequence = 0;

  for (var sextet in sextets) {
    _checkWithinIntBounds(sequence, sextet);

    var leastSignificantBits = sextet & 0x1F; //1F = 011111
    if (sequence == 0) {
      //Start of a sequence, so just set current to the LSBs.
      current = leastSignificantBits;
    } else {
      //Continuation of a sequence, so we prepend the LSBs to the value
      //by first left-shifting them.
      current = current | (leastSignificantBits << (sequence * 5));
    }

    if (sextet & continuation_bit != 0) {
      sequence++;
    } else {
      var sign = (current & 1 == 0 ? 1 : -1);
      current = (current >> 1); //Remove the sign bit.
      list.add(sign * current);
      sequence = 0;
    }
  }

  return list;
}

void _checkWithinIntBounds(int sequenceCount, int sextet) {
  if ((sequenceCount == 11 && (sextet & 0x38 != 0)) || sequenceCount > 11) {
    throw ArgumentError(
        'Decoded values larger than 2^63 (= 11 sequences + 3 bits) are not supported!');
  }
}
