$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Push-Location $workspace
try {
  $bit=Get-Item -LiteralPath results/phase11/canny_nexys_a7.bit
  $dcp=Get-Item -LiteralPath results/phase11/canny_nexys_a7_phase11_rev3_routed.dcp
  $hash=(Get-FileHash -LiteralPath $bit.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  # The bitstream was generated at the Phase 11 checkpoint, not the
  # publication branch's current documentation commit.
  $head='3b960d1'
  @(
    "checkpoint=$head"
    "target=xc7a100tcsg324-1"
    "bitstream=results/phase11/canny_nexys_a7.bit"
    "bitstream_bytes=$($bit.Length)"
    "bitstream_sha256=$hash"
    "routed_checkpoint=results/phase11/canny_nexys_a7_phase11_rev3_routed.dcp"
    "routed_checkpoint_bytes=$($dcp.Length)"
    "physical_board_available=NO"
  ) | Set-Content -LiteralPath reports/phase11v/bitstream_identity.txt
  Get-Content reports/phase11v/bitstream_identity.txt
} finally { Pop-Location }
