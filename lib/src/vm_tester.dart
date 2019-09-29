/*
 * Copyright 2019 Jakob Hjelm (Komposten)
 *
 * This file is part of covered.
 *
 * covered is a free Dart library: you can use, redistribute it and/or modify
 * it under the terms of the MIT license as written in the LICENSE file in the root
 * of this project.
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coverage/coverage.dart' as coverage;
import 'package:covered/src/output.dart';
import 'package:covered/src/tester.dart';
import 'package:path/path.dart' as path;

class VmTester extends Tester {
  final RegExp testLinePattern =
      RegExp(r'\d+(?::\d+)+(?:\s+[+-~]\d+)*\s*:(?:.+)');
  final colourSequencePattern = RegExp(r'.\[\d+m', caseSensitive: true);

  VmTester(String projectDir) : super(projectDir, 'vm');

  @override
  Future<File> runTestsAndCollect(
      File entrypoint, Output testOutputLevel) async {
    var coverageData = await _runTests(entrypoint, testOutputLevel);
    return await _compileCoverageReport(coverageData);
  }

  //This method is heavily inspired by the `test_coverage` package.
  //(https://pub.dev/packages/test_coverage)
  Future<Map<String, dynamic>> _runTests(
      File entrypoint, Output outputLevel) async {
    Process process = await _startTestRunner(entrypoint);

    var uriCompleter = Completer<Uri>();
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (!uriCompleter.isCompleted) {
        final uri = _getObservatoryUri(line);
        if (uri != null) {
          uriCompleter.complete(uri);
        } else {
          uriCompleter.completeError(line);
        }
      }

      _printTestOutput(line, outputLevel);
    });

    var observatoryUri = await uriCompleter.future.catchError((e) {
      process.kill(ProcessSignal.sigkill);
    });

    if (observatoryUri != null) {
      Map<String, dynamic> data;
      try {
        data = await coverage.collect(observatoryUri, true, true, false, {});
      } finally {
        await process.stderr.drain();
      }

      var exitCode = await process.exitCode;
      if (exitCode != 0) {
        throw 'Testing failed with exit code $exitCode';
      }

      return data;
    } else {
      throw StateError(
          'The observatory was not enabled; try using a different port!');
    }
  }

  Future<Process> _startTestRunner(File entrypoint) async {
    final dartArgs = [
      '--pause-isolates-on-exit',
      '--enable_asserts',
      '--enable-vm-service=8787',
      //TODO(komposten): Add a command line option for the port.
      entrypoint.path
    ];

    return await Process.start('dart', dartArgs, workingDirectory: projectDir);
  }

  Uri _getObservatoryUri(String str) {
    final regex = RegExp(r'Observatory listening on ([^\s]+)(?:\s|$)');
    final match = regex.firstMatch(str);
    Uri uri;

    if (match != null) {
      try {
        uri = Uri.parse(match.group(1));
      } on FormatException {
        //invalid uri; return null
      }
    }

    return uri;
  }

  void _printTestOutput(String line, Output level) {
    var line2 = line.replaceAll(colourSequencePattern, '');
    switch (level) {
      case Output.minimal:
        if (testLinePattern.hasMatch(line2)) {
          stdout.writeln('>> $line');
        }
        break;
      case Output.short:
        if (testLinePattern.hasMatch(line2) ||
            line2.startsWith(RegExp(r'\s*(Skip|Expected|Actual):'))) {
          stdout.writeln('>> $line');
        }
        break;
      case Output.verbose:
        stdout.writeln('>> $line');
        break;
      default:
        break;
    }
  }

  Future<File> _compileCoverageReport(Map<String, dynamic> coverageData) async {
    var hitmap = coverage.createHitmap(coverageData['coverage']);
    var resolver = coverage.Resolver(
      packagesPath: path.join(projectDir, '.packages'),
    );
    var formatter = coverage.LcovFormatter(resolver,
        reportOn: ['lib${path.separator}'], basePath: projectDir);
    var data = await formatter.format(hitmap);
    var file = File(path.join(reportsDir, 'lcov_vm.info'));
    await file.create(recursive: true);
    await file.writeAsString(data);

    return file;
  }
}
