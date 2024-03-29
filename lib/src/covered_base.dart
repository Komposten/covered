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

import 'package:covered/src/util/lcov.dart';
import 'package:covered/src/util/output.dart';
import 'package:covered/src/parsing/test_parser.dart';
import 'package:covered/src/parsing/testinfo.dart';
import 'package:covered/src/testers/chrome_tester.dart';
import 'package:covered/src/testers/tester.dart';
import 'package:covered/src/testers/vm_tester.dart';
import 'package:covered/src/util/utilities.dart';
import 'package:lcov/lcov.dart';
import 'package:path/path.dart' as path;

Future<bool> collectTestCoverage(
    List<String> platforms,
    int port,
    Output testOutputLevel,
    bool headless,
    List<String> reportOn,
    List<String> testArgs) async {
  stdout.writeln('Searching for test files...');

  var tests = await _getTestFiles();
  stdout.writeln('>> ${tests.length} test files found!');

  Map<String, File> coverageFiles = {};
  await Future.forEach(platforms, (platform) async {
    stdout.writeln(
        '\nRunning tests and coverage analysis for platform \'$platform\'...');

    File coverageFile = await _testAndCollect(
        platform, port, headless, testArgs, tests, testOutputLevel, reportOn);

    coverageFiles[platform] = coverageFile;
  });

  if (coverageFiles.values.contains(null)) {
    List<String> failures = coverageFiles.entries
        .where((entry) => entry.value == null)
        .map((entry) => entry.key)
        .toList();
    stdout.writeln(
        '\u001b[1;31mCoverage collection failed for the following platforms: $failures\u001b[0m');
    return false;
  } else {
    if (coverageFiles.length > 1) {
      await _mergeCoverage(coverageFiles.values.toList());
    }
    return true;
  }
}

Future<List<TestInfo>> _getTestFiles() async {
  var testRoot = Directory(path.join(Directory.current.path, 'test'));
  var testParser = TestParser();
  var files = await testRoot.list(recursive: true);
  return files
      .where((entity) =>
          entity.path.endsWith('_test.dart') &&
          entity.statSync().type == FileSystemEntityType.file)
      .map(testParser.parse)
      .toList();
}

Future<File> _testAndCollect(
    String platform,
    int port,
    bool headless,
    List<String> testArgs,
    List<TestInfo> tests,
    Output testOutputLevel,
    List<String> reportOn) async {
  tests = tests
      .where((test) =>
          test.testOn.isEmpty || testOnPlatform(test.testOn, platform))
      .toList();
  var workingDir = Directory.current.path;
  Tester tester;

  if (platform == 'vm') {
    tester = VmTester(workingDir, port, reportOn);
  } else if (platform == 'chrome') {
    tester = ChromeTester(workingDir, port, headless, reportOn);
  } else {
    throw ArgumentError('Unsupported testing platform: $platform');
  }

  try {
    return await tester.testAndCollect(testArgs, tests, testOutputLevel);
  } catch (error) {
    stdout.writeln('\u001b[1;31mTesting failed for $platform: $error\u001b[0m');
    if (error is Error) {
      stdout.writeln(error.stackTrace);
    }
    return null;
  }
}

Future<void> _mergeCoverage(List<File> list) async {
  stdout.writeln('\nMerging coverage reports...');

  List<Report> lcovReports =
      list.map((file) => Report.fromCoverage(file.readAsStringSync())).toList();
  Report merged = Lcov.merge(lcovReports);

  var reportFile = File(path.join(
      Directory.current.path, '.covered', 'reports', 'lcov_merged.info'));
  await reportFile.create(recursive: true);
  await reportFile.writeAsString(merged.toString());
  stdout.writeln(
      '>> Merged coverage report written to ${reportFile.absolute.path}');
}
