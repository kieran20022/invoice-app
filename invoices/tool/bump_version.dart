// Bumps the app's version in pubspec.yaml by one tenth: 4.3 → 4.4, and
// 4.9 → 5.0. The build number follows as MAJOR*10+MINOR so Android always
// sees it grow.
//
//   dart run tool/bump_version.dart
import 'dart:io';

void main() {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('Run this from the project folder (pubspec.yaml not found).');
    exit(1);
  }
  final text = pubspec.readAsStringSync();
  final line = RegExp(r'^version:\s*(\d+)\.(\d+)(?:\.\d+)?(?:\+\d+)?\s*$',
      multiLine: true);
  final match = line.firstMatch(text);
  if (match == null) {
    stderr.writeln('No "version: MAJOR.MINOR..." line in pubspec.yaml.');
    exit(1);
  }
  var major = int.parse(match.group(1)!);
  var minor = int.parse(match.group(2)!) + 1;
  if (minor > 9) {
    major++;
    minor = 0;
  }
  final updated = text.replaceRange(match.start, match.end,
      'version: $major.$minor.0+${major * 10 + minor}');
  pubspec.writeAsStringSync(updated);
  stdout.writeln('${match.group(1)}.${match.group(2)} → $major.$minor');
}
