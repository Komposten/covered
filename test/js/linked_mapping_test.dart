@TestOn('vm')
import 'dart:io';

import 'package:covered/src/js/linked_mapping.dart';
import 'package:test/test.dart';

main() {
  LinkedMapping mapping;

  File _file(String file) {
    return File('test/res/linked_mapping/$file');
  }

  void _compareEntries(LinkedTargetEntry actual, LinkedTargetEntry expected) {
    expect(actual.line, expected.line);
    expect(actual.column, expected.column);
    expect(actual.sourceLine, expected.sourceLine);
    expect(actual.sourceColumn, expected.sourceColumn);
    expect(actual.sourceUrl, expected.sourceUrl);
  }

  setUpAll(() {
    var file = _file('sourcemap.js.map');
    var map = file.readAsStringSync();
    mapping = LinkedMapping(map, file.uri);
  });

  group('LinkedMapping_initialised_', () {
    test('correctLineAndEntryCounts', () {
      var lines = mapping.lines;
      expect(lines.map((entry) => entry.line), [1, 2, 3, 7]);
      expect(lines.map((entry) => entry.entries.length), [2, 1, 5, 3]);
    });

    test('correctEntryValues', () {
      var lines = mapping.lines;
      var source1Url = 'test/res/linked_mapping/source1.dart';
      var source2Url = 'test/res/linked_mapping/source2.dart';
      _compareEntries(lines[0].entries[0],
          LinkedTargetEntry(lines[0], 32, 1, 7, source1Url));
      _compareEntries(lines[0].entries[1],
          LinkedTargetEntry(lines[0], 52, 1, 15, source1Url));
      _compareEntries(lines[1].entries[0],
          LinkedTargetEntry(lines[1], 8, 2, 48, source1Url));
      _compareEntries(lines[2].entries[0],
          LinkedTargetEntry(lines[2], 26, 4, 5, source1Url));
      _compareEntries(lines[2].entries[1],
          LinkedTargetEntry(lines[2], 30, 4, 18, source1Url));
      _compareEntries(lines[2].entries[2],
          LinkedTargetEntry(lines[2], 53, 4, 29, source1Url));
      _compareEntries(lines[2].entries[3],
          LinkedTargetEntry(lines[2], 76, 5, 14, source1Url));
      _compareEntries(lines[2].entries[4],
          LinkedTargetEntry(lines[2], 89, 5, 28, source1Url));
      _compareEntries(lines[3].entries[0],
          LinkedTargetEntry(lines[3], 12, 3, 18, source2Url));
      _compareEntries(lines[3].entries[1],
          LinkedTargetEntry(lines[3], 21, 3, 49, source2Url));
      _compareEntries(lines[3].entries[2],
          LinkedTargetEntry(lines[3], 48, 3, 55, source2Url));
    });

    test('correctLineChaining', () {
      var lines = mapping.lines;
      expect(lines[0].previous, null);
      expect(lines[0].next, lines[1]);
      expect(lines[1].previous, lines[0]);
      expect(lines[1].next, lines[2]);
      expect(lines[2].previous, lines[1]);
      expect(lines[2].next, lines[3]);
      expect(lines[3].previous, lines[2]);
      expect(lines[3].next, null);
    });

    test('correctEntryChaining', () {
      var lines = mapping.lines;
      expect(lines[0].entries[0].previous, null);
      expect(lines[0].entries[0].next, lines[0].entries[1]);
      expect(lines[0].entries[1].previous, lines[0].entries[0]);
      expect(lines[0].entries[1].next, lines[1].entries[0]);
      expect(lines[1].entries[0].previous, lines[0].entries[1]);
      expect(lines[1].entries[0].next, lines[2].entries[0]);
      expect(lines[2].entries[0].previous, lines[1].entries[0]);
      expect(lines[2].entries[0].next, lines[2].entries[1]);
      expect(lines[2].entries[1].previous, lines[2].entries[0]);
      expect(lines[2].entries[1].next, lines[2].entries[2]);
      expect(lines[2].entries[2].previous, lines[2].entries[1]);
      expect(lines[2].entries[2].next, lines[2].entries[3]);
      expect(lines[2].entries[3].previous, lines[2].entries[2]);
      expect(lines[2].entries[3].next, lines[2].entries[4]);
      expect(lines[2].entries[4].previous, lines[2].entries[3]);
      expect(lines[2].entries[4].next, lines[3].entries[0]);
      expect(lines[3].entries[0].previous, lines[2].entries[4]);
      expect(lines[3].entries[0].next, lines[3].entries[1]);
      expect(lines[3].entries[1].previous, lines[3].entries[0]);
      expect(lines[3].entries[1].next, lines[3].entries[2]);
      expect(lines[3].entries[2].previous, lines[3].entries[1]);
      expect(lines[3].entries[2].next, null);
    });
  });

  group('entryFor_', () {
    test('beforeFirstLine_null', () {
      expect(mapping.entryFor(0, 0), null);
    });

    test('firstLineBeforeFirstEntry_null', () {
      expect(mapping.entryFor(1, 0), null);
    });

    test('afterLastLine_lastEntry', () {
      expect(mapping.entryFor(10, 0), mapping.lines.last.entries.last);
    });

    test('lastLineAfterLastEntry_lastEntry', () {
      expect(mapping.entryFor(7, 50), mapping.lines.last.entries.last);
    });

    test('beforeFirstEntryOnLine_lastEntryOfPreviousLine', () {
      expect(mapping.entryFor(7, 0), mapping.lines[2].entries.last);
    });

    test('betweenLines_lastEntryOfPreviousLine', () {
      expect(mapping.entryFor(5, 0), mapping.lines[2].entries.last);
    });

    test('betweenEntriesOnLine_previousEntry', () {
      expect(mapping.entryFor(3, 40), mapping.lines[2].entries[1]);
    });

    test('exactEntryPosition_entryAtPosition', () {
      expect(mapping.entryFor(3, 53), mapping.lines[2].entries[2]);
    });
  });
}
