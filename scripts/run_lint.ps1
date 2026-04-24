param(
    [string]$BashPath = "C:\msys64\usr\bin\bash.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$reportsDir = Join-Path $projectRoot "reports\lint"

New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null

$lintLog = Join-Path $reportsDir "verilator_rtl.txt"
$msysProjectRoot = "/" + $projectRoot.Substring(0,1).ToLower() + ($projectRoot.Substring(2) -replace "\\","/")
$command = "export PATH=/ucrt64/bin:/usr/bin:`$PATH; cd '$msysProjectRoot'; verilator --lint-only -Wall fifo.v"

& $BashPath -lc $command 2>&1 | Tee-Object -FilePath $lintLog
if ($LASTEXITCODE -ne 0) {
    throw "Verilator lint failed. See $lintLog"
}
