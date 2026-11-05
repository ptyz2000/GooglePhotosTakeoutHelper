/// Tests for the files in `locales/` - the ones that anyone can contribute
import 'dart:convert';
import 'dart:io';

import 'package:gpth/locale.dart';
import 'package:gpth/locales.g.dart';
import 'package:test/test.dart';

import '../scripts/gen_locales.dart' show readLocaleFiles;

void main() {
  final localesDir = Directory('locales');

  test('Every file in locales/ is valid', () {
    // throws a message with the file name and what's wrong, if one isn't
    expect(() => readLocaleFiles(localesDir), returnsNormally);
  });

  test('lib/locales.g.dart is up to date', () {
    // compares the data, not the text - how the file is formatted is irrelevant
    expect(
      bundledLocaleJson,
      readLocaleFiles(localesDir),
      reason: 'You changed something in locales/ - '
          'run `dart run scripts/gen_locales.dart` and commit '
          'the updated lib/locales.g.dart',
    );
  });

  test('Every bundled locale is loaded into the defaults', () {
    expect(bundledLocaleJson.keys, contains('en'));
    for (final json in bundledLocaleJson.values) {
      final suffixes = (jsonDecode(json) as Map)['editedSuffixes'] as List;
      for (final suffix in suffixes) {
        expect(
          LocaleConfig.defaults.editedSuffixes,
          contains((suffix as String).toLowerCase()),
        );
      }
    }
  });

  test('The template is a valid locale file', () {
    final template = File('locales/_template.json').readAsStringSync();
    expect(
      () => LocaleConfig.defaults.extendedWithJson(template),
      returnsNormally,
    );
  });
}
