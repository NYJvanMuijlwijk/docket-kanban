import 'dart:io';

import 'package:args/args.dart';
import 'package:member_ordering_lints/src/reorder.dart';

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addFlag('dry-run', help: 'Show what would change without writing files.')
    ..addFlag('check', help: 'Exit with code 1 if any file needs reordering.')
    ..addFlag('help', abbr: 'h', help: 'Show this help message.');

  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln();
    _printUsage(parser);
    exit(2);
  }

  if (results.flag('help')) {
    _printUsage(parser);
    exit(0);
  }

  final dryRun = results.flag('dry-run');
  final check = results.flag('check');
  final paths = results.rest.isEmpty ? ['.'] : results.rest;

  final files = <String>[];
  for (final path in paths) {
    if (FileSystemEntity.isDirectorySync(path)) {
      files.addAll(
        Directory(path)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) => !f.path.endsWith('.g.dart'))
            .where((f) => !f.path.endsWith('.freezed.dart'))
            .map((f) => f.path),
      );
    } else if (FileSystemEntity.isFileSync(path)) {
      files.add(path);
    } else {
      stderr.writeln('Not found: $path');
      exit(2);
    }
  }

  var changedCount = 0;
  for (final file in files) {
    final source = File(file).readAsStringSync();
    final reordered = reorderFile(source);
    if (reordered != null) {
      changedCount++;
      if (dryRun || check) {
        stdout.writeln('Would reorder: $file');
      } else {
        File(file).writeAsStringSync(reordered);
        stdout.writeln('Reordered: $file');
      }
    }
  }

  if (changedCount == 0) {
    stdout.writeln('All files already in order.');
  } else if (dryRun || check) {
    stdout.writeln('$changedCount file(s) need reordering.');
  } else {
    stdout.writeln('$changedCount file(s) reordered.');
  }

  if (check && changedCount > 0) exit(1);
}

void _printUsage(ArgParser parser) {
  stdout
    ..writeln('Usage: dart run member_ordering_lints:fix [options] [paths]')
    ..writeln()
    ..writeln('Reorder class members to match the project convention.')
    ..writeln()
    ..writeln('Options:')
    ..writeln(parser.usage);
}
