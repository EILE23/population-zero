param([switch]$CleanLegacy, [switch]$Preview, [switch]$Permanent)
$ErrorActionPreference = 'Stop'
if ($Permanent -and -not $CleanLegacy) { throw 'Permanent requires an explicitly requested legacy cleanup.' }
$pozLibrary = 'C:\Users\Administrator\Documents\aproject\population-zero'
$pozStage = Join-Path $PSScriptRoot '.library-stage'
& node (Join-Path $PSScriptRoot 'export-library.mjs')
if ($LASTEXITCODE -ne 0) { throw 'Library export failed; no Documents files changed.' }
if (-not (Test-Path -LiteralPath $pozLibrary -PathType Container)) { throw 'Expected Documents library is missing.' }
$pozBoundary = [IO.Path]::GetFullPath($pozLibrary).TrimEnd('\') + '\'
$pozManifest = Get-Content -LiteralPath (Join-Path $pozStage 'manifest.json') -Raw | ConvertFrom-Json
function Resolve-PozTarget([string]$pozRelative) {
  $pozTarget = [IO.Path]::GetFullPath((Join-Path $pozLibrary $pozRelative))
  if (-not $pozTarget.StartsWith($pozBoundary, [StringComparison]::OrdinalIgnoreCase)) { throw "Target escapes library: $pozRelative" }
  if ($pozRelative -notmatch '^(brand|video)/' -or $pozRelative.Contains('..')) { throw "Unexpected target: $pozRelative" }
  $pozAncestor = $pozTarget
  while ($pozAncestor.Length -ge $pozLibrary.Length) {
    if ((Test-Path -LiteralPath $pozAncestor) -and ((Get-Item -LiteralPath $pozAncestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Linked path refused: $pozAncestor" }
    $pozAncestor = Split-Path $pozAncestor
  }
  return $pozTarget
}
# Resolve every target and reject junctions before modifying anything.
foreach ($pozRelative in $pozManifest.files) {
  $null = Resolve-PozTarget $pozRelative
  if (-not (Test-Path -LiteralPath (Join-Path $pozStage $pozRelative) -PathType Leaf)) { throw "Missing source: $pozRelative" }
}
$pozRemovals = @()
foreach ($pozRelative in $pozManifest.obsolete) {
  $pozTarget = Resolve-PozTarget $pozRelative
  if (Test-Path -LiteralPath $pozTarget) {
    if (Get-ChildItem -LiteralPath $pozTarget -Force -Recurse | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { throw "Linked descendant refused: $pozTarget" }
    $pozRemovals += $pozTarget
  }
}
if ($Preview) {
  Write-Output "Final files to copy and verify: $($pozManifest.files.Count)"
  Write-Output "Existing obsolete items to recycle: $($pozRemovals.Count)"
  $pozRemovals | Write-Output
  return
}
if ($CleanLegacy -and -not $Permanent) { Add-Type -AssemblyName Microsoft.VisualBasic }
foreach ($pozRelative in $pozManifest.files) {
  $pozTarget = Resolve-PozTarget $pozRelative
  New-Item -ItemType Directory -Path (Split-Path $pozTarget) -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $pozStage $pozRelative) -Destination $pozTarget
}
# Verify all final copies before recycling any old versions.
foreach ($pozRelative in $pozManifest.files) {
  if ((Get-FileHash -LiteralPath (Join-Path $pozStage $pozRelative)).Hash -ne (Get-FileHash -LiteralPath (Resolve-PozTarget $pozRelative)).Hash) { throw "Verification failed: $pozRelative. Legacy files were not removed." }
}
if ($CleanLegacy) {
  $pozCleanupErrors = @()
  $pozRemovedCount = 0
  foreach ($pozTarget in $pozRemovals) {
    $pozRelative = [IO.Path]::GetRelativePath($pozLibrary, $pozTarget).Replace('\', '/')
    if (-not ($pozManifest.obsolete -contains $pozRelative)) { throw 'Removal is not in the inspected manifest.' }
    $null = Resolve-PozTarget $pozRelative
    try {
    if ($Permanent) {
      # Exact preflighted targets only. Never remove the library or an owner folder.
      Remove-Item -LiteralPath $pozTarget -Recurse -Force
    } elseif (Test-Path -LiteralPath $pozTarget -PathType Container) {
      [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($pozTarget, [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs, [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin, [Microsoft.VisualBasic.FileIO.UICancelOption]::ThrowException)
    } else {
      [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($pozTarget, [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs, [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin, [Microsoft.VisualBasic.FileIO.UICancelOption]::ThrowException)
    }
    if (Test-Path -LiteralPath $pozTarget) { throw "Cleanup did not remove: $pozTarget" }
    $pozRemovedCount++
    } catch {
      $pozCleanupErrors += "$pozRelative : $($_.Exception.Message)"
    }
  }
  if ($Permanent) { Write-Output "Permanently removed $pozRemovedCount obsolete files/folders. Not recoverable from Recycle Bin." }
  else { Write-Output "Recycled $pozRemovedCount obsolete files/folders. Recoverable from Windows Recycle Bin." }
  if ($pozCleanupErrors.Count) {
    $pozCleanupErrors | Write-Output
    throw "Cleanup incomplete: $($pozCleanupErrors.Count) items remain. No automatic permanent-delete fallback."
  }
}
Write-Output "Verified $($pozManifest.files.Count) final files. Guide: $pozLibrary\brand\index.html"
Write-Output 'No legacy backup or poz-current folder created.'
