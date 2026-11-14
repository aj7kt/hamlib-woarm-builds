#!/usr/bin/env bash
# Smoke test an installed Hamlib: tools start, report a version, every
# binary is ARM64, and rigctl can drive the dummy rig.
#
#   ci/test.sh PREFIX
set -uo pipefail
PREFIX=${1:?usage: test.sh PREFIX}
B=$PREFIX/bin
fail=0
ok ()  { printf 'PASS  %s\n' "$1"; }
bad () { printf 'FAIL  %s\n' "$1"; fail=1; }

ver=$("$B/rigctl.exe" --version 2>&1) && ok "rigctl --version: $ver" || bad "rigctl --version"

for f in "$B"/*.exe "$B"/*.dll; do
  fmt=$(llvm-objdump -f "$f" | grep -o 'coff-[a-z0-9-]*')
  [ "$fmt" = coff-arm64 ] || bad "not ARM64: $(basename "$f") ($fmt)"
done
[ $fail -eq 0 ] && ok "all binaries are ARM64"

# model 1 = dummy rig: set a frequency, read it back
out=$("$B/rigctl.exe" -m 1 F 14074000 f 2>&1)
if grep -qx '14074000' <<<"$(tr -d '\r' <<<"$out")"; then ok "dummy rig set/get frequency"
else bad "dummy rig set/get frequency: $out"; fi

exit $fail
