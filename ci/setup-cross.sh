#!/usr/bin/env bash
# Set up an aarch64-w64-mingw32 cross toolchain on an arm64 (or x86_64)
# Linux host: llvm-mingw plus MSYS2 CLANGARM64 packages as the target
# sysroot (the same libusb/readline/termcap binaries a native MSYS2 build
# links). Writes TOOLS_DIR/env.sh to source before building.
#
#   ci/setup-cross.sh TOOLS_DIR
#
# Needs: curl, tar with xz and zstd support.
set -euo pipefail
TOOLS=$(realpath -m "${1:?usage: setup-cross.sh TOOLS_DIR}")
LLVM_MINGW=${LLVM_MINGW:-20261104}          # LLVM 23.1.5
TARGET_PKGS=${TARGET_PKGS:-"libusb readline termcap"}
MSYS2_REPO=https://repo.msys2.org/mingw/clangarm64

case $(uname -m) in
  aarch64) host=aarch64 ;;
  x86_64)  host=x86_64 ;;
  *) echo "unsupported host $(uname -m)" >&2; exit 1 ;;
esac

mkdir -p "$TOOLS/llvm-mingw" "$TOOLS/sysroot"
url=https://github.com/mstorsjo/llvm-mingw/releases/download/$LLVM_MINGW/llvm-mingw-$LLVM_MINGW-ucrt-ubuntu-22.04-$host.tar.xz
echo "llvm-mingw: $url"
curl -fsSL "$url" | tar -xJ -C "$TOOLS/llvm-mingw" --strip-components=1

index=$(curl -fsSL "$MSYS2_REPO/")
: > "$TOOLS/target-packages.txt"
for n in $TARGET_PKGS; do
  f=$(grep -oE "mingw-w64-clang-aarch64-$n-[0-9~][^\"]*-any\.pkg\.tar\.zst" <<<"$index" |
      grep -v '\.sig' | sort -uV | tail -1)
  [ -n "$f" ] || { echo "no MSYS2 package for $n" >&2; exit 1; }
  echo "target: $f" | tee -a "$TOOLS/target-packages.txt"
  curl -fsSL "$MSYS2_REPO/$f" | tar --zstd -x -C "$TOOLS/sysroot"
done

cat > "$TOOLS/env.sh" <<EOF
export PATH="$TOOLS/llvm-mingw/bin:\$PATH"
export WIN_HOST=aarch64-w64-mingw32
export WIN_SYSROOT="$TOOLS/sysroot/clangarm64"
export PKG_CONFIG_LIBDIR="$TOOLS/sysroot/clangarm64/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="$TOOLS/sysroot"
# where package.sh looks for the DLLs the binaries import
export DLL_PATH="$TOOLS/sysroot/clangarm64/bin:$TOOLS/llvm-mingw/aarch64-w64-mingw32/bin"
EOF
"$TOOLS/llvm-mingw/bin/aarch64-w64-mingw32-clang" --version | head -1
