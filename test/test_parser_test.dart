import 'dart:io';

import 'package:covered/src/test_parser.dart';
import 'package:test/test.dart';

void main() {
  var parser = TestParser();

  File _file(String file) {
    return File('test/res/test_parser/$file');
  }

  test('parse_fileWithoutTestOn_ignoreTestOn', () {
    var res = parser.parse(_file('no_teston.dart'));
    expect(res.testOn, '');
  });

  test('parse_fileWithTestOnInComment_ignoreTestOn', () {
    var res = parser.parse(_file('teston_in_comment.dart'));
    expect(res.testOn, '');

    res = parser.parse(_file('teston_in_comment_2.dart'));
    expect(res.testOn, '');
  });

  test('parse_fileWithTestOnBelowFirstStatement_ignoreTestOn', () {
    var res = parser.parse(_file('teston_below_statement.dart'));
    expect(res.testOn, '');
  });

  test('parse_fileWithTestOn_parseTestOn', () {
    var res = parser.parse(_file('with_teston.dart'));
    expect(res.testOn, 'chrome');
  });
}
