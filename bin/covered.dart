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

import 'package:args/args.dart';
import 'package:covered/covered.dart';
import 'package:covered/src/util/output.dart';
import 'package:path/path.dart' as path;

Future<void> main(List<String> arguments) async {
  final parser = ArgParser();

  parser.addSeparator('\nwhere options include:');
  parser.addFlag('help',
      abbr: 'h', help: 'Display usage information.', negatable: false);
  parser.addMultiOption('platforms',
      abbr: 'p',
      defaultsTo: ['vm'],
      allowed: ['vm', 'chrome'],
      help: 'Specify what platforms to run tests on.',
      valueHelp: 'PLATFORMS');
  parser.addOption('port',
      abbr: 'P',
      defaultsTo: '8787',
      help:
          'Which port to use for the Dart VM and Chrome observatories. Should be an integer in the range 0-65535.',
      valueHelp: 'PORT');
  parser.addOption('test-output',
      abbr: 't',
      defaultsTo: 'minimal',
      allowed: ['none', 'minimal', 'short', 'verbose'],
      help: 'How much of the test result output that should be displayed.',
      valueHelp: 'LEVEL',
      allowedHelp: {
        'none': 'Don\'t display test output.',
        'minimal': 'Only display passed/skipped/fail information.',
        'short':
            'Include actual/expected for failed tests and the reason for skipped tests.',
        'verbose': 'Display full test output.'
      });
  parser.addFlag('headless',
      abbr: 'H',
      help: 'If Chrome should be run in headless mode',
      negatable: false);
  parser.addMultiOption('report-on',
      abbr: 'r',
      help: 'Directories and/or files to report coverage for.'
          ' Defaults to include all classes inside the current working directory.',
      valueHelp: 'PATHS');
  parser.addSeparator(
      'and testArgs are additional options passed to the test run.');

  final argResults = parser.parse(arguments);

  if (argResults.wasParsed('help')) {
    print("usage: dart covered [-options] [testArgs...]");
    print(parser.usage);
    return;
  } else {
    print(
        'Collecting test coverage information for \'${Directory.current.path}\''
        ' on platforms ${argResults['platforms']}');
    var testOutput = Output.values
        .firstWhere((v) => v.toString().endsWith(argResults['test-output']));

    var port = _getPort(argResults);
    if (port == null) {
      return;
    }

    _validateReportOn(argResults['report-on']);
    await _run(argResults, port, testOutput);
  }
}

int _getPort(ArgResults argResults) {
  var port = int.tryParse(argResults['port']);

  if (port == null) {
    stdout.writeln('[--port] must be an integer in the range [0, 65535]!');
  } else if (port < 0 || port > 65535) {
    port = null;
    stdout.writeln('[--port] must be in the range [0, 65535]!');
  }

  return port;
}

void _validateReportOn(List<String> reportOn) {
  if (reportOn.isNotEmpty) {
    var missing = reportOn.toList()
      ..removeWhere(
          (path) => (Directory(path).existsSync() || File(path).existsSync()));

    if (missing.isNotEmpty) {
      stdout.writeln(
          'One or more of the [--reports-on] paths could not be found:\n  ' +
              missing.join('\n  '));
      stdout.writeln('Coverage analysis will proceed anyway.');
    }
  }
}

Future _run(ArgResults argResults, int port, Output testOutput) async {
  bool success = await collectTestCoverage(
      argResults['platforms'],
      port,
      testOutput,
      argResults['headless'],
      argResults['report-on'],
      argResults.rest);

  if (success) {
    stdout.writeln('\nThe coverage analysis completed successfully!');
    stdout.writeln(
        'The coverage report(s) can be found in the ${path.join('.covered', 'reports')} directory.');
  } else {
    exit(1);
  }
}
