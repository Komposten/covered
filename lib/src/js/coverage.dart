import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:covered/src/js/linked_mapping.dart';
import 'package:covered/src/js/range.dart';
import 'package:covered/src/js/range_list.dart';
import 'package:covered/src/js/utilities.dart';
import 'package:path/path.dart' as path;

/*TODO(komposten): Rewrite this as a class so some function parameters can be
   stored as instance variables
 */
Future<String> analyseJsCoverage(File coverageFile, File jsEntrypoint,
    File jsSourceMap, String projectRoot) async {
  var jsCoverage = json.decode(await coverageFile.readAsString());
  RangeList rangeList = _buildRangeList(jsCoverage);
  List<MappedRange> mappedList =
      await _mapRangesToDart(rangeList, jsEntrypoint, jsSourceMap);
  _filterMappedList(mappedList, projectRoot);

  return _toLcov(mappedList);
}

RangeList _buildRangeList(jsCoverage) {
  var rangeList = RangeList();
  var functionCount = jsCoverage['functions'].length;
  var index = 0;
  Set<String> functionNames = {};

  jsCoverage['functions'].forEach((function) {
    _printProgress(index++, 100, functionCount, 'Compiling covered ranges');
    var functionName = function['functionName'];
    functionName = _getUniqueName(functionName, functionNames);

    function['ranges'].forEach((range) {
      var start = range['startOffset'];
      var end = range['endOffset'];
      var isCovered = range['count'] != 0;

      rangeList.add(Range(functionName, start, end, isCovered));
    });
  });

  _printProgress(functionCount, 100, functionCount, 'Compiling covered ranges');
  return rangeList;
}

String _getUniqueName(String name, Set<String> existingNames) {
  var newName = name;
  var i = 0;
  while (existingNames.contains(newName)) {
    newName = name + '\$$i';
    i++;
  }

  existingNames.add(newName);
  return newName;
}

Future<List<MappedRange>> _mapRangesToDart(
    RangeList rangeList, File jsEntrypoint, File jsSourceMap) async {
  var entrypointRaw = await jsEntrypoint.readAsString();
  var mapping =
      LinkedMapping(await jsSourceMap.readAsString(), jsSourceMap.uri);
  List<MappedRange> result = [];
  var offsetConverter = OffsetToLineConverter(entrypointRaw);

  var index = 0;
  for (var range in rangeList.list) {
    _printProgress(
        index++, 100, rangeList.list.length, 'Mapping JS coverage to Dart');

    //Convert the range start and end offsets to line-column pairs.
    var startLine = offsetConverter.getLine(range.start);
    var endLine = offsetConverter.getLine(range.end);
    var startCol = offsetConverter.getColumn(range.start);
    var endCol = offsetConverter.getColumn(range.end);

    var startPosition = mapping.entryFor(startLine, startCol);
    var endPosition = mapping.entryFor(endLine, endCol);

    if (endPosition != null) {
      if (startPosition == null) {
        startPosition = mapping.lines.first.entries.first;
      } else if (startPosition.next != null && startPosition != endPosition) {
        startPosition = startPosition.next;
      }
      /* FIXME(komposten): Temp4's someValue and otherValue are still marked as covered.
          Is this because the true "not covered" coverage is missed, or because
          of the merging of line data (see FileCoverage)?
       */

      while (startPosition.sourceUrl != endPosition.sourceUrl) {
        startPosition = startPosition.next;
      }

      var mappedRange = MappedRange(
          range,
          startPosition.sourceUrl,
          startPosition.sourceLine,
          startPosition.sourceColumn,
          endPosition.sourceLine,
          endPosition.sourceColumn);

      result.add(mappedRange);
    }
  }

  _printProgress(rangeList.list.length, 100, rangeList.list.length,
      'Mapping JS coverage to Dart');

  return result;
}

void _printProgress(int index, int interval, int count, String text) {
  if (index == 0) {
    print('');
  } else if (index == count) {
    stdout.write('\u001b[F>>>> $text: Complete!\n');
  } else if (index % interval == 0) {
    stdout.write(
        '\u001b[F>>>> $text: ${((index + 1) / count * 100).toStringAsFixed(1)} %\n');
  }
}

void _filterMappedList(List<MappedRange> mappedList, String projectRoot) {
  mappedList.removeWhere((range) {
    var dartFile = path.normalize(range.dartFile);
    var isProjectFile = (path.isWithin(projectRoot, dartFile) &&
        !dartFile.contains('.covered'));
    return !isProjectFile;
  });
}

String _toLcov(List<MappedRange> mappedList) {
  Map<String, FileCoverage> fileCoverages = {};

  for (var mappedRange in mappedList) {
    var filePath = mappedRange.dartFile;
    var startLine = mappedRange.startLine;
    var endLine = mappedRange.endLine;

    var fileCoverage =
        fileCoverages.putIfAbsent(filePath, () => FileCoverage(filePath));
    for (int i = startLine; i <= endLine; i++) {
      fileCoverage.addLine(i, mappedRange.range.covered, mappedRange.range);
    }
  }

  var buffer = StringBuffer();
  for (var coverage in fileCoverages.values) {
    var coveredLines = 0;

    buffer.writeln('SF:${coverage.path}');

    for (var line in coverage.lines.entries) {
      var lineNumber = line.key + 1;
      var covered = line.value['covered'] ? 1 : 0;
      buffer.writeln('DA:$lineNumber,$covered');
      coveredLines += covered;
    }

    buffer.writeln('LF:${coverage.lines.length}');
    buffer.writeln('LH:$coveredLines');
    buffer.writeln('end_of_record');
  }

  return buffer.toString();
}

class FunctionInfo {
  final String name;
  final String className;
  final String namespace;
  final int startIndex;

  FunctionInfo(this.name, this.className, this.namespace, this.startIndex);
}

class MappedRange {
  final Range range;
  final String dartFile;
  final int startLine;
  final int startColumn;
  final int endLine;
  final int endColumn;

  MappedRange(this.range, this.dartFile, this.startLine, this.startColumn,
      this.endLine, this.endColumn);
}

class FileCoverage {
  final String path;
  Map<int, Map<String, dynamic>> _lines = LinkedHashMap();

  FileCoverage(this.path);

  void addLine(int lineNumber, bool covered, Range owner) {
    var previous = _lines[lineNumber];

    var relation = previous == null
        ? _compare(null, owner)
        : _compare(previous['owner'], owner);

    if (relation == -1) {
      _lines[lineNumber] = {'owner': owner, 'covered': covered};
    } else if (relation == 0 && previous['covered'] == false) {
      _lines[lineNumber] = {'owner': owner, 'covered': covered};
    }
  }

  int _compare(Range first, Range second) {
    if (first == null) {
      return -1;
    } else if (first == second) {
      return 0;
    } else if (second.start >= first.start && second.end <= first.end) {
      return -1;
    } else if (first.start >= second.start && first.end <= second.end) {
      return 1;
    } else {
      Function printR =
          (Range r) => print('${r.group}[${r.start}:${r.end}] -- ${r.covered}');
      printR(first);
      printR(second);
      return 0;
    }
  }

  Map<int, Map<String, dynamic>> get lines => _lines;
}
