[CmdletBinding()]
param(
  [string]$ExpectedVersion
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$tocPath = Join-Path $projectRoot "BetterProfessions.toc"
$iconPath = Join-Path $projectRoot "Media\Icon.tga"

if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) {
  throw "Missing TOC file: $tocPath"
}
if (-not (Test-Path -LiteralPath $iconPath -PathType Leaf)) {
  throw "Missing addon icon: $iconPath"
}

$tocLines = Get-Content -LiteralPath $tocPath
$versionLine = $tocLines | Where-Object { $_ -match '^## Version:\s*(.+?)\s*$' } | Select-Object -First 1
$interfaceLine = $tocLines | Where-Object { $_ -match '^## Interface:\s*(\d+)\s*$' } | Select-Object -First 1
if (-not $versionLine) {
  throw "BetterProfessions.toc does not contain a Version field."
}
if (-not $interfaceLine) {
  throw "BetterProfessions.toc does not contain a numeric Interface field."
}

$version = ([regex]::Match($versionLine, '^## Version:\s*(.+?)\s*$')).Groups[1].Value
if ($ExpectedVersion -and $version -ne $ExpectedVersion.TrimStart('v')) {
  throw "TOC version '$version' does not match expected version '$ExpectedVersion'."
}

$manifestEntries = @($tocLines | Where-Object {
  $_ -and -not $_.StartsWith("##") -and -not $_.StartsWith("#")
})
$directorySeparator = [System.IO.Path]::DirectorySeparatorChar
$addonPrefix = $projectRoot.TrimEnd([char[]]@([char]92, [char]47)) + $directorySeparator
$runtimeFiles = @()

foreach ($entry in $manifestEntries) {
  $relativePath = $entry.Trim().Replace([char]92, $directorySeparator).Replace([char]47, $directorySeparator)
  $fullPath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $relativePath))
  if (-not $fullPath.StartsWith($addonPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "TOC entry escapes the addon directory: $entry"
  }
  if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
    throw "TOC references a missing file: $entry"
  }
  $runtimeFiles += Get-Item -LiteralPath $fullPath
}

$luaFiles = @($runtimeFiles | Where-Object { $_.Extension -ieq ".lua" })
if ($luaFiles.Count -eq 0) {
  throw "No Lua source files are listed in the TOC."
}
foreach ($luaFile in $luaFiles) {
  $bytes = [System.IO.File]::ReadAllBytes($luaFile.FullName)
  if ($bytes -contains 0) {
    throw "Lua source contains a NUL byte: $($luaFile.FullName)"
  }
}

$dataPath = Join-Path $projectRoot "Data\RecipeSpecializations.lua"
$dataText = Get-Content -LiteralPath $dataPath -Raw
if ($dataText -notmatch 'addon\.SpecializationData\s*=\s*\{' -or $dataText -notmatch '\n\s*recipes\s*=\s*\{' -or $dataText -notmatch '\n\s*nodes\s*=\s*\{') {
  throw "Generated specialization data is incomplete."
}

$npxCommand = Get-Command "npx.cmd" -ErrorAction SilentlyContinue
if (-not $npxCommand) {
  $npxCommand = Get-Command "npx" -ErrorAction SilentlyContinue
}
if (-not $npxCommand) {
  throw "Lua syntax validation requires Node.js/npx."
}

& $npxCommand.Source --yes luaparse@0.3.1 --quiet @($luaFiles.FullName)
if ($LASTEXITCODE -ne 0) {
  throw "Lua syntax validation failed."
}

Write-Host "Validated BetterProfessions $version ($($luaFiles.Count) Lua files, $($manifestEntries.Count) TOC entries)."
