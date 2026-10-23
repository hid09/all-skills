[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$JsonFile,
    [ValidateSet('auto','providers','models','mini_audit','json')][string]$Kind = 'auto'
)

$ErrorActionPreference = 'Stop'

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "File not found: $Path" }
    return ([System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path), [System.Text.Encoding]::UTF8) | ConvertFrom-Json)
}

function ConvertTo-Hashtable {
    param($InputObject)
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Collections.IDictionary]) {
        $hash = [ordered]@{}
        foreach ($key in $InputObject.Keys) { $hash[$key] = ConvertTo-Hashtable $InputObject[$key] }
        return $hash
    }
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $arr = @()
        foreach ($item in $InputObject) { $arr += ,(ConvertTo-Hashtable $item) }
        return $arr
    }
    if ($InputObject.PSObject -and $InputObject.PSObject.Properties.Count -gt 0 -and $InputObject -isnot [string]) {
        $hash = [ordered]@{}
        foreach ($prop in $InputObject.PSObject.Properties) { $hash[$prop.Name] = ConvertTo-Hashtable $prop.Value }
        return $hash
    }
    return $InputObject
}

function Test-Providers {
    param($Config)
    $cfg = ConvertTo-Hashtable $Config
    if ([string]$cfg.config_version -ne '1.0') { throw 'providers config must have config_version 1.0' }
    if ($null -eq $cfg.providers -or $cfg.providers.Count -lt 1) { throw 'providers config must define providers' }
    foreach ($name in $cfg.providers.Keys) {
        $p = $cfg.providers[$name]
        foreach ($field in @('api_style','base_url','chat_path','auth_type','key_env')) {
            if ([string]::IsNullOrWhiteSpace([string]$p[$field])) { throw "provider $name missing $field" }
        }
        if ([string]$p.api_style -ne 'openai-compatible') { throw "provider $name api_style must be openai-compatible" }
        if ([string]$p.auth_type -ne 'bearer') { throw "provider $name auth_type must be bearer" }
        if (($p | ConvertTo-Json -Depth 50) -match 'sk-[A-Za-z0-9]') { throw "provider $name appears to contain API key" }
    }
}

function Test-Models {
    param($Config)
    $cfg = ConvertTo-Hashtable $Config
    if ($null -eq $cfg.models -or $cfg.models.Count -lt 1) { throw 'models config must define models' }
    if ($null -eq $cfg.pools) { throw 'models config must define pools' }
    if (-not $cfg.pools.Contains('standard_pool') -or @($cfg.pools.standard_pool).Count -lt 1) { throw 'models config must define standard_pool with at least 1 model' }
    if (-not $cfg.pools.Contains('deep_pool') -or @($cfg.pools.deep_pool).Count -lt 2) { throw 'models config must define deep_pool with at least 2 models' }
    foreach ($name in $cfg.models.Keys) {
        $m = $cfg.models[$name]
        foreach ($field in @('provider','model_id','model_type')) {
            if ([string]::IsNullOrWhiteSpace([string]$m[$field])) { throw "model $name missing $field" }
        }
        if (@('standard','reasoning') -notcontains [string]$m.model_type) { throw "model $name invalid model_type" }
    }
    foreach ($poolName in $cfg.pools.Keys) {
        foreach ($modelName in @($cfg.pools[$poolName])) {
            if ($cfg.models.Keys -notcontains [string]$modelName) { throw "pool $poolName references unknown model $modelName" }
        }
    }
}

function Test-MiniAudit {
    param($Config)
    $cfg = ConvertTo-Hashtable $Config
    foreach ($field in @('consensus','fact_check','risks')) {
        if (-not $cfg.Contains($field)) { throw "mini audit missing $field" }
    }
    if (@($cfg.consensus).Count -lt 3) { throw 'mini audit consensus must have at least 3 items' }
    foreach ($item in @($cfg.fact_check)) {
        foreach ($field in @('claim','evidence_needed','priority')) {
            if ([string]::IsNullOrWhiteSpace([string]$item[$field])) { throw "fact_check item missing $field" }
        }
        if (@('high','medium','low') -notcontains [string]$item.priority) { throw "fact_check priority invalid: $($item.priority)" }
    }
    foreach ($item in @($cfg.risks)) {
        foreach ($field in @('risk','severity','mitigation')) {
            if ([string]::IsNullOrWhiteSpace([string]$item[$field])) { throw "risk item missing $field" }
        }
        if (@('high','medium','low') -notcontains [string]$item.severity) { throw "risk severity invalid: $($item.severity)" }
    }
}

$json = Read-JsonFile $JsonFile
if ($Kind -eq 'auto') {
    $name = Split-Path -Leaf $JsonFile
    if ($name -eq 'providers.json') { $Kind = 'providers' }
    elseif ($name -eq 'models.json' -or $name -eq 'models.local.json') { $Kind = 'models' }
    elseif ($name -match 'mini') { $Kind = 'mini_audit' }
    else { $Kind = 'json' }
}
switch ($Kind) {
    'providers' { Test-Providers $json }
    'models' { Test-Models $json }
    'mini_audit' { Test-MiniAudit $json }
    default { }
}
Write-Output "$Kind validation: ok"
