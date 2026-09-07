import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// On-device avatar store: photos under `<documents>/avatars`, keyed by
/// path. Same API as testu_avatar_web.dart; testu_profile.dart picks one
/// with a conditional import.
Future<Directory> _dir() async {
  final d =
      Directory('${(await getApplicationDocumentsDirectory()).path}/avatars');
  if (!d.existsSync()) d.createSync(recursive: true);
  return d;
}

Future<List<String>> avatarRestoreLibrary() async {
  final dir = await _dir();
  // Carried over from the single-photo cut, which saved one fixed avatar.jpg.
  final legacy = File('${dir.parent.path}/avatar.jpg');
  if (legacy.existsSync()) {
    legacy.renameSync(
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
  }
  return dir.listSync().whereType<File>().map((f) => f.path).toList()..sort();
}

bool avatarExists(String src) => File(src).existsSync();

/// Copies the pick under a unique name — FileImage caches by path, so
/// reusing one filename would keep serving the previous photo.
Future<String> avatarAdd(XFile picked) async {
  final dest =
      '${(await _dir()).path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
  await File(picked.path).copy(dest);
  return dest;
}

Future<void> avatarRemove(String src) async {
  final f = File(src);
  if (f.existsSync()) f.deleteSync();
  await FileImage(f).evict();
}

ImageProvider avatarImage(String src) => FileImage(File(src));
