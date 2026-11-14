#!/usr/bin/env bash
# Package an installed Hamlib for release:
#   DIST/hamlib-<ver>-win-arm64.zip  full kit: DLLs, tools, headers, import lib
#   DIST/libhamlib-4.dll             the DLL alone (what applications swap in)
#   DIST/SHA256SUMS
#
#   ci/package.sh HAMLIB_SRC_DIR PREFIX DIST_DIR
# Prints the release name (hamlib-<ver>-win-arm64) on stdout.
set -euo pipefail
SRC=${1:?usage: package.sh HAMLIB_SRC_DIR PREFIX DIST_DIR}
PREFIX=${2:?}
DIST=$(realpath -m "${3:?}")   # absolute: used after cd below
MP=${MINGW_PREFIX:?run from an MSYS2 CLANG* shell}

# e.g. "Hamlib 4.7.3~rc 2026-11-14T22:39:38Z SHA=f788e348d 64-bit"
verline=$("$PREFIX/bin/rigctl.exe" --version | tr -d '\r')
ver=$(awk '{print $3}' <<<"$verline" | tr '~' '-')
sha=$(git -C "$SRC" rev-parse --short=9 HEAD)
name="hamlib-$ver-$sha-win-arm64"

stage=$(mktemp -d)/$name
mkdir -p "$stage/bin" "$stage/lib" "$stage/include"
cp "$PREFIX"/bin/*.exe "$PREFIX"/bin/libhamlib-*.dll "$stage/bin/"
cp -r "$PREFIX/include/hamlib" "$stage/include/"
cp "$PREFIX"/lib/libhamlib.dll.a "$stage/lib/"
[ -d "$PREFIX/lib/pkgconfig" ] && cp -r "$PREFIX/lib/pkgconfig" "$stage/lib/"

# Bundle the non-system DLLs the binaries import (libusb, winpthread, and
# for the tools readline/termcap), resolved recursively from the toolchain.
need=$(for f in "$stage"/bin/*.exe "$stage"/bin/*.dll; do
         llvm-objdump -p "$f" | awk '/DLL Name/{print $3}'; done | sort -u)
while [ -n "$need" ]; do
  next=""
  for d in $need; do
    [ -e "$stage/bin/$d" ] && continue
    if [ -e "$MP/bin/$d" ]; then
      cp "$MP/bin/$d" "$stage/bin/"
      next+=" $(llvm-objdump -p "$MP/bin/$d" | awk '/DLL Name/{print $3}')"
    fi
  done
  need=$(tr ' ' '\n' <<<"$next" | sort -u | grep -v '^$' || true)
done

for f in COPYING COPYING.LIB LICENSE README.md NEWS; do
  [ -f "$SRC/$f" ] && cp "$SRC/$f" "$stage/"
done
{
  echo "$verline"
  echo "source: $(git -C "$SRC" remote get-url origin 2>/dev/null || echo '?') $(git -C "$SRC" rev-parse HEAD)"
  echo "describe: $(git -C "$SRC" describe --tags --always 2>/dev/null || true)"
  echo "toolchain: $(clang --version | head -1)"
  echo "built: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "bundled DLLs: $(cd "$stage/bin" && ls *.dll | tr '\n' ' ')"
} > "$stage/BUILDINFO.txt"

mkdir -p "$DIST"
(cd "$(dirname "$stage")" && 7z a -tzip -bso0 -bsp0 "$DIST/$name.zip" "$name")
cp "$stage"/bin/libhamlib-*.dll "$DIST/"
cp "$stage/BUILDINFO.txt" "$DIST/$name-BUILDINFO.txt"
(cd "$DIST" && sha256sum *.zip *.dll > SHA256SUMS)
echo "$name"
