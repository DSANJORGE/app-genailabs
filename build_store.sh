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
# Privacy policy link (profile + sign-in): append
#   --dart-define=TESTU_PRIVACY_URL=https://<page>
# to D once the GenAI Labs page exists. Empty = the rows stay hidden
# (testu_live.dart: testuPrivacyUrl), which is the code's default.
D="--dart-define=TESTU_CLIENT=minsur --dart-define=TESTU_LIVE=true --dart-define=TESTU_MEDIADB=https://minsur.genailabs.tech/site/mediadb"
flutter build appbundle -t lib/main_testu.dart --release $D
flutter build ipa -t lib/main_testu.dart --release --no-codesign $D
ls -la build/app/outputs/bundle/release/*.aab
ls -la build/ios/archive/Runner.xcarchive

# Part A verification (final review, widened word list): after a build above,
# string-scan both release binaries for invented content. Every count below
# must be 0 — a non-zero one means a mock string survived into a live build.
# Not run automatically; paste into a shell by hand.
#
# cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs"
# AAB=build/app/outputs/bundle/release/app-release.aab
# IOS=build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Frameworks/App.framework/App
# for w in Diego "Ana Ruiz" ana.ruiz Lima rampa OPERACIONES "Safety Lead" Bienvenida "Operaciones · Mina"; do
#   printf '%-20s aab=%s ios=%s\n' "$w" \
#     "$(unzip -p "$AAB" base/lib/arm64-v8a/libapp.so | strings | grep -c -- "$w")" \
#     "$(strings "$IOS" | grep -c -- "$w")"
# done
#
# Expected (every row):
#   Diego                aab=0 ios=0
#   Ana Ruiz             aab=0 ios=0
#   ana.ruiz             aab=0 ios=0
#   Lima                 aab=0 ios=0
#   rampa                aab=0 ios=0
#   OPERACIONES          aab=0 ios=0
#   Safety Lead          aab=0 ios=0
#   Bienvenida           aab=0 ios=0
#   Operaciones · Mina   aab=0 ios=0
