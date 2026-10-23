# validate-flowmaker.ps1
# Validate a flowmaker HTML file before sharing it.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true, Position=0)]
  [string]$Path
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "File not found: $Path" }
$html = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path), [Text.Encoding]::UTF8)
$m = [regex]::Match($html, '(?s)<script\s+id="flow-data"[^>]*>(.*?)</script>')
if (-not $m.Success) { throw "Missing <script id=flow-data> JSON block" }
try { $data = $m.Groups[1].Value.Trim() | ConvertFrom-Json } catch { throw "Invalid flow-data JSON: $($_.Exception.Message)" }
if ([string]::IsNullOrWhiteSpace([string]$data.title)) { throw "title is required" }
$allowedDirections = @('TB','BT','LR','RL')
if ($data.direction -and $allowedDirections -notcontains [string]$data.direction) { throw "direction must be TB, BT, LR, or RL" }
if (-not $data.nodes -or @($data.nodes).Count -eq 0) { throw "nodes must contain at least one node" }
$ids = @{}
foreach ($n in @($data.nodes)) {
  $id = [string]$n.id
  if ([string]::IsNullOrWhiteSpace($id)) { throw "Every node needs a non-empty id" }
  if ($ids.ContainsKey($id)) { throw "Duplicate node id: $id" }
  $ids[$id] = $true
  if ([string]$n.shape -and @('process','terminator','decision') -notcontains [string]$n.shape) { throw "Invalid shape on node $id" }
  if ([string]$n.variant -and @('start','gold','muted') -notcontains [string]$n.variant) { throw "Invalid variant on node $id" }
}
foreach ($e in @($data.edges)) {
  if (-not $ids.ContainsKey([string]$e.source)) { throw "Edge source does not exist: $($e.source)" }
  if (-not $ids.ContainsKey([string]$e.target)) { throw "Edge target does not exist: $($e.target)" }
  if ($e.dashed -and $e.dashed -isnot [bool]) { throw "Edge dashed must be true or false" }
}
Write-Output ("OK: {0} nodes, {1} edges, title='{2}'" -f @($data.nodes).Count, @($data.edges).Count, $data.title)