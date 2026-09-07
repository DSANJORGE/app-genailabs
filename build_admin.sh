#!/bin/sh
# Builds the admin console for the web and drops it into the plugin so eMe serves it at /site/mediadb/admin/.
set -e
cd "$(dirname "$0")"
# build/web is merged into, never cleaned: an old `--wasm` build left
# main.dart.wasm (3.2 MB) + main.dart.mjs behind and `cp -R` shipped both to
# the plugin, where nothing referenced them.
rm -rf build/web
flutter build web -t lib/main_admin.dart --release --base-href /site/mediadb/admin/ --dart-define=TESTU_CLIENT=minsur --pwa-strategy=none
rm -rf ../eme-plugin-testu/html/admin && cp -R build/web ../eme-plugin-testu/html/admin
# The plugin's _site.xconf is owned by this script, not by build/web -- build/web
# is untracked scratch output and must not be the source of truth for it.
cat > ../eme-plugin-testu/html/admin/_site.xconf << 'XCONF'
<page>
  <property name="fallbackdirectory"></property>
  <generator name="file"/>
  <permission name="view"><boolean value="true"/></permission>
</page>
XCONF
echo "console built into eme-plugin-testu/html/admin"
