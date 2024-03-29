import 'package:covered/src/util/utilities.dart';
import 'package:test/test.dart';

void main() {
  test('testOnPlatform', () {
    expect(testOnPlatform('browser && !chrome', 'firefox'), true);
    expect(testOnPlatform('browser && !chrome', 'chrome'), false);
    expect(testOnPlatform('vm', 'vm'), true);
    expect(testOnPlatform('vm', 'firefox'), false);
    expect(testOnPlatform('js', 'firefox'), true);
    expect(testOnPlatform('js', 'node'), true);
    expect(testOnPlatform('dart-vm', 'vm'), true);
    expect(testOnPlatform('dart-vm', 'node'), false);
  });

  test('testOnPlatform_onWindows', () {
    expect(testOnPlatform('vm && windows', 'vm'), true);
    expect(testOnPlatform('vm && linux', 'vm'), false);
    expect(testOnPlatform('vm && !posix', 'vm'), true);
  }, testOn: 'windows');

  test('testOnPlatform_onLinux', () {
    expect(testOnPlatform('vm && windows', 'vm'), false);
    expect(testOnPlatform('vm && linux', 'vm'), true);
    expect(testOnPlatform('vm && !posix', 'vm'), false);
  }, testOn: 'linux');
}
