param(
    [string]$PythonPath = "python"
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

& (Join-Path $PSScriptRoot "run_sim.ps1")
& $PythonPath (Join-Path $PSScriptRoot "export_wave_plots.py") --vcd (Join-Path $projectRoot "fifo.vcd") --outdir (Join-Path $projectRoot "artifacts\waveforms")
& (Join-Path $PSScriptRoot "open_wave.ps1")
