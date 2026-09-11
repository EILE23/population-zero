$ErrorActionPreference = 'Stop'
$pozExportRoot = Join-Path $PSScriptRoot 'distribution'
$pozLibrary = 'C:\Users\Administrator\Documents\aproject\population-zero\brand'
$pozBackup = Join-Path $pozLibrary ('legacy-before-poz-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$pozRootResolved = [IO.Path]::GetFullPath($pozLibrary).TrimEnd('\') + '\'
if (-not (Test-Path -LiteralPath $pozLibrary -PathType Container)) { throw 'Expected brand library is missing.' }

foreach ($pozFile in Get-ChildItem -LiteralPath $pozExportRoot -File -Recurse) {
  $pozRelative = [IO.Path]::GetRelativePath($pozExportRoot, $pozFile.FullName)
  $pozTarget = [IO.Path]::GetFullPath((Join-Path $pozLibrary $pozRelative))
  if (-not $pozTarget.StartsWith($pozRootResolved, [StringComparison]::OrdinalIgnoreCase)) { throw 'Target escapes the brand library.' }
  if (Test-Path -LiteralPath $pozTarget) {
    $pozBackupFile = Join-Path $pozBackup $pozRelative
    New-Item -ItemType Directory -Path (Split-Path $pozBackupFile) -Force | Out-Null
    Copy-Item -LiteralPath $pozTarget -Destination $pozBackupFile
  }
  New-Item -ItemType Directory -Path (Split-Path $pozTarget) -Force | Out-Null
  Copy-Item -LiteralPath $pozFile.FullName -Destination $pozTarget
}
$pozFinal = Join-Path $pozLibrary 'logo\poz-current'
New-Item -ItemType Directory -Path $pozFinal -Force | Out-Null
foreach ($pozName in @('wordmark.svg', 'preview.png', 'app-icon.png', 'app-icon-mauve.png', 'README.md')) {
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot $pozName) -Destination (Join-Path $pozFinal $pozName)
}
$pozWebAssets = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\site\public\brand'))
foreach ($pozName in @('poz-wordmark.svg', 'poz-wordmark-light.svg', 'poz-wordmark.png', 'poz-wordmark-light.png', 'poz-lockup.svg', 'poz-lockup-dark.svg', 'poz-lockup.png', 'poz-lockup-dark.png')) {
  Copy-Item -LiteralPath (Join-Path $pozWebAssets $pozName) -Destination (Join-Path $pozFinal $pozName)
}
Write-Output "Updated: $pozLibrary"
Write-Output "Previous logo and OG files preserved: $pozBackup"
