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

import 'package:covered/src/tester.dart';

class ChromeTester extends Tester {
  ChromeTester(String projectDir) : super(projectDir, 'chrome');

  @override
  Future<File> runTestsAndCollect(File entrypoint, bool printTestOutput) {
    throw UnimplementedError('ChromeTester hasn\'t been implemented yet!');
  }
}
