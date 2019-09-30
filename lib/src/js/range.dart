import 'dart:math';

class Range {
  final int start;
  final int end;
  final bool covered;

  Range(this.start, this.end, this.covered);

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
        return [
          Range(coveredRange.start, uncoveredRange.start - 1, true),
          Range(uncoveredRange.start, uncoveredRange.end, false),
          Range(uncoveredRange.end + 1, coveredRange.end, true)
        ];
      } else if (uncoveredRange._contains(coveredRange.start)) {
        return [
          Range(uncoveredRange.start, uncoveredRange.end, false),
          Range(uncoveredRange.end + 1, coveredRange.end, true)
        ];
      } else {
        return [
          Range(coveredRange.start, uncoveredRange.start - 1, true),
          Range(uncoveredRange.start, uncoveredRange.end, false)
        ];
      }
    }
  }

  bool overlaps(Range other) {
    return _contains(other.start) ||
        _contains(other.end) ||
        other._contains(start) ||
        other._contains(end);
  }

  bool _contains(num value) {
    return value >= start && value <= end;
  }

  Range _mergeWith(Range other) {
    return Range(min(start, other.start), max(end, other.end), covered);
  }

  void _assertOverlaps(Range other) {
    if (!overlaps(other)) {
      throw ArgumentError('Can only merge overlapping ranges');
    }
  }
}
