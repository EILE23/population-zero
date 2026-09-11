$ErrorActionPreference = 'Stop'
$pozLibrary = 'C:\Users\Administrator\Documents\aproject\population-zero\brand'
if (-not (Test-Path -LiteralPath $pozLibrary -PathType Container)) { throw 'Expected brand library is missing.' }
$pozBoundary = [IO.Path]::GetFullPath($pozLibrary).TrimEnd('\') + '\'
$pozBackup = Join-Path $pozLibrary ('legacy-before-poz-complete-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
function Copy-PozFile([string]$pozSource, [string]$pozRelative) {
  if (-not (Test-Path -LiteralPath $pozSource -PathType Leaf)) { throw "Missing source: $pozSource" }
  $pozTarget = [IO.Path]::GetFullPath((Join-Path $pozLibrary $pozRelative))
  if (-not $pozTarget.StartsWith($pozBoundary, [StringComparison]::OrdinalIgnoreCase)) { throw 'Target escapes brand library.' }
  if (Test-Path -LiteralPath $pozTarget) {
    $pozBackupFile = Join-Path $pozBackup $pozRelative
    New-Item -ItemType Directory -Path (Split-Path $pozBackupFile) -Force | Out-Null
    Copy-Item -LiteralPath $pozTarget -Destination $pozBackupFile
  }
  New-Item -ItemType Directory -Path (Split-Path $pozTarget) -Force | Out-Null
  Copy-Item -LiteralPath $pozSource -Destination $pozTarget
}
$pozTopFiles = @('BRAND_GUIDE.md', 'index.html', 'README.md', 'QA.md', 'wordmark.svg', 'preview.png', 'app-icon.png', 'app-icon-mauve.png')
foreach ($pozName in $pozTopFiles) { Copy-PozFile (Join-Path $PSScriptRoot $pozName) "poz-current\$pozName" }
foreach ($pozFolder in @('characters', 'favicon')) {
  $pozSourceFolder = Join-Path $PSScriptRoot $pozFolder
  foreach ($pozFile in Get-ChildItem -LiteralPath $pozSourceFolder -File -Recurse) {
    $pozRelative = [IO.Path]::GetRelativePath($PSScriptRoot, $pozFile.FullName)
    Copy-PozFile $pozFile.FullName "poz-current\$pozRelative"
  }
}
# Existing character-library entry point remains up to date, without deleting legacy art.
foreach ($pozFile in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'characters') -File -Recurse) {
  $pozRelative = [IO.Path]::GetRelativePath((Join-Path $PSScriptRoot 'characters'), $pozFile.FullName)
  Copy-PozFile $pozFile.FullName "characters\poz-current\$pozRelative"
}
Copy-PozFile (Join-Path $PSScriptRoot 'characters\CAST.md') 'characters\CAST.md'
Copy-PozFile (Join-Path $PSScriptRoot 'library-entry.md') 'BRAND_GUIDE.md'
Copy-PozFile (Join-Path $PSScriptRoot 'characters\library-index.html') 'characters\index.html'
Write-Output "Complete brand set: $pozLibrary\poz-current"
Write-Output "Previous overwritten files preserved: $pozBackup"
Write-Output 'No files deleted. Legacy 3D artwork and animations remain available.'
