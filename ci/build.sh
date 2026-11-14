#!/usr/bin/env bash
# Build Hamlib (libhamlib-4.dll + rigctl/rotctl/ampctl tools) for
# Windows on Arm.
#
#   ci/build.sh HAMLIB_SRC_DIR BUILD_DIR PREFIX
#
# Cross build on Linux: source TOOLS_DIR/env.sh from ci/setup-cross.sh first
# (sets WIN_HOST and WIN_SYSROOT). Without WIN_HOST this is a native build
# in an MSYS2 CLANG* shell (e.g. CLANGARM64).
set -euo pipefail

SRC=$(realpath "${1:?usage: build.sh HAMLIB_SRC_DIR BUILD_DIR PREFIX}")
BUILD=$(realpath -m "${2:?}")
PREFIX=$(realpath -m "${3:?}")

if [ -n "${WIN_HOST:-}" ]; then
  host_args=(--host="$WIN_HOST")
  tools=(CC="$WIN_HOST-clang" CXX="$WIN_HOST-clang++")
  cppflags="-I$WIN_SYSROOT/include"
  ldflags="-L$WIN_SYSROOT/lib"
else
  # clang reports e.g. aarch64-w64-windows-gnu; autotools wants -mingw32
  h=$(clang -dumpmachine | sed 's/-windows-gnu$/-mingw32/')
  host_args=(--host="$h" --build="$h")
  tools=(CC=clang CXX=clang++)
  cppflags=""; ldflags=""
fi

# A git checkout (unlike a release tarball) has no generated configure.
[ -x "$SRC/configure" ] || (cd "$SRC" && ./bootstrap)

mkdir -p "$BUILD" "$PREFIX"
cd "$BUILD"
[ -f Makefile ] || "$SRC"/configure \
  "${host_args[@]}" --prefix="$PREFIX" \
  --enable-shared --disable-static \
  --without-cxx-binding --disable-pytest \
  "${tools[@]}" \
  CPPFLAGS="$cppflags" \
  CFLAGS="-g -O2 -fdata-sections -ffunction-sections" \
  LDFLAGS="$ldflags -Wl,--gc-sections"
make -j"$(nproc)" all
make install-strip
