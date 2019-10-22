/*
 * Copyright 2019 Jakob Hjelm (Komposten)
 *
 * This file is part of covered.
 *
 * covered is a free Dart library: you can use, redistribute it and/or modify
 * it under the terms of the MIT license as written in the LICENSE file in the root
 * of this project.
 */
import 'package:lcov/lcov.dart';

class Lcov {
  static Report merge(List<Report> lcovs) {
    var merged = Report();

    Map<String, int> fileOccurrences = {};
    Map<String, Map<int, _LinePair>> lineOccurrences = {};

    for (var lcov in lcovs) {
      for (var record in lcov.records) {
        var oc = fileOccurrences.putIfAbsent(record.sourceFile, () => 0) + 1;
        fileOccurrences[record.sourceFile] = oc;

        var loc = lineOccurrences.putIfAbsent(
            record.sourceFile, () => <int, _LinePair>{});
        for (var line in record.lines.data) {
          var pair = loc.putIfAbsent(line.lineNumber, () => _LinePair());
          pair.occurrances++;
          pair.covered = (line.executionCount > 0 ? true : pair.covered);
        }
      }
    }

    fileOccurrences.removeWhere((name, occurrences) => occurrences < 2);
    fileOccurrences.keys.forEach((file) {
      lineOccurrences[file].removeWhere((line, data) => data.occurrances == 1);
    });

    lineOccurrences.forEach((file, data) {
      var lineData = data.entries.map((entry) =>
          LineData(entry.key, executionCount: entry.value.covered ? 1 : 0));
      var covered = lineData.where((data) => data.executionCount > 0).length;
      var lineCoverage = LineCoverage(lineData.length, covered, lineData);
      var record = Record(file, lines: lineCoverage);
      merged.records.add(record);
    });

    return merged;
  }
}

class _LinePair {
  int occurrances = 0;
  bool covered = false;

  _LinePair();
}
