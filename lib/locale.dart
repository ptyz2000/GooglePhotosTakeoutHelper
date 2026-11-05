/// Everything in gpth that depends on the *language* of the Google account that
/// made the Takeout lives in this file - so supporting a new language never
/// means digging through the rest of the code.
///
/// The names for each language are kept in `locales/*.json` - one file per
/// language, and anyone can contribute one (see `locales/README.md`). They get
/// compiled into `locales.g.dart` by `scripts/gen_locales.dart`, and *all* of
/// them are active at once, so there's no need to tell gpth which language your
/// Takeout is in.
///
/// For your own private additions, pass `--locale-file my-locale.json` on the
/// command line - see [LocaleConfig.extendedWithJson] for the format.

import 'dart:convert';
import 'dart:io';

import 'package:gpth/locales.g.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Stands for the 4-digit year inside a year-folder template, so
/// `Photos from {year}` matches the folder `Photos from 2021`.
///
/// It may be placed anywhere, because some languages put the year first.
const yearPlaceholder = '{year}';

/// What [yearPlaceholder] turns into when a template is converted to a regex
const _yearRegex = r'(?:20|19|18)\d{2}';

class LocaleConfig {
  /// Names of the "year folders" Google creates, with [yearPlaceholder] where
  /// the year goes. A folder matching *any* of them is a year folder.
  final List<String> yearFolders;

  /// Suffixes Google adds to edited photos (`IMG_1234-edited.jpg`).
  /// Always stored lowercase and NFC-normalized.
  final List<String> editedSuffixes;

  /// Output folder that holds photos that don't belong to any album
  final String allPhotosFolder;

  /// Output folder for photos whose date could not be found
  final String unknownDateFolder;

  final List<RegExp> _yearFolderPatterns;

  /// Throws [FormatException] if anything is invalid (a year folder without
  /// [yearPlaceholder], an empty suffix, a folder name with slashes...)
  LocaleConfig({
    required Iterable<String> yearFolders,
    required Iterable<String> editedSuffixes,
    this.allPhotosFolder = 'ALL_PHOTOS',
    this.unknownDateFolder = 'date-unknown',
  })  : yearFolders = List.unmodifiable({...yearFolders}),
        editedSuffixes =
            List.unmodifiable({...editedSuffixes.map(_normalizeSuffix)}),
        _yearFolderPatterns =
            List.unmodifiable({...yearFolders}.map(_templateToRegExp)) {
    _checkFolderName(allPhotosFolder, 'allPhotosFolder');
    _checkFolderName(unknownDateFolder, 'unknownDateFolder');
  }

  /// All the languages bundled in `locales/` (see `locales.g.dart`), together
  static final defaults = bundledLocaleJson.values.fold(
    LocaleConfig(yearFolders: const [], editedSuffixes: const []),
    (config, json) => config.extendedWithJson(json),
  );

  /// Whether [folderName] (just the name, not the whole path) is a year folder
  bool isYearFolderName(String folderName) {
    // MacOS uses NFD that doesn't work with our accents 🙃🙃
    final name = unorm.nfc(folderName);
    return _yearFolderPatterns.any((pattern) => pattern.hasMatch(name));
  }

  static const _jsonKeys = [
    'name',
    'credits',
    'yearFolders',
    'editedSuffixes',
    'allPhotosFolder',
    'unknownDateFolder',
  ];

  /// Returns a copy of this config with the settings from a JSON string
  /// layered on top. Example:
  ///
  /// ```json
  /// {
  ///   "yearFolders": ["Photos from {year}", "{year} photos"],
  ///   "editedSuffixes": ["-edited"],
  ///   "allPhotosFolder": "ALL_PHOTOS",
  ///   "unknownDateFolder": "date-unknown"
  /// }
  /// ```
  ///
  /// - `yearFolders` and `editedSuffixes` are *added* to the existing ones, so
  ///   a file only has to list what's new
  /// - `allPhotosFolder` and `unknownDateFolder` *replace* the existing ones
  /// - every key is optional; keys starting with `_` are ignored (use them
  ///   for notes, JSON has no comments)
  /// - `name` (of the language) and `credits` (who made it) are only used in
  ///   the files in `locales/`, and are not needed otherwise
  ///
  /// Throws [FormatException] on invalid JSON, unknown keys or invalid values.
  LocaleConfig extendedWithJson(String source) {
    // Notepad on windoza likes to put this at the start of files
    if (source.startsWith('\uFEFF')) source = source.substring(1);
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Locale file must contain a JSON object');
    }
    for (final key in decoded.keys) {
      if (key.startsWith('_')) continue;
      if (!_jsonKeys.contains(key)) {
        // fail loudly on typos - silently ignoring them would be a nightmare
        throw FormatException(
          "Unknown key '$key' - expected one of: ${_jsonKeys.join(', ')}",
        );
      }
    }
    // just documentation - but it's still checked, to keep the files clean
    _string(decoded, 'name');
    _stringList(decoded, 'credits');
    return LocaleConfig(
      yearFolders: [...yearFolders, ..._stringList(decoded, 'yearFolders')],
      editedSuffixes: [
        ...editedSuffixes,
        ..._stringList(decoded, 'editedSuffixes'),
      ],
      allPhotosFolder: _string(decoded, 'allPhotosFolder') ?? allPhotosFolder,
      unknownDateFolder:
          _string(decoded, 'unknownDateFolder') ?? unknownDateFolder,
    );
  }

  /// Reads a JSON [file] (see [extendedWithJson] for the format) and layers it
  /// on top of [base], or on top of [defaults] if [base] is not given.
  ///
  /// Throws [FileSystemException] if file can't be read, and
  /// [FormatException] if its contents are invalid.
  static Future<LocaleConfig> fromFile(File file, {LocaleConfig? base}) async =>
      (base ?? defaults).extendedWithJson(await file.readAsString());
}

/// The locale gpth is running with. It starts as [LocaleConfig.defaults];
/// `--locale-file` replaces it before any processing happens.
LocaleConfig activeLocale = LocaleConfig.defaults;

RegExp _templateToRegExp(String template) {
  if (!template.contains(yearPlaceholder)) {
    throw FormatException(
      "Year folder '$template' must contain '$yearPlaceholder'",
    );
  }
  final literalParts = unorm.nfc(template).split(yearPlaceholder);
  return RegExp('^${literalParts.map(RegExp.escape).join(_yearRegex)}\$');
}

String _normalizeSuffix(String suffix) {
  if (suffix.isEmpty) {
    // would match *every* file name, and --skip-extras would delete everything
    throw const FormatException('An "edited" suffix must not be empty');
  }
  return unorm.nfc(suffix.toLowerCase());
}

void _checkFolderName(String name, String key) {
  if (name.trim().isEmpty ||
      name == '.' ||
      name == '..' ||
      name.contains('/') ||
      name.contains('\\')) {
    throw FormatException(
      "'$key' must be a plain folder name without slashes, got '$name'",
    );
  }
}

List<String> _stringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return const [];
  if (value is List && value.every((e) => e is String)) {
    return value.cast<String>();
  }
  throw FormatException("'$key' must be a list of strings");
}

String? _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException("'$key' must be a string");
}
