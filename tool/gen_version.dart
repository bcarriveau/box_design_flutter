// Run with: dart run tool/gen_version.dart
// Regenerates lib/version.dart with the current short git commit hash, so
// the app header can show exactly which build is running. Run this before
// `flutter build` -- it's not wired into the build automatically.
import 'dart:io';

void main() {
  final hashResult = Process.runSync('git', ['rev-parse', '--short', 'HEAD']);
  if (hashResult.exitCode != 0) {
    stderr.write(hashResult.stderr);
    exit(1);
  }
  final hash = (hashResult.stdout as String).trim();

  final statusResult = Process.runSync('git', ['status', '--porcelain']);
  final dirty = (statusResult.stdout as String).trim().isNotEmpty;

  final version = dirty ? '$hash-dirty' : hash;
  File('lib/version.dart').writeAsStringSync(
    '// GENERATED FILE -- do not edit by hand.\n'
    '// Regenerate with: dart run tool/gen_version.dart\n'
    "const String appVersion = '$version';\n",
  );
  // ignore: avoid_print
  print('Wrote lib/version.dart: $version');
}
