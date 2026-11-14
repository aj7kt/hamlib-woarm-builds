# hamlib-woarm-builds

Native **Windows on Arm** (ARM64) builds of [Hamlib](https://github.com/Hamlib/Hamlib):
`libhamlib-4.dll` plus the `rigctl` / `rigctld` / `rotctl` / `ampctl` tools.

Built with the MSYS2 **CLANGARM64** toolchain (clang + LLVM lld) on GitHub's
`windows-11-arm` runners.

## Source

The workflow builds the `lld-add-stdcall-alias` branch of
[aj7kt/Hamlib](https://github.com/aj7kt/Hamlib): upstream's `Hamlib-4.7`
branch plus one configure fix, without which `libhamlib.dll` does not link
with lld (`--add-stdcall-alias` is only passed when the linker accepts it).
Once that fix is upstream, `HAMLIB_REPO` / `HAMLIB_REF` in
`.github/workflows/build.yml` can point at `Hamlib/Hamlib` directly.

## Releases

Each release (one per Hamlib commit) contains:

| File | Contents |
|---|---|
| `hamlib-<version>-<commit>-win-arm64.zip` | `bin/` (DLL, tools, dependency DLLs), `include/`, `lib/` (import library, pkg-config), licences, `BUILDINFO.txt` |
| `libhamlib-4.dll` | the DLL on its own, for applications that let you swap it (needs `libusb-1.0.dll` and `libwinpthread-1.dll` next to it, which such applications already ship) |
| `SHA256SUMS` | checksums of the above |

Builds run on every push and pull request (artifacts only). A release is
published by running the workflow manually with **publish** ticked; it is
skipped if that Hamlib commit already has one. To pick up new upstream
changes, sync/rebase the fork branch first.

## Local build

From an MSYS2 CLANGARM64 shell:

```sh
bash ci/build.sh   path/to/Hamlib build install
bash ci/test.sh    install
bash ci/package.sh path/to/Hamlib install dist
```
