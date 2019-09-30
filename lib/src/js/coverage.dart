import 'dart:convert';
import 'dart:io';

import 'package:covered/src/js/range.dart';
import 'package:covered/src/js/range_list.dart';
import 'package:path/path.dart' as path;

Future<String> analyseJsCoverage(File coverageFile, File testEntrypoint,
    File jsSourceMap, String projectRoot) async {
  var jsCoverage = json.decode(await coverageFile.readAsString());
  var functions =
      await _getRelevantFunctions(testEntrypoint, jsSourceMap, projectRoot);

  RangeList rangeList = _buildRangeList(jsCoverage);

  var covered = 0;
  var total = 0;
  //TODO(komposten): Temporary output
  var file = File('$projectRoot/.covered/internal/js_reports/ranges.txt');
  var sink = file.openWrite();
  for (var range in rangeList.list) {
    if (range.covered) {
      covered += range.end - range.start;
    }
    total += range.end - range.start;

    if (range.covered) {
      sink.writeln('[covered]   ${range.start}>${range.end}');
    } else {
      sink.writeln('[uncovered] ${range.start}>${range.end}');
    }
  }
  await sink.close();

  return 'Coverage: ${covered}/${total} (${(covered / total * 100).toStringAsFixed(1)} %)';
}

Future<List<FunctionInfo>> _getRelevantFunctions(
    File entrypoint, File jsSourceMap, String projectRoot) async {
  var files = await _getRelevantFiles(jsSourceMap, projectRoot);
  //TODO(komposten): WIP
  return [];
}

Future<List<File>> _getRelevantFiles(
    File jsSourceMap, String projectRoot) async {
  var sources = json.decode(await jsSourceMap.readAsString())['sources'];
  var result = <File>[];
  for (var source in sources) {
    source = path.join('.covered', 'internal', 'chrome', source);
    source = path.normalize(source);
    if (path.isWithin(projectRoot, source) && !source.contains('.covered')) {
      result.add(File(source));
    }
  }

  return result;
}

RangeList _buildRangeList(jsCoverage) {
  //TODO(komposten): Filter using the functions list.
  var rangeList = RangeList();
  jsCoverage['functions'].forEach((function) {
    function['ranges'].forEach((range) {
      var start = range['startOffset'];
      var end = range['endOffset'];
      var isCovered = range['count'] != 0;

      rangeList.add(Range(start, end, isCovered));
    });
  });
  return rangeList;
}

class FunctionInfo {
  final String name;
  final String inClass;

  FunctionInfo(this.name, this.inClass);
}
