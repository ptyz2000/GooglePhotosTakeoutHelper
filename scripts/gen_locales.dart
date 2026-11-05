/// Builds `lib/locales.g.dart` out of the JSON files in `locales/`, so that
/// they get compiled into the gpth executable (it can't read them at runtime).
///
/// Run it from the root of the project after adding or changing a locale:
///
///     dart run scripts/gen_locales.dart
///
/// ...or with `--check` to only verify that the generated file is up to date
/// (the tests do that too).

import 'dart:convert';
import 'dart:io';

import 'package:gpth/locale.dart';
import 'package:path/path.dart' as p;

const localesDir = 'locales';
const generatedFile = 'lib/locales.g.dart';

/// Language codes, like `de` or `pt-BR`
final _fileNameRegExp = RegExp(r'^[a-z]{2,3}(-[A-Za-z0-9]{2,8})?$');

/// Only these may be in a locale file that's added to the repo. Names of output
/// folders are a personal preference, not a language thing - for those, people
/// can use their own file with `--locale-file`.
const _allowedKeys = {'name', 'credits', 'yearFolders', 'editedSuffixes'};

String _code(File file) => p.basenameWithoutExtension(file.path);

/// English goes first, then alphabetically
String _sortKey(File file) => _code(file) == 'en' ? '' : _code(file);

/// Builds the contents of `lib/locales.g.dart` from the JSON files in [dir]
///
/// Throws [FormatException] with a message saying what's wrong and in which
/// file, if any of them is invalid
String generateLocalesSource(Directory dir) {
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => p.extension(f.path) == '.json')
      .where((f) => !p.basename(f.path).startsWith('_'))
      .toList()
    ..sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
  if (files.isEmpty) {
    throw FormatException('No locale files found in ${dir.path}');
  }

  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT EDIT BY HAND.')
    ..writeln('//')
    ..writeln('// Built from locales/*.json by scripts/gen_locales.dart.')
    ..writeln('// To add or change a language, edit those files and run:')
    ..writeln('//   dart run scripts/gen_locales.dart')
    ..writeln()
    ..writeln('// dart format off')
    ..writeln()
    ..writeln('/// Language code -> JSON with the names for that language')
    ..writeln('/// (see `locale.dart` for how they are used).')
    ..writeln('const bundledLocaleJson = <String, String>{');
  for (final file in files) {
    final String json;
    try {
      json = _embeddedJson(_code(file), file.readAsStringSync());
    } on FormatException catch (e) {
      throw FormatException('${p.basename(file.path)}: ${e.message}');
    }
    buffer.writeln("  '${_code(file)}': r'$json',");
  }
  buffer.writeln('};');
  return buffer.toString();
}

/// Validates one locale file and returns the JSON to embed in the code, that
/// is safe to put in a raw string with single quotes
String _embeddedJson(String code, String source) {
  if (!_fileNameRegExp.hasMatch(code)) {
    throw const FormatException(
      'file name must be a language code, like "de" or "pt-BR"',
    );
  }
  // Notepad on windoza likes to put this at the start of files
  if (source.startsWith('\uFEFF')) source = source.substring(1);
  // this is the very same parser (and validation) that gpth uses when running
  LocaleConfig(yearFolders: const [], editedSuffixes: const [])
      .extendedWithJson(source);

  final json = jsonDecode(source) as Map<String, dynamic>;
  for (final key in json.keys) {
    if (key.startsWith('_')) continue;
    if (!_allowedKeys.contains(key)) {
      throw FormatException(
        "'$key' is not allowed here - only: ${_allowedKeys.join(', ')}",
      );
    }
  }
  final name = json['name'];
  if (name is! String || name.trim().isEmpty) {
    throw const FormatException(
      '"name" is required - the name of the language, like "German"',
    );
  }
  final embedded = jsonEncode({
    'name': name,
    'yearFolders': json['yearFolders'] ?? [],
    'editedSuffixes': json['editedSuffixes'] ?? [],
  });
  // a single quote can't be in a raw string, but it can be in JSON like this:
  return embedded.replaceAll("'", r'\u0027');
}

void main(List<String> args) {
  if (!Directory(localesDir).existsSync()) {
    stderr.writeln('Run this from the root of the project '
        '(there is no "$localesDir" folder here)');
    exit(2);
  }
  final String source;
  try {
    source = generateLocalesSource(Directory(localesDir));
  } on FormatException catch (e) {
    stderr.writeln('ERROR in locale files: ${e.message}');
    exit(1);
  }

  final file = File(generatedFile);
  if (args.contains('--check')) {
    final current = file.existsSync()
        ? file.readAsStringSync().replaceAll('\r\n', '\n')
        : '';
    if (current != source) {
      stderr.writeln('$generatedFile is out of date - '
          'run: dart run scripts/gen_locales.dart');
      exit(1);
    }
    print('$generatedFile is up to date');
    return;
  }
  file.writeAsStringSync(source);
  print('Wrote $generatedFile');
}
