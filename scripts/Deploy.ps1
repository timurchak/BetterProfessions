[CmdletBinding()]
param(
  [string]$WowRoot,
  [switch]$NoClean
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$tocPath = Join-Path $projectRoot "BetterProfessions.toc"
$localConfigPath = Join-Path $projectRoot ".deploy.local.ps1"
$BetterProfessionsWowRoot = $null

if (-not $WowRoot -and $env:WOW_RETAIL_PATH) {
  $WowRoot = $env:WOW_RETAIL_PATH
}
if (-not $WowRoot -and (Test-Path -LiteralPath $localConfigPath -PathType Leaf)) {
  . $localConfigPath
  $WowRoot = $BetterProfessionsWowRoot
}
if (-not $WowRoot) {
  throw "WoW Retail path is not configured. Pass -WowRoot, set WOW_RETAIL_PATH, or create .deploy.local.ps1."
}

& (Join-Path $PSScriptRoot "Validate.ps1")

$resolvedWowRoot = [System.IO.Path]::GetFullPath($WowRoot)
$addOnsRoot = [System.IO.Path]::GetFullPath((Join-Path $resolvedWowRoot "Interface\AddOns"))
if (-not (Test-Path -LiteralPath $addOnsRoot -PathType Container)) {
  throw "WoW AddOns directory does not exist: $addOnsRoot"
}

$destinationRoot = [System.IO.Path]::GetFullPath((Join-Path $addOnsRoot "BetterProfessions"))
$destinationParent = [System.IO.Directory]::GetParent($destinationRoot).FullName
if (
  [System.IO.Path]::GetFileName($destinationRoot) -ne "BetterProfessions" -or
  -not $destinationParent.Equals($addOnsRoot, [System.StringComparison]::OrdinalIgnoreCase)
) {
  throw "Refusing unsafe deployment target: $destinationRoot"
}

if ((Test-Path -LiteralPath $destinationRoot) -and -not $NoClean) {
  Remove-Item -LiteralPath $destinationRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null

$addonEntries = @("BetterProfessions.toc", "Media\Icon.tga")
$addonEntries += Get-Content -LiteralPath $tocPath | Where-Object {
  $_ -and -not $_.StartsWith("##") -and -not $_.StartsWith("#")
}

foreach ($entry in $addonEntries) {
  $separator = [System.IO.Path]::DirectorySeparatorChar
  $relativePath = $entry.Trim().Replace([char]92, $separator).Replace([char]47, $separator)
  $sourcePath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $relativePath))
  $destinationPath = [System.IO.Path]::GetFullPath((Join-Path $destinationRoot $relativePath))
  $destinationDirectory = [System.IO.Directory]::GetParent($destinationPath).FullName
  New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
  Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
}

Write-Host "Deployed BetterProfessions to $destinationRoot"
