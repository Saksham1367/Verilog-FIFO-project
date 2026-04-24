param(
    [string]$PythonPath = "python"
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$reportsDir = Join-Path $projectRoot "reports\cdc"

New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null

& $PythonPath (Join-Path $PSScriptRoot "run_cdc_review.py") `
    --rtl (Join-Path $projectRoot "fifo.v") `
    --out (Join-Path $reportsDir "cdc_review.md")

if ($LASTEXITCODE -ne 0) {
    throw "CDC review generation failed."
}
