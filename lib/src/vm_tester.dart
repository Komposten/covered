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
import 'package:covered/src/tester.dart';
import 'package:path/path.dart' as path;

class VmTester extends Tester {
  VmTester(String projectDir) : super(projectDir, 'vm');

  @override
  Future<File> runTestsAndCollect(File entrypoint, bool printTestOutput) async {
    var coverageData = await _runTests(entrypoint, printTestOutput);
    return await _compileCoverageReport(coverageData);
  }

  //This method is heavily inspired by the `test_coverage` package.
  //(https://pub.dev/packages/test_coverage)
  Future<Map<String, dynamic>> _runTests(
      File entrypoint, bool printTestOutput) async {
    Process process = await startTestRunner(entrypoint);

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

      if (printTestOutput) {
        stdout.writeln('>> $line');
      }
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

  Future<Process> startTestRunner(File entrypoint) async {
    final dartArgs = [
      '--pause-isolates-on-exit',
      '--enable_asserts',
      '--enable-vm-service=8787',
      //TODO(komposten): Add a command line option for the port.
      entrypoint.path
    ];

    var process =
        await Process.start('dart', dartArgs, workingDirectory: projectDir);
    return process;
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