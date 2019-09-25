@TestOn('vm')
import 'package:covered/src/utilities.dart';
import 'package:test/test.dart';

void main() {
  test('testOnPlatform', () {
    expect(testOnPlatform('browser && !chrome', 'firefox'), true);
    expect(testOnPlatform('browser && !chrome', 'chrome'), false);
    expect(testOnPlatform('vm', 'vm'), true);
    expect(testOnPlatform('vm', 'firefox'), false);
    expect(testOnPlatform('vm && windows', 'vm'), true);
    expect(testOnPlatform('vm && linux', 'vm'), false);
    expect(testOnPlatform('vm && !posix', 'vm'), true);
    expect(testOnPlatform('js', 'firefox'), true);
    expect(testOnPlatform('js', 'node'), true);
    expect(testOnPlatform('dart-vm', 'vm'), true);
    expect(testOnPlatform('dart-vm', 'node'), false);
  });
}
