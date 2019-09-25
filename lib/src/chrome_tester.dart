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
import 'dart:io';

import 'package:covered/src/tester.dart';
import 'package:path/path.dart' as path;
import 'package:resource/resource.dart';

class ChromeTester extends Tester {
  ChromeTester(String projectDir) : super(projectDir, 'chrome');

  @override
  Future<File> runTestsAndCollect(File entrypoint, bool printTestOutput) async {
    var htmlFile = await _transpileToJS(entrypoint);
    return File(reportsDir);
  }

  Future<File> _transpileToJS(File entrypoint) async {
    var outputFile = File(path.relative(
        path.join(internalDir, 'chrome', 'entrypoint.js'),
        from: projectDir));
    await outputFile.create(recursive: true);
    final dart2jsArgs = [
      '--enable-asserts',
      '--out=${outputFile.path}',
      path.relative(entrypoint.absolute.path, from: projectDir)
    ];

    var processName = (Platform.isWindows ? 'dart2js.bat' : 'dart2js');
    var process = await Process.start(processName, dart2jsArgs,
        workingDirectory: projectDir);
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stdout.writeln('>> $line');
    });
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stderr.writeln('>> $line');
    });

    var exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw 'dart2js failed with exit code $exitCode';
    }

    return await _copyHtmlFile();
  }

  Future<File> _copyHtmlFile() async {
    var target = File(path.join(internalDir, 'chrome', 'index.html'));
    var source = Resource('package:covered/res/chrome-template.html');

    return target.writeAsString(await source.readAsString());
  }
}
