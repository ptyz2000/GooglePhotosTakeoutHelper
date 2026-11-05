import 'package:gpth/locale.dart';
import 'package:path/path.dart' as p;
import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'media.dart';

/// "Edited" file name suffixes (like `-edited`) in all configured languages.
///
/// This is just a view on [activeLocale] - to add your language,
/// see `locale.dart` or use the `--locale-file` option
List<String> get extraFormats => activeLocale.editedSuffixes;

/// Removes any media that match any of "extra" formats
/// Returns count of removed
int removeExtras(List<Media> media) {
  final copy = media.toList();
  var count = 0;
  for (final m in copy) {
    final name = p.withoutExtension(p.basename(m.firstFile.path)).toLowerCase();
    for (final extra in extraFormats) {
      // MacOS uses NFD that doesn't work with our accents 🙃🙃
      // https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/pull/247
      if (unorm.nfc(name).endsWith(extra)) {
        media.remove(m);
        count++;
        break;
      }
    }
  }
  return count;
}
