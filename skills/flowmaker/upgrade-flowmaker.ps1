# upgrade-flowmaker.ps1
# 把老 flowmaker HTML 升级到新引擎（带 💾 保存 + 📤 HTML 功能）
#
# 用法：
#   单文件：  .\upgrade-flowmaker.ps1 -Path "C:\path\to\old.html"
#   批量：    .\upgrade-flowmaker.ps1 -Path "C:\path\to\outputs"
#   通配符：  .\upgrade-flowmaker.ps1 -Path "C:\path\to\*.html"
#
# 行为：
#   - 老文件原地保留，不动
#   - 在同目录生成 <原名>.upgraded.html
#   - 已有 .upgraded.html 自动跳过（避免重复升级）
#   - 自动验证：升级后能解析出 JSON 且节点数一致
#
# 原理：
#   抽取老 HTML 的 <script id="flow-data"> JSON 数据 + <title> 标题，
#   注入到新 template.html 模板，另存为新文件。
#   引擎代码全用新版（含保存/导出/Ctrl+S）。

param(
  [Parameter(Mandatory=$true, Position=0)]
  [string]$Path,
  [switch]$Force  # 跳过 .upgraded.html 已存在的检查，强制重新生成
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplatePath = Join-Path $ScriptDir "template.html"

if (-not (Test-Path $TemplatePath)) {
  Write-Host "❌ 找不到新模板：$TemplatePath" -ForegroundColor Red
  exit 1
}

# 读新模板（UTF-8，会自动处理 BOM）
$template = [System.IO.File]::ReadAllText($TemplatePath, [System.Text.Encoding]::UTF8)

# 收集要处理的文件
$files = @()
if (Test-Path $Path -PathType Container) {
  $files = Get-ChildItem $Path -Filter "*.html" -File |
           Where-Object { $_.Name -notlike "*.upgraded.html" -and $_.Name -notlike "*.bak.html" }
} elseif (Test-Path $Path -PathType Leaf) {
  $files = @(Get-Item $Path)
} else {
  # 通配符
  $files = Get-Item $Path -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -notlike "*.upgraded.html" -and $_.Name -notlike "*.bak.html" }
}

if ($files.Count -eq 0) {
  Write-Host "❌ 没找到匹配的 .html 文件: $Path" -ForegroundColor Red
  exit 1
}

Write-Host "找到 $($files.Count) 个文件待升级`n" -ForegroundColor Cyan

$utf8Bom = New-Object System.Text.UTF8Encoding $true
$okCount = 0
$skipCount = 0
$failCount = 0

foreach ($f in $files) {
  $outName = [System.IO.Path]::GetFileNameWithoutExtension($f.Name) + ".upgraded.html"
  $outPath = Join-Path $f.Directory.FullName $outName

  Write-Host "→ $($f.Name)" -NoNewline

  if ((Test-Path $outPath) -and -not $Force) {
    Write-Host "  ⏭  跳过（已存在 .upgraded.html，用 -Force 覆盖）" -ForegroundColor Yellow
    $skipCount++
    continue
  }

  try {
    $old = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)

    # 抽老文件的 JSON 数据
    if ($old -notmatch '(?s)<script id="flow-data"[^>]*>(.*?)</script>') {
      throw "找不到 <script id='flow-data'>（不是 flowmaker 生成的 HTML？）"
    }
    $oldJson = $matches[1].Trim()

    # 校验 JSON 合法 + 节点数
    try {
      $parsed = $oldJson | ConvertFrom-Json
      if (-not $parsed.nodes) { throw "JSON 缺少 nodes 字段" }
      $oldNodeCount = $parsed.nodes.Count
    } catch {
      throw "JSON 解析失败: $($_.Exception.Message)"
    }

    # 抽老文件的 <title>
    $oldTitle = "__TITLE__"
    if ($old -match '<title>([^<]*)</title>') {
      $oldTitle = $matches[1]
    }

    # 把新模板的 __TITLE__ 替成老标题
    $newHtml = $template.Replace("<title>__TITLE__</title>", "<title>$oldTitle</title>")

    # 替换新模板的 JSON 块为老 JSON（用 IndexOf 避免 regex 转义陷阱）
    $startTag = '<script id="flow-data" type="application/json">'
    $endTag   = '</script>'
    $sIdx = $newHtml.IndexOf($startTag)
    if ($sIdx -lt 0) { throw "新模板里找不到 flow-data 标签（模板被改坏？）" }
    $searchFrom = $sIdx + $startTag.Length
    $eIdx = $newHtml.IndexOf($endTag, $searchFrom)
    if ($eIdx -lt 0) { throw "新模板里找不到 flow-data 闭合" }

    $newHtml = $newHtml.Substring(0, $searchFrom) + "`n" + $oldJson + "`n" + $newHtml.Substring($eIdx)

    # 写出 UTF-8 with BOM
    [System.IO.File]::WriteAllText($outPath, $newHtml, $utf8Bom)

    # 验证：能再解析回来 + 节点数一致
    $vtxt = [System.IO.File]::ReadAllText($outPath, [System.Text.Encoding]::UTF8)
    if ($vtxt -match '(?s)<script id="flow-data"[^>]*>(.*?)</script>') {
      $vParsed = $matches[1].Trim() | ConvertFrom-Json
      if ($vParsed.nodes.Count -ne $oldNodeCount) {
        throw "节点数不一致：原 $oldNodeCount → 升级后 $($vParsed.nodes.Count)"
      }
    } else {
      throw "升级后的文件无法解析 JSON"
    }

    $sz = [math]::Round((Get-Item $outPath).Length / 1024, 1)
    Write-Host "  ✓ → $outName  (${oldNodeCount}节点, ${sz}KB)" -ForegroundColor Green
    $okCount++
  } catch {
    Write-Host "  ❌ 失败: $($_.Exception.Message)" -ForegroundColor Red
    $failCount++
  }
}

Write-Host ""
Write-Host "=== 升级完成 ===" -ForegroundColor Cyan
Write-Host "成功: $okCount  跳过: $skipCount  失败: $failCount"
if ($okCount -gt 0) {
  Write-Host ""
  Write-Host "✓ 老文件已原样保留，新版在 .upgraded.html 后缀" -ForegroundColor Green
  Write-Host "✓ 双击打开升级后的 HTML 即可使用 💾 保存 / Ctrl+S / 📤 HTML 功能"
}
