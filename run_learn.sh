#!/bin/sh
# Learner app in Chrome against the local server (start it first). Extra
# args go to flutter run.
# ponytail: --disable-web-security covers the :7358 -> :8080 CORS gap for
# local dev only; production serves the app same-origin from the plugin, so
# this flag never ships.
cd "$(dirname "$0")" && exec flutter run -t lib/main_testu.dart -d chrome --web-port 7358 \
  --web-browser-flag=--disable-web-security \
  --dart-define=TESTU_CLIENT=minsur --dart-define=TESTU_MEDIADB=http://localhost:8080/site/mediadb "$@"
