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
import 'package:covered/src/output.dart';
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
  parser.addOption('test-output',
      abbr: 't',
      defaultsTo: 'none',
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
    await collectTestCoverage(
        argResults['platforms'], testOutput, argResults.rest);
    stdout.writeln('\nThe coverage analysis completed successfully!');
    stdout.writeln(
        'The coverage report(s) can be found in the ${path.join('.covered', 'reports')} directory.');
  }
}
