#!/bin/sh
# Store builds for Minsur, pointed at production.
# This Mac has no codesigning identities/provisioning profiles, so both
# artifacts come out unsigned:
#   - the .aab is debug-signed (Android release uses the debug signing
#     config here) and must be re-signed (or rebuilt) with EnterMedia's
#     upload key before it can go to Play Console.
#   - the .xcarchive is unsigned; EnterMedia signs it at export time in
#     Xcode Organizer with their own team (VJ8RCF92K4 is the team
#     currently in the pbxproj; unverified).
set -e
cd "$(dirname "$0")"
D="--dart-define=TESTU_CLIENT=minsur --dart-define=TESTU_LIVE=true --dart-define=TESTU_MEDIADB=https://minsur.genailabs.tech/site/mediadb"
flutter build appbundle -t lib/main_testu.dart --release $D
flutter build ipa -t lib/main_testu.dart --release --no-codesign $D
ls -la build/app/outputs/bundle/release/*.aab
ls -la build/ios/archive/Runner.xcarchive
