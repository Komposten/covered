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

import 'package:covered/src/js/coverage.dart' as js_coverage;
import 'package:covered/src/util/output.dart';
import 'package:covered/src/testers/tester.dart';
import 'package:path/path.dart' as path;
import 'package:resource/resource.dart';

class ChromeTester extends Tester {
  final bool headless;

  ChromeTester(
      String projectDir, int port, this.headless, List<String> reportOn)
      : super(projectDir, port, 'chrome', reportOn);

  @override
  Future<File> runTestsAndCollect(
      File entrypoint, Output testOutputLevel) async {
    stdout.writeln('>> Running dartdevc...');
    var jsFile = await _transpileToJS(entrypoint);
    var htmlFile = await _copyHtmlFile();
    await _copyJsDependencies();
    var coverageData = await _runTests(htmlFile, jsFile, testOutputLevel);
    return await _compileCoverageReport(
        coverageData, jsFile, File('${jsFile.path}.map'));
  }

  Future<File> _transpileToJS(File entrypoint) async {
    var outputFile = File(path.relative(
        path.join(internalDir, 'chrome', 'entrypoint.js'),
        from: projectDir));
    await outputFile.create(recursive: true);
    final dartdevcArgs = [
      '--enable-asserts',
      '--modules=amd',
      '--out=${outputFile.path}',
      path.relative(entrypoint.absolute.path, from: projectDir)
    ];

    var processName = (Platform.isWindows ? 'dartdevc.bat' : 'dartdevc');
    var process = await Process.start(processName, dartdevcArgs,
        workingDirectory: projectDir);
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line != null &&
          !line.contains(RegExp(r'Hint:|Dart file|<sdk>.+preambles'))) {
        stdout.writeln('>>>> $line');
      }
    });
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stderr.writeln('>>>> $line');
    });

    var exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw 'dartdevc failed with exit code $exitCode';
    }

    return outputFile;
  }

  Future<File> _copyHtmlFile() async {
    var target = File(path.join(internalDir, 'chrome', 'index.html'));
    var source = Resource('package:covered/res/chrome-template.html');

    return target.writeAsString(await source.readAsString());
  }

  Future<void> _copyJsDependencies() async {
    var target = path.join(internalDir, 'chrome');
    var sdkDir = Platform.environment['DART_SDK'];
    var sdkFile =
        File(path.join(sdkDir, 'lib', 'dev_compiler', 'amd', 'dart_sdk.js'));
    var requireFile =
        File(path.join(sdkDir, 'lib', 'dev_compiler', 'amd', 'require.js'));

    await sdkFile.copy(path.join(target, 'dart_sdk.js'));
    await requireFile.copy(path.join(target, 'require.js'));
  }

  Future<File> _runTests(File htmlFile, File jsFile, Output outputLevel) async {
    var htmlPath = htmlFile.absolute.path;
    var jsPath = jsFile.absolute.path;
    var nodeEntrypoint = await _copyNodeEntrypoint();

    stdout.writeln('>> Running npm...');
    await _runNpm(nodeEntrypoint);

    stdout.writeln('>> Launching Chrome...');
    var chrome = await _launchChrome();

    chrome.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stdout.writeln('C>>> $line');
    });
    chrome.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stderr.writeln('C>>> $line');
    });

    stdout.writeln('>> Running tests...');
    var nodeArgs = [
      nodeEntrypoint.path,
      '8787',
      path.context.toUri(htmlPath).toString(),
      path.context.toUri(jsPath).toString(),
      outputLevel.toString().substring(outputLevel.toString().indexOf('.') + 1)
    ];
    var node = await Process.start('node', nodeArgs,
        workingDirectory: nodeEntrypoint.parent.path);
    node.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stdout.writeln('>>>> $line');
    });
    node.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stderr.writeln('>>>> $line');
      if (line.contains('invalid auth')) {
        stderr.writeln(
            '>>>> this may be caused by another application using port $port');
      }
    });

    var exitCode = await node.exitCode;
    chrome.kill(ProcessSignal.sigterm);
    _handleNodeExitCode(exitCode);

    return File(path.join(internalDir, 'js_reports', 'chrome.json'));
  }

  void _handleNodeExitCode(int exitCode) {
    if (exitCode == 0) {
      return;
    } else if (exitCode == 1) {
      throw 'Some tests failed!';
    } else if (exitCode == 2) {
      throw 'No tests ran!';
    } else if (exitCode == 3) {
      throw 'An error occurred while running the tests (see above)!';
    } else if (exitCode == 4) {
      throw 'An error occurred while communicating with Chrome (see above)!';
    } else if (exitCode == 5) {
      throw 'An error occurred while writing the coverage data (see above)!';
    } else if (exitCode == 6) {
      throw 'node failed to connect to Chrome DevTools (see above)!';
    } else {
      throw 'node failed with exit code $exitCode';
    }
  }

  Future<void> _runNpm(File nodeEntrypoint) async {
    var npm = await Process.start('npm.cmd', ['install'],
        workingDirectory: nodeEntrypoint.parent.path);
    npm.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => stdout.writeln('>>>> $line'));
    npm.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => stderr.writeln('>>>> $line'));
    var exitCode = await npm.exitCode;
    if (exitCode != 0) {
      throw 'npm install failed with exit code $exitCode';
    }
  }

  Future<File> _copyNodeEntrypoint() async {
    Directory directory =
        Directory(path.join(internalDir, 'chrome', 'js_runner'));
    var entryTarget = File(path.join(directory.path, 'chrome.js'));
    var packageTarget = File(path.join(directory.path, 'package.json'));
    var entrySource = Resource('package:covered/js/chrome.js');
    var packageSource = Resource('package:covered/js/package.json');

    await directory.create(recursive: true);
    await packageTarget.writeAsString(await packageSource.readAsString());
    await entryTarget.writeAsString(await entrySource.readAsString());

    return entryTarget;
  }

  Future<Process> _launchChrome() async {
    var chromeArgs = [
      '--remote-debugging-port=$port',
      '--disable-extensions',
      '--disable-popup-blocking',
      '--bwsi',
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-default-apps',
      '--disable-translate',
    ];

    if (headless) {
      chromeArgs.insert(1, '--headless');
    }

    return await Process.start(
      'chrome',
      chromeArgs,
      workingDirectory: projectDir,
    );
  }

  Future<File> _compileCoverageReport(
      File coverageFile, File jsEntrypoint, File jsSourceMap) async {
    stdout.writeln('>> Compiling coverage report...');
    var lcov = await js_coverage.analyseJsCoverage(
        coverageFile, jsEntrypoint, jsSourceMap, projectDir, reportOn);

    var outputFile = File(path.join(reportsDir, 'lcov_chrome.info'));
    await outputFile.create(recursive: true);
    await outputFile.writeAsString(lcov);
    return outputFile;
  }
}
