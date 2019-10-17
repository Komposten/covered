/*
 * Copyright 2019 Jakob Hjelm (Komposten)
 *
 * This file is part of covered.
 *
 * covered is a free Dart library: you can use, redistribute it and/or modify
 * it under the terms of the MIT license as written in the LICENSE file in the root
 * of this project.
 */
import 'dart:io';

import 'package:covered/src/output.dart';
import 'package:covered/src/testinfo.dart';
import 'package:covered/src/utilities.dart';
import 'package:path/path.dart' as path;

abstract class Tester {
  final String projectDir;
  final int port;
  final String platform;
  final List<String> reportOn;

  String get outputDir => path.join(projectDir, '.covered');

  String get internalDir => path.join(outputDir, 'internal');

  String get reportsDir => path.join(outputDir, 'reports');

  Tester(this.projectDir, int port, this.platform, List<String> reportOn)
      : this.port = port ?? 8787,
        this.reportOn = List.unmodifiable((reportOn != null
            ? reportOn.map((path) => fixPathSeparators(path))
            : []));

  Future<File> testAndCollect(List<String> testArgs, List<TestInfo> tests,
      Output testOutputLevel) async {
    var testFile = await _buildTestEntryPoint(tests);
    var coverageFile = await runTestsAndCollect(testFile, testOutputLevel);

    stdout.writeln(
        '>> $platform coverage report written to ${coverageFile.absolute.path}');

    return coverageFile;
  }

  Future<File> _buildTestEntryPoint(List<TestInfo> tests) async {
    var file = File(path.join(internalDir, '${platform}_entrypoint.dart'));
    var output = StringBuffer();
    var usedNames = <String>{};

    var data = tests.map((test) {
      var uri = test.file.absolute.uri;
      var name = path.basenameWithoutExtension(test.file.path);
      name = getUniqueName(name, usedNames, sep: '_');

      return {'uri': uri.toString(), 'name': name};
    }).toList();

    output.writeln('import \'package:test/test.dart\';');
    data.forEach(
        (e) => output.writeln('import \'${e['uri']}\' as ${e['name']};'));
    output.writeln('\nvoid main() {');
    data.forEach((e) => output
        .writeln('\tgroup(\'${e['name']}\', () => ${e['name']}.main());'));
    output.writeln('}');

    await file.create(recursive: true);
    await file.writeAsString(output.toString());
    return file;
  }

  Future<File> runTestsAndCollect(File entrypoint, Output printTestOutput);
}
