import 'dart:convert';
import 'dart:io';

import 'package:covered/src/js/range.dart';
import 'package:covered/src/js/range_list.dart';
import 'package:path/path.dart' as path;

/*TODO(komposten): Rewrite this as a class so some function parameters can be
   stored as instance variables
 */
Future<String> analyseJsCoverage(File coverageFile, File jsEntrypoint,
    File jsSourceMap, String projectRoot) async {
  var jsCoverage = json.decode(await coverageFile.readAsString());
  var functions = await _getRelevantFunctions(
      jsEntrypoint, jsSourceMap, projectRoot, jsCoverage);

  RangeList rangeList = _buildRangeList(jsCoverage, functions);

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

Future<List<FunctionInfo>> _getRelevantFunctions(File jsEntrypoint,
    File jsSourceMap, String projectRoot, dynamic coverageData) async {
  print('>>>> Finding relevant source files...');
  var files = await _getRelevantFiles(jsSourceMap, projectRoot);
  var jsEntrypointRaw = await jsEntrypoint.readAsString();

  print('>>>> Mapping JS functions...');
  var nsToLibMap = _loadNamespaceToLibraryMap(jsEntrypointRaw);
  if (nsToLibMap == null) {
    throw 'Couldn\'t load namespace map from JS entrypoint file!';
  }

  await File('.covered/internal/nsToLib.txt')
      .writeAsString(nsToLibMap.toString());

  var functionList = <FunctionInfo>[];
  var functionCount = coverageData['functions'].length;
  var index = 0;
  coverageData['functions'].forEach((function) {
    if (index++ % 100 == 0) {
      stdout.write(
          '\u001b[100D>>>> Progress: ${((index + 1) / functionCount * 100).toStringAsFixed(1)} %');
    }

    var name = function['functionName'];
    if (name.toString().isNotEmpty) {
      var definitionStart = getFunctionStart(function);

      var namespace = _findNamespace(definitionStart, name, jsEntrypointRaw);

      if (namespace != null) {
        if (_namespaceInFileList(namespace['namespace'], files, nsToLibMap)) {
          functionList.add(FunctionInfo(name, namespace['class'],
              namespace['namespace'], definitionStart));
        }
      }
    }
  });
  print('');

  return functionList;
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

Map<String, String> _loadNamespaceToLibraryMap(String jsEntrypoint) {
  var startIndex = jsEntrypoint.indexOf('dart.trackLibraries("entrypoint", {');

  if (startIndex != -1) {
    startIndex += 35;
    var endIndex = jsEntrypoint.indexOf('}, {', startIndex);
    var mappings = jsEntrypoint.substring(startIndex, endIndex).split('\n');
    var result = <String, String>{};

    mappings.forEach((mapping) {
      var colonIndex = mapping.lastIndexOf(':');

      if (colonIndex != -1) {
        var library = mapping.substring(0, colonIndex).trim();
        var namespace = mapping.substring(colonIndex + 1).trim();

        library = _unescape(library.substring(1, library.length - 1));
        if (namespace.endsWith(',')) {
          namespace = namespace.substring(0, namespace.length - 1);
        }

        result[namespace] = library;
      }
    });

    return result;
  }

  return null;
}

String _unescape(String string) {
  for (int i = 0; i < string.length - 1; i++) {
    if (string[i] == r'\' && string[i + 1] == r'\') {
      string = string.substring(0, i) + string.substring(i + 1);
    }
  }

  return string;
}

int getFunctionStart(Map<String, dynamic> functionData) {
  int lowest;

  functionData['ranges'].forEach((range) {
    if (lowest == null || range['startOffset'] < lowest) {
      lowest = range['startOffset'];
    }
  });

  return lowest;
}

Map<String, String> _findNamespace(
    int functionStart, String functionName, String jsEntrypoint) {
  /* TODO(komposten): Relevant notes on entrypoint.js:
      dart.trackLibraries -> maps library/file uri to JS namespace.
      dart.setLibraryUri -> maps JS namespace.class to library/file uri.
                            only applies to classes and not top-level functions
   */

  /* TODO(komposten): Currently doesn't support top-level getters and setters!
      Should be easy enough since in the JS these are defined as:
       dart.copyProperties(namespace, { get functionName() ... });
   */
  /* TODO(komposten): Currently doesn't support constructors!
      These appear as `(functionName = function(...) { /*code*/ })`
       where 'functionName' is 'namespace.Class.new'.
      This cannot use the same class-matching as for normal methods, since it's
       defined outside of the `namespace.class = Class extends ... {}` block!
      .
      NOTE: Must also check how named constructors (e.g. ClassName.fromString)
       and factory constructors get translated to JS!
   */
  var escapedName = RegExp.escape(functionName);
  var patternClass = r'(?:([^\s-]+) = class [^\s-]+ extends)';
  var patternFunction = '(?:[^\\s-]+ = function $escapedName)';
  var pattern =
      RegExp(r'([^\s]+)\.(?:' + patternClass + '|' + patternFunction + ')');

  var namespaceRegionEnd = _findNamespaceRegionEnd(functionStart, jsEntrypoint);
  var namespaceRegionStart =
      _findNamespaceRegionStart(namespaceRegionEnd, jsEntrypoint);
  var matches = pattern.allMatches(
      jsEntrypoint.substring(namespaceRegionStart, namespaceRegionEnd));

  if (matches.isNotEmpty) {
    var match = matches.last;
    return {'namespace': match.group(1), 'class': match.group(2)};
  } else {
    return null;
  }
}

int _findNamespaceRegionEnd(int functionStart, String coverageJson) {
  var stringPattern = RegExp('"|\'|`');

  var afterStart = coverageJson.substring(functionStart);
  if (afterStart.startsWith('() ')) {
    // If functionStart is followed by '= ' we know it's a built-in method or an
    // otherwise uninteresting definition.
    // These appear e.g. near the top of the JS file as 'let functionName = () => ...'
    return 0;
  } else if (afterStart.startsWith('function')) {
    return coverageJson.indexOf('(', functionStart);
  } else {
    int braceDepth = 0;
    bool inString = false;
    String stringChar;

    for (var i = functionStart; i >= 0; i--) {
      var char = coverageJson[i];

      if (!inString) {
        if (char == '{') {
          braceDepth--;
        } else if (char == '}') {
          braceDepth++;
        } else if (stringPattern.hasMatch(char)) {
          inString = true;
          stringChar = char;
        }

        if (braceDepth == -1) {
          return i;
        }
      } else if (char == stringChar) {
        //TODO(komposten): This doesn't support escaped stringChars.
        // Probably don't need to worry about interpolated strings since dartdevc
        // doesn't appear to use that yet.
        inString = false;
      }
    }
  }

  return 0;
}

_findNamespaceRegionStart(int namespaceRegionEnd, String coverageJson) {
  var spaces = 0;
  for (int i = namespaceRegionEnd; i >= 0; i--) {
    if (coverageJson[i] == ' ' && ++spaces == 10) {
      return i;
    }
  }

  return 0;
}

bool _namespaceInFileList(
    String namespace, List<File> files, Map<String, String> nsToLibMap) {
  var library = nsToLibMap[namespace];

  if (library != null) {
    if (library.startsWith('package:')) {
      library = library.substring(library.indexOf(RegExp(r'[\\/]')) + 1);
    }

    var libraryFile = path.fromUri(path.toUri(library));

    var match = files.firstWhere(
        (file) => path.fromUri(path.toUri(file.path)).endsWith(libraryFile),
        orElse: () => null);
    return match != null;
  } else {
    return false;
  }
}

RangeList _buildRangeList(jsCoverage, List<FunctionInfo> functions) {
  Function functionId = (name, index) => '$name@$index';

  Map<String, FunctionInfo> functionMap = {};
  functions.forEach((function) =>
      functionMap[functionId(function.name, function.startIndex)] = function);

  print('Valid functions: ${functionMap.keys}');

  var rangeList = RangeList();
  jsCoverage['functions'].forEach((function) {
    var id = functionId(function['functionName'], getFunctionStart(function));
    if (functionMap.containsKey(id)) {
      print('Function ID valid: $id');
      var functionInfo = functionMap[id];
      function['ranges'].forEach((range) {
        var start = range['startOffset'];
        var end = range['endOffset'];
        var isCovered = range['count'] != 0;

        rangeList.add(Range(functionInfo, start, end, isCovered));
      });
    }
  });
  return rangeList;
}

class FunctionInfo {
  final String name;
  final String className;
  final String namespace;
  final int startIndex;

  FunctionInfo(this.name, this.className, this.namespace, this.startIndex);
}
