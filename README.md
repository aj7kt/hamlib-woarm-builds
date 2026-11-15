# hamlib-woarm-builds

Native **Windows on Arm** (ARM64) builds of [Hamlib](https://github.com/Hamlib/Hamlib):
`libhamlib-4.dll` plus the `rigctl` / `rigctld` / `rotctl` / `ampctl` tools.

Cross-compiled on GitHub's `ubuntu-24.04-arm` runners with
[llvm-mingw](https://github.com/mstorsjo/llvm-mingw) (clang + LLVM lld,
pinned release in `ci/setup-cross.sh`), linking the MSYS2 **CLANGARM64**
builds of libusb and readline. Autotools and libtool run about ten times
faster there than under MSYS2 on Windows (about 1.5 instead of 17 minutes).
Every build is then tested on a `windows-11-arm` runner: all binaries are
ARM64, `rigctl` runs with only the bundled DLLs, and drives the dummy rig.

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

Builds never publish anything by themselves. Every successful push or
manual build of a branch updates that branch's standing **draft** release
(tag `next-<branch>`, e.g. `next-main`) in place with its files and notes;
drafts are visible only to people with write access. Pull request builds
only upload workflow artifacts.

To release: run the workflow (Actions → *Hamlib for Windows on Arm* → Run
workflow; pick the Hamlib ref), download the draft's files and test them,
then edit the draft, set its tag to the package name its notes give (e.g.
`hamlib-4.7.3-rc-f788e348d-win-arm64`; WS builds pin Hamlib by that tag)
and publish. The next build starts a new standing draft. To pick up new
upstream changes, sync/rebase the fork branch first.

## Local build

On Linux (arm64 or x86_64, e.g. in an `ubuntu:24.04` container), with
autotools, libtool, pkg-config, make, texinfo, zip, zstd and xz installed:

```sh
bash ci/setup-cross.sh /opt/woa-tools
source /opt/woa-tools/env.sh
bash ci/build.sh   path/to/Hamlib build install
bash ci/package.sh path/to/Hamlib install dist
```

Or natively in an MSYS2 CLANGARM64 shell on Windows on Arm (no
`setup-cross.sh`; slower). Test a package on Windows on Arm with:

```powershell
pwsh ci/test.ps1 -Bin path\to\hamlib-...-win-arm64\bin
```
