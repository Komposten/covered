/*
 * Copyright 2019 Jakob Hjelm (Komposten)
 *
 * This file is part of covered.
 *
 * covered is a free Dart library: you can use, redistribute it and/or modify
 * it under the terms of the MIT license as written in the LICENSE file in the root
 * of this project.
 */
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:covered/src/js/data/linked_mapping.dart';
import 'package:covered/src/js/data/range.dart';
import 'package:covered/src/js/data/range_list.dart';
import 'package:covered/src/js/util/utilities.dart' as js_utils;
import 'package:covered/src/util/utilities.dart' as utils;
import 'package:covered/src/util/utilities.dart';
import 'package:path/path.dart' as path;

/*TODO(komposten): Rewrite this as a class so some function parameters can be
   stored as instance variables
 */
Future<String> analyseJsCoverage(File coverageFile, File jsEntrypoint,
    File jsSourceMap, String projectRoot, List<String> reportOn) async {
  var jsCoverage = json.decode(await coverageFile.readAsString());
  RangeList rangeList = _buildRangeList(jsCoverage);
  List<MappedRange> mappedList =
      await _mapRangesToDart(rangeList, jsEntrypoint, jsSourceMap);
  _filterMappedList(mappedList, projectRoot, reportOn);

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
    functionName = getUniqueName(functionName, functionNames);

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

Future<List<MappedRange>> _mapRangesToDart(
    RangeList rangeList, File jsEntrypoint, File jsSourceMap) async {
  var entrypointRaw = await jsEntrypoint.readAsString();
  var mapping =
      LinkedMapping(await jsSourceMap.readAsString(), jsSourceMap.uri);
  List<MappedRange> result = [];
  var offsetConverter = js_utils.OffsetToLineConverter(entrypointRaw);

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

      if (mappedRange.isNotEmpty) {
        result.add(mappedRange);
      }
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

void _filterMappedList(
    List<MappedRange> mappedList, String projectRoot, List<String> reportOn) {
  var dotCovered = path.join(projectRoot, '.covered');

  mappedList.removeWhere((range) {
    var dartFile = path.normalize(range.dartFile);
    if (reportOn.isEmpty) {
      var isProjectFile = (path.isWithin(projectRoot, dartFile) &&
          !path.isWithin(dotCovered, dartFile));
      return !isProjectFile;
    } else {
      var shouldReportOn = reportOn
          .any((p) => path.isWithin(p, dartFile) || path.equals(p, dartFile));
      return !shouldReportOn;
    }
  });
}

String _toLcov(List<MappedRange> mappedList) {
  Map<String, FileCoverage> fileCoverages = {};

  for (var mappedRange in mappedList) {
    var filePath = utils.fixPathSeparators(mappedRange.dartFile);
    var startLine = mappedRange.startLine;
    var endLine = mappedRange.endLine;

    var fileCoverage =
        fileCoverages.putIfAbsent(filePath, () => FileCoverage(filePath));
    for (int i = startLine; i <= endLine; i++) {
      fileCoverage.addLine(i, mappedRange);
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

  bool get isNotEmpty => (endLine > startLine || endColumn > startColumn);

  bool contains(MappedRange other) {
    bool startsInside = other.startLine > startLine ||
        (other.startLine == startLine && other.startColumn >= startColumn);
    bool endsInside = other.endLine < endLine ||
        (other.endLine == endLine && other.endColumn <= endColumn);
    return startsInside && endsInside;
  }
}

class FileCoverage {
  final String path;
  Map<int, Map<String, dynamic>> _lines = LinkedHashMap();

  FileCoverage(this.path);

  void addLine(int lineNumber, MappedRange owner) {
    var previous = _lines[lineNumber];

    var relation = previous == null
        ? _compare(null, owner)
        : _compare(previous['owner'], owner);

    if (relation == -1) {
      _lines[lineNumber] = {'owner': owner, 'covered': owner.range.covered};
    } else if (relation == 0 && previous['covered'] == false) {
      // We end up here if several ranges occur beside each other on the same line.
      // In that case, treat the entire line as covered if at least one of the
      // ranges has been covered.
      // This is to be consistent with how the coverage package handles VM coverage.
      _lines[lineNumber] = {'owner': owner, 'covered': owner.range.covered};
    }
  }

  int _compare(MappedRange first, MappedRange second) {
    if (first == null) {
      return -1;
    } else if (first == second) {
      return 0;
    } else if (first.contains(second)) {
      return -1;
    } else if (second.contains(first)) {
      return 1;
    } else {
      return 0;
    }
  }

  Map<int, Map<String, dynamic>> get lines => _lines;
}
