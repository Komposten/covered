/*
 * Copyright 2019 Jakob Hjelm (Komposten)
 *
 * This file is part of covered.
 *
 * covered is a free Dart library: you can use, redistribute it and/or modify
 * it under the terms of the MIT license as written in the LICENSE file in the root
 * of this project.
 */
Future<void> collectTestCoverage(
    List<String> platforms, List<String> testArgs) async {
  await Future.forEach(platforms, (platform) {
    _testAndCollect(platform, testArgs);
  });
}

Future<void> _testAndCollect(String platform, List<String> testArgs) async {
  if (platform == 'vm') {
    _vmTestAndCollect(testArgs);
  } else {
    _browserTestAndCollect(testArgs);
  }
}

void _vmTestAndCollect(List<String> testArgs) {
  throw UnimplementedError('VM testing hasn\'t been implemented yet.');
}

void _browserTestAndCollect(List<String> testArgs) {
  throw UnimplementedError('Browser testing hasn\'t been implemented yet.');
}
