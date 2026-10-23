param(
  [string]$OutputPath = ""
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$dataDir = Join-Path $repo 'wardrobe\data'
$contextDir = Join-Path $repo 'context'
$distDir = Join-Path $repo 'dist'

if (-not (Test-Path -LiteralPath $dataDir)) { throw "找不到 wardrobe/data" }
if (-not (Test-Path -LiteralPath $contextDir)) { throw "找不到 context" }

$running = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -eq 'node.exe' -and $_.CommandLine -like '*wardrobe*app*server.js*' }
if ($running) {
  throw "检测到衣橱服务仍在运行，请先按 Ctrl+C 停止服务，再重新打包。"
}

New-Item -ItemType Directory -Force -Path $distDir | Out-Null
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $stamp = Get-Date -Format 'yyyy-MM-dd-HHmm'
  $OutputPath = Join-Path $distDir "my-wardrobe-private-$stamp.zip"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
  $OutputPath = Join-Path (Get-Location) $OutputPath
}

$stage = Join-Path $env:TEMP ("wardrobe-bundle-" + [guid]::NewGuid().ToString('N'))
try {
  New-Item -ItemType Directory -Force -Path (Join-Path $stage 'wardrobe') | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $stage 'context') | Out-Null
  Copy-Item -LiteralPath $dataDir -Destination (Join-Path $stage 'wardrobe') -Recurse -Force
  Copy-Item -LiteralPath $contextDir -Destination $stage -Recurse -Force
  if (Test-Path -LiteralPath $OutputPath) { Remove-Item -LiteralPath $OutputPath -Force }
  Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $OutputPath -CompressionLevel Optimal
  Write-Output "已生成个人迁移包：$OutputPath"
} finally {
  if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
}

