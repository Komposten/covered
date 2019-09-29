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
import 'package:path/path.dart' as path;

abstract class Tester {
  final String projectDir;
  final String platform;

  String get outputDir => path.join(projectDir, '.covered');

  String get internalDir => path.join(outputDir, 'internal');

  String get reportsDir => path.join(outputDir, 'reports');

  Tester(this.projectDir, this.platform);

  Future<void> testAndCollect(List<String> testArgs, List<TestInfo> tests,
      Output testOutputLevel) async {
    var testFile = await _buildTestEntryPoint(tests);
    var coverageFile = await runTestsAndCollect(testFile, testOutputLevel);

    stdout.writeln(
        '>> $platform coverage report written to ${coverageFile.path}');
  }

  Future<File> _buildTestEntryPoint(List<TestInfo> tests) async {
    var file = File(path.join(internalDir, '${platform}_entrypoint.dart'));
    var output = StringBuffer();

    var data = tests.map((test) {
      var uri = test.file.absolute.uri;
      var name = path.basenameWithoutExtension(test.file.path);
      return {'uri': uri.toString(), 'name': name};
    });

    data.forEach(
        (e) => output.write('import \'${e['uri']}\' as ${e['name']};\n'));
    output.write('\nvoid main() {\n');
    data.forEach((e) => output.write('\t${e['name']}.main();\n'));
    output.write('}\n');

    await file.create(recursive: true);
    await file.writeAsString(output.toString());
    return file;
  }

  Future<File> runTestsAndCollect(File entrypoint, Output printTestOutput);
}
