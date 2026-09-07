import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_avatar_web.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The browser has no filesystem: a picked photo must survive as a data
/// URL in prefs, resolve to an image, and leave cleanly when removed.
/// (The file has no web-only imports, so the VM can test it directly.)
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a picked photo round-trips through prefs as a data URL', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final src = await avatarAdd(XFile.fromData(bytes, mimeType: 'image/png'));
    expect(src, 'data:image/png;base64,${base64Encode(bytes)}');
    expect(avatarExists(src), isTrue);
    expect(await avatarRestoreLibrary(), [src]);
    expect((avatarImage(src) as MemoryImage).bytes, bytes);
    expect(identical(avatarImage(src), avatarImage(src)), isTrue,
        reason: 'one provider per key, so the image cache hits');
    await avatarRemove(src);
    expect(await avatarRestoreLibrary(), isEmpty);
  });

  test('a key that is not a data URL does not exist here', () {
    expect(avatarExists('/var/mobile/avatars/1.jpg'), isFalse);
  });

  test('picking the same photo twice keeps one entry', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final src1 = await avatarAdd(XFile.fromData(bytes, mimeType: 'image/png'));
    final src2 = await avatarAdd(XFile.fromData(bytes, mimeType: 'image/png'));
    expect(src1, src2);
    expect(await avatarRestoreLibrary(), [src1]);
    await avatarRemove(src1);
    expect(await avatarRestoreLibrary(), isEmpty);
  });
}