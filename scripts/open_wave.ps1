param(
    [string]$GtkWavePath = "C:\msys64\ucrt64\bin\gtkwave.exe",
    [string]$DumpFile = "fifo.vcd",
    [string]$ScriptFile = "scripts\gtkwave_setup.tcl"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $GtkWavePath)) {
    throw "gtkwave executable not found at '$GtkWavePath'."
}

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$dumpPath = Resolve-Path (Join-Path $projectRoot $DumpFile)
$scriptPath = Resolve-Path (Join-Path $projectRoot $ScriptFile)

Start-Process -FilePath $GtkWavePath -ArgumentList @(
    "-f",
    $dumpPath.Path,
    "-S",
    $scriptPath.Path
)
