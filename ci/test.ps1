# Smoke test a packaged Hamlib on Windows (no MSYS2 needed):
#   - every .exe/.dll is ARM64 (PE machine 0xAA64)
#   - rigctl starts and reports its version, using only the bundled DLLs
#   - rigctl drives the dummy rig (model 1): set/get frequency and mode
#
#   pwsh ci/test.ps1 -Bin path\to\bin
param([Parameter(Mandatory)] [string] $Bin)
$ErrorActionPreference = 'Stop'
$fail = 0
function Pass($m) { Write-Host "PASS  $m" }
function Fail($m) { Write-Host "FAIL  $m"; $script:fail = 1 }

$Bin = (Resolve-Path $Bin).Path
foreach ($f in Get-ChildItem $Bin -File | Where-Object Extension -in '.exe', '.dll') {
  $b = [IO.File]::ReadAllBytes($f.FullName)
  $pe = [BitConverter]::ToInt32($b, 0x3C)
  $machine = [BitConverter]::ToUInt16($b, $pe + 4)
  if ($machine -ne 0xAA64) { Fail ("not ARM64: {0} (machine 0x{1:X4})" -f $f.Name, $machine) }
}
if ($fail -eq 0) { Pass "all binaries are ARM64" }

# only the bundled DLLs (plus Windows itself) may be used
$env:PATH = "$Bin;" + (Join-Path $env:SystemRoot 'System32') + ";$env:SystemRoot"

$ver = & "$Bin\rigctl.exe" --version 2>&1
if ($LASTEXITCODE -eq 0) { Pass "rigctl --version: $ver" } else { Fail "rigctl --version (exit $LASTEXITCODE): $ver" }

$out = @(& "$Bin\rigctl.exe" -m 1 F 14074000 f M USB 2400 m 2>&1 | ForEach-Object { "$_".Trim() })
if ($LASTEXITCODE -eq 0 -and $out[0] -eq '14074000' -and $out[1] -eq 'USB' -and $out[2] -eq '2400') {
  Pass "dummy rig set/get frequency and mode"
} else {
  Fail "dummy rig (exit $LASTEXITCODE): $($out -join ' | ')"
}
exit $fail
