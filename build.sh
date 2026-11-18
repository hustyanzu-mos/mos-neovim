#!/usr/bin/env bash
# Build a local MOS plugin .deb for Neovim (host architecture).
# The Neovim release tree is embedded in the .deb and installed under /usr/lib/neovim.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

VERSION="${1:-${VERSION:-}}"
if [ -z "$VERSION" ]; then
  VERSION="$(node -e "import('./page/plugin.config.js').then(m => console.log(m.default.version))" 2>/dev/null || echo 0.2.2)"
fi

case "$(uname -m)" in
  x86_64|amd64) DEB_ARCH=amd64; NVIM_ARCH=x86_64 ;;
  aarch64|arm64) DEB_ARCH=arm64; NVIM_ARCH=arm64 ;;
  *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

PKG_NAME="neovim-${VERSION}-1+mos-plugin_${DEB_ARCH}"
PKG_DIR="$ROOT/build/${PKG_NAME}"
DEB_FILE="$ROOT/build/${PKG_NAME}.deb"
PAGE_DIST="$ROOT/page/dist/neovim"
NVIM_ASSET="nvim-linux-${NVIM_ARCH}.tar.gz"

echo "==> Neovim MOS plugin ${VERSION} (${DEB_ARCH})"

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

rm -rf "$PKG_DIR"
mkdir -p \
  "$PKG_DIR/DEBIAN" \
  "$PKG_DIR/usr/bin/plugins" \
  "$PKG_DIR/usr/lib" \
  "$PKG_DIR/usr/share/neovim-plugin" \
  "$PKG_DIR/var/www/mos-plugins/neovim"

echo "==> fetching Neovim ${NVIM_ASSET}"
REL="$(curl -fsSL --retry 2 https://api.github.com/repos/neovim/neovim/releases/latest)"
TAG="$(printf '%s' "$REL" | jq -r '.tag_name // empty')"
NVIM_VERSION="${TAG#v}"
[ -n "$NVIM_VERSION" ] || { echo "cannot read Neovim release" >&2; exit 1; }
URL="$(printf '%s' "$REL" | jq -r --arg n "$NVIM_ASSET" '.assets[] | select(.name == $n) | .browser_download_url' | head -n1)"
DIGEST="$(printf '%s' "$REL" | jq -r --arg n "$NVIM_ASSET" '.assets[] | select(.name == $n) | .digest // empty' | head -n1)"
[ -n "$URL" ] || { echo "no $NVIM_ASSET asset" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fsSL --retry 2 "$URL" -o "$TMP/nvim.tar.gz"
if [ -n "$DIGEST" ]; then
  case "$DIGEST" in sha256:*) DIGEST="${DIGEST#sha256:}" ;; esac
  printf '%s  %s\n' "$DIGEST" "$TMP/nvim.tar.gz" | sha256sum -c - >/dev/null
fi
mkdir -p "$PKG_DIR/usr/lib/neovim"
tar -xzf "$TMP/nvim.tar.gz" -C "$PKG_DIR/usr/lib/neovim" --strip-components=1 --no-same-owner
chmod 0755 "$PKG_DIR/usr/lib/neovim/bin/nvim"
"$PKG_DIR/usr/lib/neovim/bin/nvim" --version >/dev/null 2>&1 || { echo "Neovim does not run" >&2; exit 1; }

install -m 0755 "$ROOT/neovim-backend" "$PKG_DIR/usr/bin/plugins/neovim"
install -m 0755 "$ROOT/neovim-wrapper" "$PKG_DIR/usr/bin/nvim"

install -m 0755 "$ROOT/neovim-backend" "$PKG_DIR/usr/share/neovim-plugin/neovim-backend"
install -m 0755 "$ROOT/neovim-wrapper" "$PKG_DIR/usr/share/neovim-plugin/neovim-wrapper"
install -m 0755 "$ROOT/functions" "$PKG_DIR/usr/share/neovim-plugin/functions"
install -m 0644 "$ROOT/neovim-env" "$PKG_DIR/usr/share/neovim-plugin/neovim-env"
install -m 0644 "$ROOT/settings.json" "$PKG_DIR/usr/share/neovim-plugin/settings.json"

cp -a "$PAGE_DIST/." "$PKG_DIR/var/www/mos-plugins/neovim/"
install -m 0644 "$ROOT/images/neovim.png" "$PKG_DIR/var/www/mos-plugins/neovim/icon.png"

cat > "$PKG_DIR/DEBIAN/control" <<EOF
Package: neovim-plugin
Version: ${VERSION}-1+mos-plugin
Architecture: ${DEB_ARCH}
Maintainer: hustyanzu
Section: utils
Priority: optional
Description: Neovim plugin for MOS
 Vim-based text editor with config and data on the MOS pool.
EOF

install -m 0755 "$ROOT/debian/postinst" "$PKG_DIR/DEBIAN/postinst"
install -m 0755 "$ROOT/debian/postrm" "$PKG_DIR/DEBIAN/postrm"

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
echo "Neovim:  $NVIM_VERSION"
echo
echo "Install the plugin via MOS Hub."