/*
 * Copyright 2019 Jakob Hjelm (Komposten)
 *
 * This file is part of covered.
 *
 * covered is a free Dart library: you can use, redistribute it and/or modify
 * it under the terms of the MIT license as written in the LICENSE file in the root
 * of this project.
 */
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:source_maps/source_maps.dart';

class LinkedMapping {
  List<LinkedLineEntry> lines;

  LinkedMapping(String sourceMap, Uri mapUrl) {
    SingleMapping mapping =
        SingleMapping.fromJson(json.decode(sourceMap), mapUrl: mapUrl);
    lines = [];

    LinkedTargetEntry lastEntry;
    for (var line in mapping.lines) {
      var linkedLine = LinkedLineEntry(line.line);
      for (var entry in line.entries) {
        String sourceUrl = _getSourceUrl(mapping, entry, mapUrl);

        var linkedEntry = LinkedTargetEntry(linkedLine, entry.column,
            entry.sourceLine, entry.sourceColumn, sourceUrl);

        if (linkedEntry.sourceColumn != null &&
            linkedEntry.sourceLine != null) {
          if (lastEntry != null) {
            lastEntry._next = linkedEntry;
            linkedEntry._previous = lastEntry;
          }

          linkedLine.entries.add(linkedEntry);
          lastEntry = linkedEntry;
        }
      }

      if (linkedLine.entries.isNotEmpty) {
        if (lines.isNotEmpty) {
          lines.last._next = linkedLine;
          linkedLine._previous = lines.last;
        }

        lines.add(linkedLine);
      }
    }
  }

  String _getSourceUrl(SingleMapping mapping, TargetEntry entry, Uri mapUrl) {
    if (entry.sourceUrlId == null) {
      return null;
    }

    var sourceUrl = mapping.urls[entry.sourceUrlId];
    if (mapping.sourceRoot != null) {
      sourceUrl = '${mapping.sourceRoot}$sourceUrl';

      if (mapUrl != null) {
        sourceUrl = mapUrl.resolve(sourceUrl).path;
      }
    }

    return sourceUrl;
  }

  /// Finds an entry matching the specified position.
  ///
  /// [line] is the zero-based line in the mapped file, and [column] the
  /// zero-based column. If no entry matches exactly [line:column], the previous
  /// entry (possibly on a previous line) will be returned, or [null] if no
  /// previous entry exists.
  LinkedTargetEntry entryFor(int line, int column) {
    var lineEntry = _findLine(line);

    if (lineEntry != null) {
      if (lineEntry.line == line) {
        return _findEntry(lineEntry, column);
      } else {
        return lineEntry.entries.last;
      }
    }

    return null;
  }

  LinkedLineEntry _findLine(int line) {
    if (lines.isNotEmpty) {
      var index = lowerBound(lines, line + 1,
              compare: (lineEntry, lineNumber) =>
                  lineEntry.line.compareTo(lineNumber)) -
          1;

      if (index >= 0) {
        return lines[index];
      }
    }

    return null;
  }

  LinkedTargetEntry _findEntry(LinkedLineEntry line, int column) {
    if (line.entries.isNotEmpty) {
      var index = lowerBound(line.entries, column + 1,
              compare: (entry, column) => entry.column.compareTo(column)) -
          1;

      if (index >= 0) {
        return line.entries[index];
      } else if (line.previous != null) {
        return line.previous.entries.last;
      }
    }

    return null;
  }
}

class LinkedLineEntry {
  final int line;
  final List<LinkedTargetEntry> entries;
  LinkedLineEntry _next;
  LinkedLineEntry _previous;

  LinkedLineEntry get next => _next;

  LinkedLineEntry get previous => _previous;

  LinkedLineEntry(this.line) : entries = [];
}

class LinkedTargetEntry {
  final LinkedLineEntry line;
  final int column;
  final int sourceLine;
  final int sourceColumn;
  final String sourceUrl;
  LinkedTargetEntry _next;
  LinkedTargetEntry _previous;

  LinkedTargetEntry get next => _next;

  LinkedTargetEntry get previous => _previous;

  LinkedTargetEntry(this.line, this.column, this.sourceLine, this.sourceColumn,
      this.sourceUrl);
}
