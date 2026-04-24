param(
    [string]$PythonPath = "python"
)

$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "run_sim.ps1")
& (Join-Path $PSScriptRoot "run_lint.ps1")
& (Join-Path $PSScriptRoot "run_cdc.ps1") -PythonPath $PythonPath
& (Join-Path $PSScriptRoot "run_formal.ps1") -PythonPath $PythonPath
& (Join-Path $PSScriptRoot "run_synthesis.ps1")
