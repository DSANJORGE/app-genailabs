#!/bin/sh
# Builds the learner app for the web and drops it into the plugin so eMe
# serves it at /site/mediadb/learn/ (spec: testu-learn-web). Mirrors
# build_admin.sh; same-origin, so no CORS anywhere.
set -e
cd "$(dirname "$0")"
# build/web is merged into, never cleaned (see build_admin.sh for the
# stale --wasm artifact that once shipped).
rm -rf build/web
flutter build web -t lib/main_testu.dart --release --base-href /site/mediadb/learn/ --dart-define=TESTU_CLIENT=minsur --pwa-strategy=none
rm -rf ../eme-plugin-testu/html/learn && cp -R build/web ../eme-plugin-testu/html/learn
# The plugin's _site.xconf is owned by this script, not by build/web.
cat > ../eme-plugin-testu/html/learn/_site.xconf << 'XCONF'
<page>
  <property name="fallbackdirectory"></property>
  <generator name="file"/>
  <permission name="view"><boolean value="true"/></permission>
</page>
XCONF
echo "learner web built into eme-plugin-testu/html/learn"
