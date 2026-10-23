param(
  [Parameter(Mandatory=$true)]
  [string]$ArchivePath
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$archive = $ArchivePath
if (-not [System.IO.Path]::IsPathRooted($archive)) { $archive = Join-Path (Get-Location) $archive }
if (-not (Test-Path -LiteralPath $archive)) { throw "找不到迁移包：$archive" }

$running = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -eq 'node.exe' -and $_.CommandLine -like '*wardrobe*app*server.js*' }
if ($running) { throw "检测到衣橱服务仍在运行，请先停止服务。" }

$stage = Join-Path $env:TEMP ("wardrobe-restore-" + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $env:TEMP ("wardrobe-before-restore-" + [guid]::NewGuid().ToString('N'))
try {
  Expand-Archive -LiteralPath $archive -DestinationPath $stage -Force
  $dataSource = Join-Path $stage 'wardrobe\data'
  $contextSource = Join-Path $stage 'context'
  if (-not (Test-Path -LiteralPath $dataSource)) { throw "迁移包缺少 wardrobe/data" }

  if (Test-Path -LiteralPath (Join-Path $repo 'wardrobe\data')) {
    New-Item -ItemType Directory -Force -Path $backup | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo 'wardrobe\data') -Destination $backup -Recurse -Force
  }
  Remove-Item -LiteralPath (Join-Path $repo 'wardrobe\data') -Recurse -Force -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force -Path (Join-Path $repo 'wardrobe') | Out-Null
  Copy-Item -LiteralPath $dataSource -Destination (Join-Path $repo 'wardrobe') -Recurse -Force
  if (Test-Path -LiteralPath $contextSource) {
    Remove-Item -LiteralPath (Join-Path $repo 'context') -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item -LiteralPath $contextSource -Destination $repo -Recurse -Force
  }
  Write-Output "个人衣橱数据已恢复到：$repo"
  if (Test-Path -LiteralPath $backup) { Write-Output "恢复前备份保存在临时目录：$backup" }
} finally {
  if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
}

