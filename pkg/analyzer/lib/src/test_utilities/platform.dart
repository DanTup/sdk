import 'dart:io';

/// The EOL character to be used for source code in tests.
final platformEol = Platform.isWindows ? '\r\n' : '\n';

/// Normalizes content to use platform-specific newlines to ensure that
/// when running on Windows \r\n is used even though source files are checked
/// out using \n.
String normalizeNewlinesForPlatform(String input) {
  // TODO(dantup): This is commited as a no-op because it breaks many tests
  // on Windows.
  //
  // Uncomment these lines to work on fixing tests. Change `platformEol`
  // to `\r\n` to emulate Windows behaviour from non-windows machines.
  //
  // final newlinePattern = RegExp(r'\r?\n'); // either \r\n or \n
  // return input.replaceAll(newlinePattern, platformEol);
  return input;
}
