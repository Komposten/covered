class OffsetToLineConverter {
  final String _text;
  int lastLineEnd = 0;
  int lastOffset = 0;

  OffsetToLineConverter(this._text);

  int getLine(int offset) {
    _validateOffset(offset);

    if (lastOffset > offset) {
      lastOffset = 0;
      lastLineEnd = 0;
    }

    var line = RegExp(r'\r\n?|\n\r?')
        .allMatches(_text.substring(lastOffset, offset))
        .length + lastLineEnd;

    lastLineEnd = line;
    lastOffset = offset;

    return line;
  }

  int getColumn(int offset) {
    _validateOffset(offset);

    if (offset == 0) {
      return offset;
    }

    var newlineIndex = _text.lastIndexOf(RegExp(r'\r\n?|\n\r?'), offset-1);

    if (newlineIndex == -1) {
      return offset;
    } else {
      return offset - newlineIndex - 1;
    }
  }

  void _validateOffset(int offset) {
    if (offset < 0) {
      throw ArgumentError('[offset] cannot be negative: $offset < 0');
    }
    if (offset > _text.length) {
      throw ArgumentError('[offset] cannot be after the end of the text: $offset > ${_text.length}');
    }
  }
}