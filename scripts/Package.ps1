[CmdletBinding()]
param(
  [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$tocPath = Join-Path $projectRoot "BetterProfessions.toc"
& (Join-Path $PSScriptRoot "Validate.ps1")

if (-not $OutputDirectory) {
  $OutputDirectory = Join-Path $projectRoot "dist"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputDirectory)) {
  $OutputDirectory = Join-Path $projectRoot $OutputDirectory
}
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$toc = Get-Content -LiteralPath $tocPath
$versionLine = $toc | Where-Object { $_ -match '^## Version:\s*(.+?)\s*$' } | Select-Object -First 1
$version = ([regex]::Match($versionLine, '^## Version:\s*(.+?)\s*$')).Groups[1].Value
$zipPath = Join-Path $OutputDirectory "BetterProfessions-$version.zip"
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("BetterProfessions-package-" + [guid]::NewGuid().ToString("N"))
$stagedAddon = Join-Path $temporaryRoot "BetterProfessions"

try {
  New-Item -ItemType Directory -Path $stagedAddon -Force | Out-Null
  $addonEntries = @("BetterProfessions.toc")
  $addonEntries += $toc | Where-Object { $_ -and -not $_.StartsWith("##") -and -not $_.StartsWith("#") }

  foreach ($entry in $addonEntries) {
    $separator = [System.IO.Path]::DirectorySeparatorChar
    $relativePath = $entry.Trim().Replace([char]92, $separator).Replace([char]47, $separator)
    $sourcePath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $relativePath))
    $stagedPath = [System.IO.Path]::GetFullPath((Join-Path $stagedAddon $relativePath))
    New-Item -ItemType Directory -Path ([System.IO.Directory]::GetParent($stagedPath).FullName) -Force | Out-Null
    Copy-Item -LiteralPath $sourcePath -Destination $stagedPath -Force
  }

  if (Test-Path -LiteralPath $zipPath -PathType Leaf) {
    Remove-Item -LiteralPath $zipPath -Force
  }
  Compress-Archive -LiteralPath $stagedAddon -DestinationPath $zipPath -CompressionLevel Optimal
} finally {
  $resolvedTemporaryRoot = [System.IO.Path]::GetFullPath($temporaryRoot)
  $systemTemporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
  if (
    $resolvedTemporaryRoot.StartsWith($systemTemporaryRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
    [System.IO.Path]::GetFileName($resolvedTemporaryRoot).StartsWith("BetterProfessions-package-") -and
    (Test-Path -LiteralPath $resolvedTemporaryRoot)
  ) {
    Remove-Item -LiteralPath $resolvedTemporaryRoot -Recurse -Force
  }
}

Write-Host "Created package: $zipPath"
