#!/usr/bin/env bash
# Build a local MOS plugin .deb for Neovim.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

VERSION="${1:-${VERSION:-}}"
if [ -z "$VERSION" ]; then
  VERSION="$(node -e "import('./page/plugin.config.js').then(m => console.log(m.default.version))" 2>/dev/null || echo 0.1.0)"
fi

PKG_NAME="neovim-${VERSION}-1+mos-plugin"
PKG_DIR="$ROOT/build/${PKG_NAME}_all"
DEB_FILE="$ROOT/build/${PKG_NAME}_all.deb"
PAGE_DIST="$ROOT/page/dist/neovim"

echo "==> Neovim MOS plugin ${VERSION}"

if [ "${SKIP_PAGE:-0}" != "1" ]; then
  if ! command -v npm >/dev/null 2>&1; then
    echo "npm is required to build the plugin page" >&2
    exit 1
  fi
  if [ ! -d "$ROOT/page/node_modules" ]; then
    echo "==> npm install"
    ( cd "$ROOT/page" && npm install )
  fi
  echo "==> building plugin page"
  ( cd "$ROOT/page" && PLUGIN_VERSION="$VERSION" npm run build )
fi

if [ ! -f "$PAGE_DIST/remoteEntry.js" ]; then
  echo "page build output missing: $PAGE_DIST/remoteEntry.js" >&2
  exit 1
fi

rm -rf "$ROOT/build"
mkdir -p \
  "$PKG_DIR/DEBIAN" \
  "$PKG_DIR/usr/bin/plugins" \
  "$PKG_DIR/usr/share/neovim-plugin" \
  "$PKG_DIR/var/www/mos-plugins/neovim"

install -m 0755 "$ROOT/neovim-backend" "$PKG_DIR/usr/bin/plugins/neovim"
install -m 0755 "$ROOT/neovim-wrapper" "$PKG_DIR/usr/bin/nvim"

install -m 0755 "$ROOT/neovim-backend" "$PKG_DIR/usr/share/neovim-plugin/neovim-backend"
install -m 0755 "$ROOT/neovim-wrapper" "$PKG_DIR/usr/share/neovim-plugin/neovim-wrapper"
install -m 0755 "$ROOT/functions" "$PKG_DIR/usr/share/neovim-plugin/functions"
install -m 0644 "$ROOT/settings.json" "$PKG_DIR/usr/share/neovim-plugin/settings.json"

cp -a "$PAGE_DIST/." "$PKG_DIR/var/www/mos-plugins/neovim/"
install -m 0644 "$ROOT/images/neovim.png" "$PKG_DIR/var/www/mos-plugins/neovim/icon.png"

cat > "$PKG_DIR/DEBIAN/control" <<EOF
Package: neovim-plugin
Version: ${VERSION}-1+mos-plugin
Architecture: all
Maintainer: hustyanzu
Section: utils
Priority: optional
Description: Neovim plugin for MOS
 Vim-based text editor with persistent config on MOS.
EOF

cat > "$PKG_DIR/DEBIAN/postinst" <<'EOF'
#!/bin/bash
set -e
PLG=/boot/optional/plugins/neovim
SHARE=/usr/share/neovim-plugin
mkdir -p "$PLG/config" "$PLG/data" "$PLG/state" "$PLG/cache"
chmod 0755 /usr/bin/plugins/neovim /usr/bin/nvim 2>/dev/null || true
for f in neovim-backend neovim-wrapper functions; do
  cp -f "$SHARE/$f" "$PLG/$f"
done
chmod 0755 "$PLG/neovim-backend" "$PLG/neovim-wrapper" "$PLG/functions" 2>/dev/null || true
if [ ! -f "$PLG/settings.json" ]; then
  cp -f "$SHARE/settings.json" "$PLG/settings.json"
fi
if [ -x "$PLG/nvim/bin/nvim" ]; then
  rm -rf /usr/lib/neovim.new
  cp -a "$PLG/nvim" /usr/lib/neovim.new
  printf '%s\n' "$(jq -r '.version // empty' "$PLG/settings.json" 2>/dev/null)" > /usr/lib/neovim.new/.mos-version
  rm -rf /usr/lib/neovim
  mv /usr/lib/neovim.new /usr/lib/neovim
fi
exit 0
EOF
chmod 0755 "$PKG_DIR/DEBIAN/postinst"

cat > "$PKG_DIR/DEBIAN/postrm" <<'EOF'
#!/bin/bash
rm -rf /usr/lib/neovim
exit 0
EOF
chmod 0755 "$PKG_DIR/DEBIAN/postrm"

echo "==> building ${DEB_FILE}"
if command -v dpkg-deb >/dev/null 2>&1; then
  dpkg-deb --build --root-owner-group "$PKG_DIR" "$DEB_FILE"
else
  WORK="$(mktemp -d)"
  trap 'rm -rf "$WORK"' EXIT
  printf '2.0\n' > "$WORK/debian-binary"
  ( cd "$PKG_DIR/DEBIAN" && tar --owner=0 --group=0 --numeric-owner -czf "$WORK/control.tar.gz" . )
  ( cd "$PKG_DIR" && tar --owner=0 --group=0 --numeric-owner --exclude=./DEBIAN -czf "$WORK/data.tar.gz" . )
  ( cd "$WORK" && ar rcs "$DEB_FILE" debian-binary control.tar.gz data.tar.gz )
fi

md5sum "$DEB_FILE" | awk '{print $1}' > "$DEB_FILE.md5"

echo
echo "Package: $DEB_FILE"
echo "MD5:     $(cat "$DEB_FILE.md5")"
echo
echo "Install on MOS:  dpkg -i $(basename "$DEB_FILE")"
echo "Then open Plugins -> Neovim and click Install."