#!/usr/bin/env bash
# Build Hamlib (libhamlib-4.dll + rigctl/rotctl/ampctl tools) for Windows
# with an MSYS2 CLANG* toolchain, e.g. CLANGARM64 for Windows on Arm.
#
#   ci/build.sh HAMLIB_SRC_DIR BUILD_DIR PREFIX
set -euo pipefail

SRC=$(realpath "${1:?usage: build.sh HAMLIB_SRC_DIR BUILD_DIR PREFIX}")
BUILD=$(realpath -m "${2:?}")
PREFIX=$(realpath -m "${3:?}")
# clang reports e.g. aarch64-w64-windows-gnu; autotools wants -mingw32
HOST=$(clang -dumpmachine | sed 's/-windows-gnu$/-mingw32/')

# A git checkout (unlike a release tarball) has no generated configure.
[ -x "$SRC/configure" ] || (cd "$SRC" && ./bootstrap)

mkdir -p "$BUILD" "$PREFIX"
cd "$BUILD"
[ -f Makefile ] || "$SRC"/configure \
  --host="$HOST" --build="$HOST" --prefix="$PREFIX" \
  --enable-shared --disable-static \
  --without-cxx-binding --disable-pytest \
  CC=clang CXX=clang++ \
  CFLAGS="-g -O2 -fdata-sections -ffunction-sections" \
  LDFLAGS="-Wl,--gc-sections"
make -j"$(nproc)" all
make install-strip
