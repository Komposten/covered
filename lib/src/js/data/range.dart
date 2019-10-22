/*
 * Copyright 2019 Jakob Hjelm (Komposten)
 *
 * This file is part of covered.
 *
 * covered is a free Dart library: you can use, redistribute it and/or modify
 * it under the terms of the MIT license as written in the LICENSE file in the root
 * of this project.
 */
import 'dart:math';

class Range {
  final String group;
  final int start;
  final int end;
  final bool covered;

  Range(this.group, this.start, this.end, this.covered) {
    if (start > end) {
      throw ArgumentError(
          '[start] must be smaller than or equal to [end]: $start > $end');
    }
  }

  List<Range> resolveOverlap(Range other) {
    _assertOverlaps(other);

    if (covered == other.covered) {
      return [_mergeWith(other)];
    } else {
      var coveredRange = (covered ? this : other);
      var uncoveredRange = (covered ? other : this);

      if (uncoveredRange._contains(coveredRange.start) &&
          uncoveredRange._contains(coveredRange.end)) {
        return [uncoveredRange];
      } else if (coveredRange._contains(uncoveredRange.start) &&
          coveredRange._contains(uncoveredRange.end)) {
        List<Range> ranges = [];
        if (coveredRange.start < uncoveredRange.start) {
          ranges.add(
              Range(group, coveredRange.start, uncoveredRange.start - 1, true));
        }
        ranges
            .add(Range(group, uncoveredRange.start, uncoveredRange.end, false));
        if (coveredRange.end > uncoveredRange.end) {
          ranges.add(
              Range(group, uncoveredRange.end + 1, coveredRange.end, true));
        }
        return ranges;
      } else if (uncoveredRange._contains(coveredRange.start)) {
        return [
          Range(group, uncoveredRange.start, uncoveredRange.end, false),
          Range(group, uncoveredRange.end + 1, coveredRange.end, true)
        ];
      } else {
        return [
          Range(group, coveredRange.start, uncoveredRange.start - 1, true),
          Range(group, uncoveredRange.start, uncoveredRange.end, false)
        ];
      }
    }
  }

  bool overlaps(Range other) {
    return group == other.group &&
        (_contains(other.start) ||
            _contains(other.end) ||
            other._contains(start) ||
            other._contains(end));
  }

  bool _contains(num value) {
    return value >= start && value <= end;
  }

  Range _mergeWith(Range other) {
    return Range(group, min(start, other.start), max(end, other.end), covered);
  }

  void _assertOverlaps(Range other) {
    if (!overlaps(other)) {
      throw ArgumentError(
          'Can only merge overlapping ranges from the same group!');
    }
  }
}
