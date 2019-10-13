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

import 'package:covered/src/chrome_tester.dart';
import 'package:covered/src/output.dart';
import 'package:covered/src/test_parser.dart';
import 'package:covered/src/tester.dart';
import 'package:covered/src/testinfo.dart';
import 'package:covered/src/utilities.dart';
import 'package:covered/src/vm_tester.dart';
import 'package:path/path.dart' as path;

Future<bool> collectTestCoverage(List<String> platforms, Output testOutputLevel,
    bool headless, List<String> testArgs) async {
  stdout.writeln('Searching for test files...');

  var tests = await _getTestFiles();
  stdout.writeln('>> ${tests.length} test files found!');

  List<String> failures = [];
  await Future.forEach(platforms, (platform) async {
    stdout.writeln(
        '\nRunning tests and coverage analysis for platform \'$platform\'...');

    bool success = await _testAndCollect(
        platform, headless, testArgs, tests, testOutputLevel);

    if (!success) {
      failures.add(platform);
    }
  });

  if (failures.isNotEmpty) {
    stdout.writeln('\u001b[1;31mCoverage collection failed for the following platforms: $failures\u001b[0m');
    return false;
  } else {
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

Future<bool> _testAndCollect(String platform, bool headless,
    List<String> testArgs, List<TestInfo> tests, Output testOutputLevel) async {
  tests = tests
      .where((test) =>
          test.testOn.isEmpty || testOnPlatform(test.testOn, platform))
      .toList();
  var workingDir = Directory.current.path;
  Tester tester;

  if (platform == 'vm') {
    tester = VmTester(workingDir);
  } else if (platform == 'chrome') {
    tester = ChromeTester(workingDir, headless);
  } else {
    throw ArgumentError('Unsupported testing platform: $platform');
  }

  try {
    await tester.testAndCollect(testArgs, tests, testOutputLevel);
    return true;
  } catch (error) {
    stdout.writeln('\u001b[1;31mTesting failed for $platform: $error\u001b[0m');
    if (error is Error) {
      stdout.writeln(error.stackTrace);
    }
    return false;
  }
}
