# covered
[![GitHub Actions](https://github.com/Komposten/covered/workflows/build/badge.svg)](https://github.com/Komposten/covered/actions)

**Code coverage for Dart applications**

covered is a Dart library for collecting code coverage for Dart code running in both the Dart VM and in browsers.

Existing packages like [`coverage`](https://pub.dev/packages/coverage) and [`test_coverage`](https://pub.dev/packages?q=test_coverage) only provide coverage for code run in the Dart VM, and [codecov.io's code coverage script](https://github.com/codecov/dart/blob/master/bin/src/coverage.dart) was built for Dart 1.0 and dartium/content_shell. covered aims to provide code coverage for both the Dart VM and browsers as there currently are no other solutions for this.

## Main features
- Collect code coverage for Dart applications running in the Dart VM.
- Collect code coverage for Dart web applications running in Chrome.
- Obtain coverage by platform as well as overall coverage, all in LCOV format.

## Usage
### Running covered
1) Add covered as a dev dependency.
2) Run `pub run covered` inside your project's root directory.
    * Use `-p`/`--platforms` to specify which platform(s) to run on (`vm` and/or `chrome`).
    * Use `-r`/`--report-on` to specify directories or files to collect coverage for.
    * See `-h`/`--help` for all options.
3) Find the resulting LCOV coverage files in `.covered/reports`.

**Example**

Collect coverage on both the Dart VM and headless Chrome. Provide "short" output from the tests, and only report on files found in the `lib` folder.

```
pub run covered --platforms vm,chrome --headless --test-output short --report-on lib
```

### Software requirements for browser coverage
* Chrome: Used for running the browser tests.
* Node: Used for connecting to the Chrome's remote interface to collect coverage.

## Limitations
covered currently has a couple of important limitations which I hope to resolve in the future. These are currently:
* Limited test configuration.
    * It is not possible to specify which test files or individual tests to run. Every file ending with `_test.dart` in the `test` directory will be run.
    * `dart_test.yaml` configuration is not respected.
    * `@Timeout`, `@OnPlatform`, `@Skip`, and `@Tags` are not respected (but `@TestOn` is).
* Limited platform options (only the Dart VM and Chrome).
* Line execution counts are not provided for browser coverage and merged coverage files.

## Roadmap
* Run the tests using the `test` package.

  If possible, this would mean that all test configuration support by the `test` package will also be supported by covered.
  
  Challenges:
  * Getting `test` to use dartdevc instead of dart2js. dartdevc provides slightly different JS code that happens to work better with Chrome's coverage tool.
  * Intercepting execution of browser tests after Chrome has opened and before the tests are run (to start coverage collection).
* Add Node.js as a test platform.

## License
covered is licensed under the MIT license. See [LICENSE](https://github.com/Komposten/covered/blob/master/LICENSE) for the full license text.
