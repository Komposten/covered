/*
 * Copyright 2019 Jakob Hjelm (Komposten)
 *
 * This file is part of covered.
 *
 * covered is a free Dart library: you can use, redistribute it and/or modify
 * it under the terms of the MIT license as written in the LICENSE file in the root
 * of this project.
 */
import 'package:collection/collection.dart';
import 'package:covered/src/js/data/range.dart';

class RangeList {
  var _ranges = <Range>[];

  List<Range> get list => _ranges;

  void add(Range range) {
    var overlapping = _ranges.where((r) => r.overlaps(range)).toList();
    var current = range;

    for (var overlapped in overlapping) {
      var ranges = current.resolveOverlap(overlapped);
      var index = _ranges.indexOf(overlapped);
      _ranges.remove(overlapped);
      current = ranges.removeLast();

      for (var newRange in ranges.reversed) {
        _ranges.insert(index, newRange);
      }
    }

    _insert(current);
  }

  void _insert(Range range) {
    var insertionPoint = lowerBound(_ranges, range,
        compare: (Range a, Range b) => a.start.compareTo(b.start));
    _ranges.insert(insertionPoint, range);
  }
}
