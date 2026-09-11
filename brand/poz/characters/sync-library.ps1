$ErrorActionPreference = 'Stop'
$pozCharactersLibrary = 'C:\Users\Administrator\Documents\aproject\population-zero\brand\characters'
if (-not (Test-Path -LiteralPath $pozCharactersLibrary -PathType Container)) { throw 'Expected character library is missing.' }
$pozBoundary = [IO.Path]::GetFullPath($pozCharactersLibrary).TrimEnd('\') + '\'
$pozBackup = Join-Path $pozCharactersLibrary ('legacy-before-poz-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$pozNames = @('lineup.png', 'iris.png', 'bracket.png', 'cache.png', 'null.png', 'CAST.md', 'README.md', 'PROMPTS.md', 'qa.html')
foreach ($pozName in $pozNames) {
  if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $pozName) -PathType Leaf)) { throw "Missing source: $pozName" }
}
$pozCopies = @($pozNames | ForEach-Object { @{ Source = $_; Relative = "poz-current\$_" } })
$pozCopies += @{ Source = 'CAST.md'; Relative = 'CAST.md' }
foreach ($pozCopy in $pozCopies) {
  $pozTarget = [IO.Path]::GetFullPath((Join-Path $pozCharactersLibrary $pozCopy.Relative))
  if (-not $pozTarget.StartsWith($pozBoundary, [StringComparison]::OrdinalIgnoreCase)) { throw 'Target escapes character library.' }
  if (Test-Path -LiteralPath $pozTarget) {
    $pozBackupFile = Join-Path $pozBackup $pozCopy.Relative
    New-Item -ItemType Directory -Path (Split-Path $pozBackupFile) -Force | Out-Null
    Copy-Item -LiteralPath $pozTarget -Destination $pozBackupFile
  }
  New-Item -ItemType Directory -Path (Split-Path $pozTarget) -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot $pozCopy.Source) -Destination $pozTarget
}
Write-Output "Current character set: $pozCharactersLibrary\poz-current"
Write-Output "Previous overwritten files preserved: $pozBackup"
Write-Output 'Legacy motion sheets, GIFs and videos are retained unchanged.'
