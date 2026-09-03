#!/bin/sh
# Minsur demo: Minsur skin, Spanish, LIVE against the local eMe server
# (http://localhost:8080, start it first). Extra args go to flutter run,
# e.g. ./run_minsur.sh -d <device id>.
cd "$(dirname "$0")" && exec flutter run -t lib/main_testu.dart \
  --dart-define=TESTU_CLIENT=minsur "$@"
