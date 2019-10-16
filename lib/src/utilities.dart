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

import 'package:boolean_selector/boolean_selector.dart';
import 'package:path/path.dart' as path;

const _browsers = 'chrome || phantomjs || firefox || safari || ie';
const _blink = 'chrome';
const _js = '$_browsers || node';
const _posix = 'mac-os || linux || android || ios';

bool testOnPlatform(String testOnString, String platform) {
  testOnString = testOnString
      .replaceAll('browser', '($_browsers)')
      .replaceAll('blink', '($_blink)')
      .replaceAll(RegExp(r'\bjs\b'), '($_js)')
      .replaceAll('dart-vm', '!($_js)')
      .replaceAll('posix', '($_posix)');

  var selector = BooleanSelector.parse(testOnString);
  var system = _getSystem(testOnString);

  if (system == null) {
    return selector.evaluate([platform]);
  } else {
    return selector.evaluate([platform, system]);
  }
}

String _getSystem(String testOnString) {
  if (testOnString.contains(RegExp(r'vm|node'))) {
    if (Platform.isWindows) {
      return 'windows';
    } else if (Platform.isMacOS) {
      return 'mac-os';
    } else if (Platform.isLinux) {
      return 'linux';
    }
  }

  if (testOnString.contains('vm')) {
    if (Platform.isAndroid) {
      return 'android';
    } else if (Platform.isIOS) {
      return 'ios';
    }
  }

  return null;
}

String fixPathSeparators(String string) {
  return string.replaceAll('/', path.separator);
}
