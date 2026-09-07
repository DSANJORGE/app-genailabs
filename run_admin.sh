#!/bin/sh
# Admin console in Chrome against the local server. Extra args go to flutter run.
# ponytail: --disable-web-security works around the :7357 -> :8080 CORS gap
# for local dev only; production serves the console same-origin from the
# plugin, so this flag never ships.
cd "$(dirname "$0")" && exec flutter run -t lib/main_admin.dart -d chrome --web-port 7357 \
  --web-browser-flag=--disable-web-security \
  --dart-define=TESTU_CLIENT=minsur --dart-define=TESTU_MEDIADB=http://localhost:8080/site/mediadb "$@"
