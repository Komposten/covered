import 'package:args/args.dart';
import 'package:covered/covered.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser();

  parser.addSeparator('\nwhere options include:');
  parser.addFlag('help',
      abbr: 'h', help: 'Display usage information.', negatable: false);
  parser.addMultiOption('platforms',
      abbr: 'p',
      help: 'Specify what platforms to run tests on.',
      valueHelp: 'PLATFORMS');
  parser.addSeparator('and testArgs are additional options passed to the test run.');

  final argResults = parser.parse(arguments);

  if (argResults.wasParsed('help')) {
    print("usage: dart covered [-options] [testArgs...]");
    print(parser.usage);
    return;
  } else {
    await collectTestCoverage(argResults['platforms'], argResults.rest);
  }
}
