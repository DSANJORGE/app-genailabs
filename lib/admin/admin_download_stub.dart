// ponytail: no-op outside a browser -- flutter test runs on the Dart VM,
// where there is no window to hand a download to. Upgrade only if a non-web
// admin console target ever needs CSV export too.
void downloadCsv(String filename, String content) {}
