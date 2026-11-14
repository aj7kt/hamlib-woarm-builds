#!/usr/bin/env bash
# Package an installed Hamlib for release:
#   DIST/hamlib-<ver>-<commit>-win-arm64.zip  DLLs, tools, headers, import lib
#   DIST/libhamlib-4.dll                      the DLL alone (what applications swap in)
#   DIST/<name>-BUILDINFO.txt
#   DIST/SHA256SUMS
#
#   ci/package.sh HAMLIB_SRC_DIR PREFIX DIST_DIR
#
# Dependency DLLs are looked up in DLL_PATH (colon separated; set by
# ci/setup-cross.sh) or, in an MSYS2 shell, $MINGW_PREFIX/bin.
# Prints the release name on stdout.
set -euo pipefail
SRC=$(realpath "${1:?usage: package.sh HAMLIB_SRC_DIR PREFIX DIST_DIR}")
PREFIX=$(realpath "${2:?}")
DIST=$(realpath -m "${3:?}")   # absolute: used after cd below
DLL_PATH=${DLL_PATH:-${MINGW_PREFIX:+$MINGW_PREFIX/bin}}
[ -n "$DLL_PATH" ] || { echo "set DLL_PATH (see ci/setup-cross.sh)" >&2; exit 1; }
CLANG=${WIN_HOST:+$WIN_HOST-}clang

# version from configure.ac, e.g. AC_INIT([Hamlib],[4.7.3~rc],...)
ver=$(sed -n 's/^AC_INIT(\[Hamlib\],\[\([^]]*\)\].*/\1/p' "$SRC/configure.ac" | head -1 | tr '~' '-')
sha=$(git -C "$SRC" rev-parse --short=9 HEAD)
name="hamlib-$ver-$sha-win-arm64"

stage=$(mktemp -d)/$name
mkdir -p "$stage/bin" "$stage/lib" "$stage/include"
cp "$PREFIX"/bin/*.exe "$PREFIX"/bin/libhamlib-*.dll "$stage/bin/"
cp -r "$PREFIX/include/hamlib" "$stage/include/"
cp "$PREFIX"/lib/libhamlib.dll.a "$stage/lib/"
[ -d "$PREFIX/lib/pkgconfig" ] && cp -r "$PREFIX/lib/pkgconfig" "$stage/lib/"

find_dll () {
  local IFS=:
  for d in $DLL_PATH; do [ -e "$d/$1" ] && { echo "$d/$1"; return 0; }; done
  return 1
}
imports () { llvm-objdump -p "$1" | awk '/DLL Name/{print $3}'; }

# Bundle the non-system DLLs the binaries import (libusb, winpthread, and
# for the tools readline/termcap), resolved recursively.
need=$(for f in "$stage"/bin/*.exe "$stage"/bin/*.dll; do imports "$f"; done | sort -u)
while [ -n "$need" ]; do
  next=""
  for d in $need; do
    [ -e "$stage/bin/$d" ] && continue
    if p=$(find_dll "$d"); then
      cp "$p" "$stage/bin/"
      next+=" $(imports "$p" | tr '\n' ' ')"
    fi
  done
  need=$(tr ' ' '\n' <<<"$next" | grep -v '^$' | sort -u || true)
done

for f in COPYING COPYING.LIB LICENSE README.md NEWS; do
  [ -f "$SRC/$f" ] && cp "$SRC/$f" "$stage/"
done

# Where the built commit stands relative to upstream Hamlib: the upstream
# commit it is based on, any (fork) commits on top, and how far that base
# is behind the upstream branch head at build time.
UPSTREAM_REPO=${UPSTREAM_REPO:-Hamlib/Hamlib}
UPSTREAM_BRANCH=${UPSTREAM_BRANCH:-Hamlib-4.7}
upstream_info () {
  local head base n
  if ! git -C "$SRC" fetch --quiet --no-tags "https://github.com/$UPSTREAM_REPO.git" \
         "+refs/heads/$UPSTREAM_BRANCH:refs/upstream-info/head" 2>/dev/null; then
    echo "upstream: $UPSTREAM_REPO $UPSTREAM_BRANCH: could not be fetched"
    return
  fi
  head=$(git -C "$SRC" rev-parse refs/upstream-info/head)
  base=$(git -C "$SRC" merge-base HEAD "$head") || {
    echo "upstream: $UPSTREAM_REPO $UPSTREAM_BRANCH: no common history"; return; }
  echo "upstream: $UPSTREAM_REPO $UPSTREAM_BRANCH @ $(git -C "$SRC" log -1 --date=short --format='%h (%cd) %s' "$base")"
  n=$(git -C "$SRC" rev-list --count "$base..HEAD")
  if [ "$n" -eq 0 ]; then
    echo "  built from that upstream commit"
  else
    echo "  plus $n commit(s) not in upstream:"
    git -C "$SRC" log --reverse --format='    %h %s' "$base..HEAD"
  fi
  n=$(git -C "$SRC" rev-list --count "$base..$head")
  if [ "$n" -eq 0 ]; then
    echo "  upstream $UPSTREAM_BRANCH has no newer commits"
  else
    echo "  upstream $UPSTREAM_BRANCH head $(git -C "$SRC" rev-parse --short=9 "$head") is $n commit(s) newer"
  fi
  git -C "$SRC" update-ref -d refs/upstream-info/head
}

{
  echo "Hamlib $ver ($(git -C "$SRC" describe --tags --always 2>/dev/null || echo "$sha"))"
  echo "source: $(git -C "$SRC" remote get-url origin 2>/dev/null || echo '?') $(git -C "$SRC" rev-parse HEAD)"
  upstream_info
  echo "toolchain: $($CLANG --version | head -1)"
  echo "host: $(uname -sm)"
  echo "built: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "bundled DLLs: $(cd "$stage/bin" && ls *.dll | tr '\n' ' ')"
  [ -n "${TARGET_PACKAGES_FILE:-}" ] && [ -f "$TARGET_PACKAGES_FILE" ] && cat "$TARGET_PACKAGES_FILE"
} > "$stage/BUILDINFO.txt"

mkdir -p "$DIST"
(cd "$(dirname "$stage")" && zip -qr "$DIST/$name.zip" "$name")
cp "$stage"/bin/libhamlib-*.dll "$DIST/"
cp "$stage/BUILDINFO.txt" "$DIST/$name-BUILDINFO.txt"
(cd "$DIST" && sha256sum *.zip *.dll > SHA256SUMS)
echo "$name"
