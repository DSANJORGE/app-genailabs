#!/bin/sh
# Vueling demo: Vueling skin, English, OFFLINE prototype content (no server).
# Extra args go to flutter run, e.g. ./run_vueling.sh -d <device id>.
cd "$(dirname "$0")" && exec flutter run -t lib/main_testu.dart \
  --dart-define=TESTU_CLIENT=vueling "$@"
