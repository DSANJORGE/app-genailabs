// Browser download for the CSV export. Conditional export keeps
// `package:web` (and any browser-only call) out of the path `flutter test`
// exercises on the Dart VM -- see admin_download_stub.dart /
// admin_download_web.dart.
export 'admin_download_stub.dart'
    if (dart.library.js_interop) 'admin_download_web.dart';
