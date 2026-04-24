param(
    [string]$IverilogPath = "C:\iverilog\bin\iverilog.exe",
    [string]$VvpPath = "C:\iverilog\bin\vvp.exe",
    [string]$OutputName = "fifo_tb"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $IverilogPath)) {
    throw "iverilog executable not found at '$IverilogPath'."
}

if (-not (Test-Path $VvpPath)) {
    throw "vvp executable not found at '$VvpPath'."
}

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $projectRoot

try {
    & $IverilogPath -g2012 -Wall -o $OutputName fifo.v tb_fifo.v
    & $VvpPath (Join-Path "." $OutputName)
} finally {
    Pop-Location
}
