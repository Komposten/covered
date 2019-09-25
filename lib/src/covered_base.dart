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
import 'package:covered/src/test_parser.dart';
import 'package:covered/src/tester.dart';
import 'package:covered/src/testinfo.dart';
import 'package:covered/src/utilities.dart';
import 'package:covered/src/vm_tester.dart';
import 'package:path/path.dart' as path;

Future<void> collectTestCoverage(
    List<String> platforms, bool printTestOutput, List<String> testArgs) async {
  stdout.writeln('Searching for test files...');
  var tests = await _getTestFiles();
  stdout.writeln('>> ${tests.length} test files found!');
  await Future.forEach(platforms, (platform) async {
    stdout.writeln(
        '\nRunning tests and coverage analysis for platform \'$platform\'...');
    await _testAndCollect(platform, testArgs, tests, printTestOutput);
  });
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

Future<void> _testAndCollect(String platform, List<String> testArgs,
    List<TestInfo> tests, bool printTestOutput) async {
  tests = tests
      .where((test) =>
          test.testOn.isEmpty || testOnPlatform(test.testOn, platform))
      .toList();
  var workingDir = Directory.current.path;
  Tester tester;

  if (platform == 'vm') {
    tester = VmTester(workingDir);
  } else if (platform == 'chrome') {
    tester = ChromeTester(workingDir);
  } else {
    throw ArgumentError('Unsupported testing platform: $platform');
  }

  await tester.testAndCollect(testArgs, tests, printTestOutput);
}
