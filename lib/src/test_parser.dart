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
import 'testinfo.dart';

class TestParser {
  TestInfo parse(FileSystemEntity entity) {
    var file = File(entity.path);
    var lines = file.readAsLinesSync();
    var testOnRegex = RegExp(r'''\s*@TestOn\(["'](\w+)["']\)\s*''');
    var inComment = false;
    var testOn = '';

    for (var line in lines) {
      if (inComment && line.contains('*/')) {
        inComment = false;
        line = line.substring(0, line.indexOf('*/') + 2);
      }

      if (!inComment) {
        if (line.trimLeft().startsWith('//')) {
          continue;
        }

        if (line.contains('/*')) {
          line = line.substring(0, line.indexOf('/*'));
          inComment = true;
        }

        if (testOnRegex.hasMatch(line)) {
          testOn = testOnRegex.firstMatch(line).group(1);
          break;
        } else if (line.isNotEmpty) {
          break;
        }
      }
    }

    return TestInfo(testOn, file);
  }
}
