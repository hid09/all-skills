[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ContractFile
)
$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillRoot = Split-Path -Parent $scriptRoot
$keywordsFile = Join-Path (Join-Path $skillRoot 'config') 'sensitive-keywords.txt'
$contract = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $ContractFile), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$text = (($contract.question, ($contract.context.PSObject.Properties.Value -join "`n")) -join "`n")
$hits = @()
foreach ($line in [System.IO.File]::ReadAllLines($keywordsFile, [System.Text.Encoding]::UTF8)) {
    $pattern = $line.Trim()
    if (-not $pattern -or $pattern.StartsWith('#')) { continue }
    if ($text -match $pattern) { $hits += $pattern }
}
[pscustomobject]@{
    question_preview = ([string]$contract.question).Substring(0, [Math]::Min(200, ([string]$contract.question).Length))
    shared_facts_count = @($contract.shared_facts).Count
    sensitive_hits = $hits
    sensitivity = $(if ($hits.Count -gt 0) { 'high' } else { 'low' })
} | ConvertTo-Json -Depth 20