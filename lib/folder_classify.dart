/// This file contains utils for determining type of a folder
/// Whether it's a legendary "year folder", album, trash, etc
import 'dart:io';

import 'package:gpth/locale.dart';
import 'package:gpth/utils.dart';
import 'package:path/path.dart' as p;

/// Names of year folders depend on the language of the Takeout -
/// see `locale.dart`
bool isYearFolder(Directory dir) =>
    activeLocale.isYearFolderName(p.basename(dir.path));

Future<bool> isAlbumFolder(Directory dir) =>
    dir.parent.list().whereType<Directory>().any((e) => isYearFolder(e));
