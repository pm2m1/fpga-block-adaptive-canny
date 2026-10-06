param(
  [Parameter(Mandatory=$true)][ValidateSet('vivado','xvlog','xelab','xsim','glbl')][string]$Tool,
  [string]$VivadoBin
)
$ErrorActionPreference='Stop'
if (-not $VivadoBin) { $VivadoBin=$env:VIVADO_BIN }
if (-not $VivadoBin) {
  $found=Get-Command vivado.bat -ErrorAction SilentlyContinue
  if ($found) { $VivadoBin=Split-Path -Parent $found.Source }
}
if (-not $VivadoBin) {
  throw 'Set VIVADO_BIN to the Vivado bin directory, or pass -VivadoBin.'
}
$bin=(Resolve-Path -LiteralPath $VivadoBin -ErrorAction Stop).Path
$path=if ($Tool -eq 'glbl') {
  Join-Path (Split-Path -Parent $bin) 'data/verilog/src/glbl.v'
} else {
  Join-Path $bin "$Tool.bat"
}
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing Vivado tool: $path" }
Write-Output $path
