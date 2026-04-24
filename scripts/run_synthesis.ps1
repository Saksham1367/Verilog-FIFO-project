param(
    [string]$YosysPath = "C:\msys64\ucrt64\bin\yosys.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$reportsDir = Join-Path $projectRoot "reports\synthesis"
$artifactsDir = Join-Path $projectRoot "artifacts\netlist"

New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null
New-Item -ItemType Directory -Force -Path $artifactsDir | Out-Null

& $YosysPath -l (Join-Path $reportsDir "generic.log") -s (Join-Path $projectRoot "synthesis\generic.ys")
if ($LASTEXITCODE -ne 0) {
    throw "Generic synthesis failed."
}

& $YosysPath -l (Join-Path $reportsDir "xc7_ooc.log") -s (Join-Path $projectRoot "synthesis\xc7_ooc.ys")
if ($LASTEXITCODE -ne 0) {
    throw "XC7 out-of-context synthesis failed."
}
