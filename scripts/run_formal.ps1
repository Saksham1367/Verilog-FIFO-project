param(
    [string]$YosysPath = "C:\msys64\ucrt64\bin\yosys.exe",
    [string]$PythonPath = "python",
    [string]$SmtBmcScript = "C:\msys64\ucrt64\bin\yosys-smtbmc-script.py",
    [string]$SolverBinDir = "C:\msys64\ucrt64\bin"
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$reportsDir = Join-Path $projectRoot "reports\formal"
$artifactsDir = Join-Path $projectRoot "artifacts\formal"

New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null
New-Item -ItemType Directory -Force -Path $artifactsDir | Out-Null

$yosysBmcLog = Join-Path $reportsDir "yosys_formal_bmc.log"
$yosysInductionLog = Join-Path $reportsDir "yosys_formal_induction.log"
$bmcSmt2Path = Join-Path $artifactsDir "fifo_formal.smt2"
$inductionSmt2Path = Join-Path $artifactsDir "fifo_formal_induction.smt2"
$bmcLog = Join-Path $reportsDir "bmc.log"
$proveLog = Join-Path $reportsDir "prove.log"
$coverLog = Join-Path $reportsDir "cover.log"

& $YosysPath -l $yosysBmcLog -s (Join-Path $projectRoot "formal\fifo_formal.ys")
if ($LASTEXITCODE -ne 0) {
    throw "Yosys formal BMC preparation failed. See $yosysBmcLog"
}

& $YosysPath -l $yosysInductionLog -s (Join-Path $projectRoot "formal\fifo_formal_induction.ys")
if ($LASTEXITCODE -ne 0) {
    throw "Yosys formal induction preparation failed. See $yosysInductionLog"
}

$originalPath = $env:PATH
$env:PATH = "$SolverBinDir;$originalPath"

& $PythonPath $SmtBmcScript -s z3 --presat -t 18 --dump-vcd (Join-Path $artifactsDir "fifo_formal_bmc.vcd") $bmcSmt2Path 2>&1 | Tee-Object -FilePath $bmcLog
if ($LASTEXITCODE -ne 0) {
    $env:PATH = $originalPath
    throw "Formal BMC failed. See $bmcLog"
}

& $PythonPath $SmtBmcScript -s z3 --presat -i -t 18 $inductionSmt2Path 2>&1 | Tee-Object -FilePath $proveLog
if ($LASTEXITCODE -ne 0) {
    $env:PATH = $originalPath
    throw "Formal induction/prove failed. See $proveLog"
}

& $PythonPath $SmtBmcScript -s z3 -c -t 24 --dump-vcd (Join-Path $artifactsDir "fifo_formal_cover.vcd") $bmcSmt2Path 2>&1 | Tee-Object -FilePath $coverLog
if ($LASTEXITCODE -ne 0) {
    $env:PATH = $originalPath
    throw "Formal cover run failed. See $coverLog"
}

$env:PATH = $originalPath
