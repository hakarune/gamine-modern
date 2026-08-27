#!/usr/bin/env bash
#
# build-deb.sh — package gamine-modern (a single-file HTML5 app) as a .deb
#
# The package installs:
#   /usr/share/gamine-modern/index.html      the game itself
#   /usr/bin/gamine-modern                   launcher: opens it fullscreen in a browser
#   /usr/share/applications/gamine-modern.desktop
#   /usr/share/icons/hicolor/scalable/apps/gamine-modern.svg
#   /usr/share/doc/gamine-modern/{copyright,changelog.Debian.gz}
#
# Usage:  ./build-deb.sh [version]
# Output: dist/gamine-modern_<version>_all.deb
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

PKG="gamine-modern"
VERSION="${1:-$(sed -n 's/.*"version":[[:space:]]*"\([^"]*\)".*/\1/p' package.json | head -n1)}"
VERSION="${VERSION:-2.0.0}"
ARCH="all"

# Maintainer taken from git config, with a sane fallback.
MAINT_NAME="$(git config user.name  2>/dev/null || echo "$PKG maintainers")"
MAINT_MAIL="$(git config user.email 2>/dev/null || echo "nobody@example.com")"
MAINTAINER="${MAINTAINER:-$MAINT_NAME <$MAINT_MAIL>}"

BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
ROOT="$BUILD/$PKG"

echo ">> Building $PKG $VERSION ($ARCH)"

# ---- payload -------------------------------------------------------------
install -Dm644 index.html          "$ROOT/usr/share/$PKG/index.html"
install -Dm644 gamine-modern.svg   "$ROOT/usr/share/icons/hicolor/scalable/apps/$PKG.svg"

# ---- launcher ----------------------------------------------------------
install -d "$ROOT/usr/bin"
cat > "$ROOT/usr/bin/$PKG" <<'LAUNCH'
#!/bin/sh
# Launch Gamine fullscreen in the best browser we can find.
APP="/usr/share/gamine-modern/index.html"
URL="file://$APP"
PROFILE="${XDG_CACHE_HOME:-$HOME/.cache}/gamine-modern"

for b in chromium chromium-browser google-chrome google-chrome-stable brave-browser; do
    if command -v "$b" >/dev/null 2>&1; then
        exec "$b" --app="$URL" --start-fullscreen --kiosk --no-first-run \
                  --no-default-browser-check --user-data-dir="$PROFILE" "$@"
    fi
done
for b in firefox firefox-esr; do
    if command -v "$b" >/dev/null 2>&1; then
        exec "$b" --kiosk "$URL" "$@"
    fi
done
if command -v xdg-open >/dev/null 2>&1; then
    exec xdg-open "$URL"
fi
echo "gamine-modern: no supported web browser found." >&2
echo "Open $APP manually in a browser." >&2
exit 1
LAUNCH
chmod 755 "$ROOT/usr/bin/$PKG"

# ---- desktop entry ---------------------------------------------------
install -d "$ROOT/usr/share/applications"
sed 's|@BINDIR@|/usr/bin|g' gamine-modern.desktop.in \
    > "$ROOT/usr/share/applications/$PKG.desktop"
chmod 644 "$ROOT/usr/share/applications/$PKG.desktop"

# ---- docs ----------------------------------------------------------
install -d "$ROOT/usr/share/doc/$PKG"
cat > "$ROOT/usr/share/doc/$PKG/copyright" <<COPYRIGHT
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: gamine-modern
Source: https://github.com/hakarune/gamine-modern

Files: *
Copyright: 2024 $MAINT_NAME
           2007-2019 Emmanuel Garette and the Gamine authors
License: GPL-3.0+
 This program is free software: you can redistribute it and/or modify it
 under the terms of the GNU General Public License as published by the Free
 Software Foundation, either version 3 of the License, or (at your option)
 any later version.
 .
 This program is distributed in the hope that it will be useful, but WITHOUT
 ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 .
 On Debian systems the full text of the GNU General Public License version 3
 can be found in /usr/share/common-licenses/GPL-3.
COPYRIGHT
chmod 644 "$ROOT/usr/share/doc/$PKG/copyright"

DATE_RFC="$(date -R)"
cat > "$BUILD/changelog.Debian" <<CHANGELOG
$PKG ($VERSION) unstable; urgency=low

  * HTML5 Canvas re-implementation of Gamine.
  * Shape stamping, colour cycling and mouse logic ported from gamine.c.
  * Sound samples replaced by a Web Audio synth.

 -- $MAINTAINER  $DATE_RFC
CHANGELOG
gzip -9n -c "$BUILD/changelog.Debian" > "$ROOT/usr/share/doc/$PKG/changelog.Debian.gz"
chmod 644 "$ROOT/usr/share/doc/$PKG/changelog.Debian.gz"

# ---- control metadata ------------------------------------------------
install -d "$ROOT/DEBIAN"
INSTALLED_KB="$(du -k -s "$ROOT" | cut -f1)"

cat > "$ROOT/DEBIAN/control" <<CONTROL
Package: $PKG
Version: $VERSION
Section: games
Priority: optional
Architecture: $ARCH
Depends: chromium | chromium-browser | google-chrome-stable | firefox-esr | firefox | www-browser
Installed-Size: $INSTALLED_KB
Maintainer: $MAINTAINER
Homepage: https://github.com/hakarune/gamine-modern
Description: drawing game for very young children (HTML5 port)
 Gamine is a game for toddlers who cannot yet use a mouse and keyboard.
 Moving the pointer draws bright coloured lines, clicking stamps colourful
 stars, and pressing keys stamps letters. Every action triggers a playful
 Web Audio sound.
 .
 This is a single-file HTML5 Canvas re-implementation of the original
 GTK/Cairo program by Emmanuel Garette.
CONTROL

# conffiles: none (index.html is data, not config)

# md5sums
( cd "$ROOT" && find . -type f ! -path './DEBIAN/*' -printf '%P\0' \
    | xargs -0 md5sum > DEBIAN/md5sums )
chmod 644 "$ROOT/DEBIAN/md5sums"

# ---- assemble ------------------------------------------------------
mkdir -p "$HERE/dist"
OUT="$HERE/dist/${PKG}_${VERSION}_${ARCH}.deb"

if command -v dpkg-deb >/dev/null 2>&1; then
    dpkg-deb --build --root-owner-group "$ROOT" "$OUT"
else
    echo ">> dpkg-deb not found; falling back to ar + tar"
    # Portable fallback so the script also works on non-Debian CI runners.
    ( cd "$ROOT/DEBIAN" && tar --numeric-owner --owner=0 --group=0 -czf "$BUILD/control.tar.gz" ./* )
    ( cd "$ROOT" && tar --numeric-owner --owner=0 --group=0 \
        --exclude=./DEBIAN -czf "$BUILD/data.tar.gz" ./* )
    echo "2.0" > "$BUILD/debian-binary"
    ( cd "$BUILD" && ar rc "$OUT" debian-binary control.tar.gz data.tar.gz )
fi

echo ">> Wrote $OUT"
command -v lintian >/dev/null 2>&1 && lintian --no-tag-display-limit "$OUT" || true
command -v dpkg-deb >/dev/null 2>&1 && dpkg-deb --info "$OUT" || true
