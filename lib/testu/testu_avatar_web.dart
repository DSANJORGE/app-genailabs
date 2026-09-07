import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Browser avatar store (spec: `testu-learn-web`): picked photos live as
/// data URLs in shared_preferences (localStorage). A 512px JPEG is ~60 KB;
/// the 5 MB quota is nowhere near. Same API as testu_avatar_io.dart.
const _kLib = 'testu_avatar_library';

Future<List<String>> avatarRestoreLibrary() async =>
    (await SharedPreferences.getInstance()).getStringList(_kLib) ?? const [];

bool avatarExists(String src) => src.startsWith('data:');

Future<String> avatarAdd(XFile picked) async {
  final src = 'data:${picked.mimeType ?? 'image/jpeg'};base64,'
      '${base64Encode(await picked.readAsBytes())}';
  final lib = await avatarRestoreLibrary();
  // Re-picking the same photo selects the existing entry instead of adding a twin.
  if (lib.contains(src)) return src;
  final p = await SharedPreferences.getInstance();
  await p.setStringList(_kLib, [...lib, src]);
  return src;
}

Future<void> avatarRemove(String src) async {
  final p = await SharedPreferences.getInstance();
  await p.setStringList(
      _kLib, (await avatarRestoreLibrary()).where((s) => s != src).toList());
  _images.remove(src);
}

// One provider per key, so Flutter's image cache hits instead of decoding
// the same photo on every rebuild (MemoryImage compares bytes by identity).
final _images = <String, MemoryImage>{};

ImageProvider avatarImage(String src) => _images[src] ??=
    MemoryImage(base64Decode(src.substring(src.indexOf(',') + 1)));
