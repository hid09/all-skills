[CmdletBinding()]
param(
    [switch]$Quiet,
    [switch]$DryRun,
    [string]$ConfigRoot = (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.prism')
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillRoot = Split-Path -Parent $ScriptRoot

function Write-Utf8NoBomFile {
    param([string]$Path, $Content)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir) -and -not $DryRun) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $encoding = New-Object System.Text.UTF8Encoding($false)
    $text = if ($Content -is [string]) { $Content } else { $Content | ConvertTo-Json -Depth 100 }
    if ($DryRun) { Write-Host "[dry-run] write $Path"; return }
    [System.IO.File]::WriteAllText($Path, $text, $encoding)
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    return ([System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json)
}

function Read-Answer {
    param([string]$Prompt, [string]$Default = '')
    if ($Quiet) { return $Default }
    $suffix = if ($Default) { " [$Default]" } else { '' }
    $value = Read-Host "$Prompt$suffix"
    if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
    return $value.Trim()
}

function Read-SecretAnswer {
    param([string]$Prompt)
    if ($Quiet) { return '' }
    $secure = Read-Host $Prompt -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Confirm-Yes {
    param([string]$Prompt, [bool]$DefaultYes = $true)
    $default = if ($DefaultYes) { 'Y' } else { 'N' }
    $answer = Read-Answer $Prompt $default
    return ($answer -match '(?i)^(y|yes)$')
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

function Test-ProvidersConfig {
    param($Config)
    $cfg = ConvertTo-Hashtable $Config
    if ([string]$cfg.config_version -ne '1.0') { throw 'providers.json must have config_version 1.0' }
    if ($null -eq $cfg.providers -or $cfg.providers.Count -lt 1) { throw 'providers.json must define providers' }
    foreach ($name in $cfg.providers.Keys) {
        $p = $cfg.providers[$name]
        foreach ($field in @('api_style','base_url','chat_path','auth_type','key_env')) {
            if ([string]::IsNullOrWhiteSpace([string]$p[$field])) { throw "provider $name missing $field" }
        }
        $uri = $null
        if (-not [Uri]::TryCreate([string]$p.base_url, [UriKind]::Absolute, [ref]$uri)) { throw "provider $name base_url must be an absolute URL" }
        if ($uri.Scheme -ne 'https' -and -not ($uri.Scheme -eq 'http' -and @('localhost','127.0.0.1','::1') -contains $uri.Host)) { throw "provider $name base_url must use HTTPS (HTTP is allowed only for localhost)" }
        if ([string]$p.api_style -ne 'openai-compatible') { throw "provider $name api_style must be openai-compatible" }
        if ([string]$p.auth_type -ne 'bearer') { throw "provider $name auth_type must be bearer" }
        if (($p | ConvertTo-Json -Depth 50) -match 'sk-[A-Za-z0-9]') { throw "provider $name must not contain API key" }
    }
}

function Test-ModelsConfig {
    param($Config)
    $cfg = ConvertTo-Hashtable $Config
    if ($null -eq $cfg.models -or $cfg.models.Count -lt 1) { throw 'models.local.json must define models' }
    if ($null -eq $cfg.pools) { throw 'models.local.json must define pools' }
    if (-not $cfg.pools.Contains('standard_pool') -or @($cfg.pools.standard_pool).Count -lt 1) { throw 'models.local.json must define standard_pool with at least 1 model' }
    if (-not $cfg.pools.Contains('deep_pool') -or @($cfg.pools.deep_pool).Count -lt 2) { throw 'models.local.json must define deep_pool with at least 2 models' }
    foreach ($name in $cfg.models.Keys) {
        $m = $cfg.models[$name]
        foreach ($field in @('provider','model_id','model_type')) {
            if ([string]::IsNullOrWhiteSpace([string]$m[$field])) { throw "model $name missing $field" }
        }
        if (@('standard','reasoning') -notcontains [string]$m.model_type) { throw "model $name model_type must be standard or reasoning" }
    }
    foreach ($poolName in $cfg.pools.Keys) {
        foreach ($modelName in @($cfg.pools[$poolName])) {
            if ($cfg.models.Keys -notcontains [string]$modelName) { throw "pool $poolName references unknown model $modelName" }
        }
    }
}

function New-ProviderConfig {
    param([string]$Alias)
    $upper = ($Alias -replace '[^A-Za-z0-9]', '_').ToUpperInvariant()
    $baseUrl = Read-Answer "Base URL for $Alias" 'https://api.example.com'
    $chatPath = Read-Answer "Chat path for $Alias" '/v1/chat/completions'
    $key_env_name = Read-Answer "API key env name for $Alias" "PRISM_${upper}_KEY"
    $base_env_name = Read-Answer "Base URL env name for $Alias" "PRISM_${upper}_BASE"
    return [ordered]@{
        api_style = 'openai-compatible'
        base_url = $baseUrl
        chat_path = $chatPath
        auth_type = 'bearer'
        key_env = $key_env_name
        base_env = $base_env_name
        extra_headers = @{}
        request_defaults = @{ temperature = 0.7; max_tokens = 8000 }
        timeout_seconds = 60
        retry = @{ max_attempts = 3; retry_on_status = @(429,503,504); retry_on_body_match = @(); backoff_seconds = @(2,5) }
    }
}

function Build-RecommendPools {
    param([hashtable]$Models)
    $names = @($Models.Keys)
    $standard = @($names | Where-Object { [string]$Models[$_].model_type -eq 'standard' })
    $reasoning = @($names | Where-Object { [string]$Models[$_].model_type -eq 'reasoning' })
    $standard_pool = @()
    if ($standard.Count -gt 0) { $standard_pool += $standard[0] }
    $reasoning_different = @($reasoning | Where-Object { $standard_pool.Count -eq 0 -or [string]$Models[$_].provider -ne [string]$Models[$standard_pool[0]].provider })
    if ($reasoning_different.Count -gt 0) { $standard_pool += $reasoning_different[0] }
    elseif ($reasoning.Count -gt 0) { $standard_pool += $reasoning[0] }
    elseif ($names.Count -gt 1) { $standard_pool += $names[1] }
    $deep_pool = @($names | Select-Object -First 3)
    $backup_pool = @($names | Where-Object { $deep_pool -notcontains $_ })
    return @{ standard_pool = $standard_pool; deep_pool = $deep_pool; backup_pool = $backup_pool }
}

try {
    Write-Host 'Prism init wizard - V4.2'
    $providersPath = Join-Path $ConfigRoot 'providers.json'
    $modelsPath = Join-Path $ConfigRoot 'models.local.json'
    $keysPath = Join-Path $ConfigRoot 'keys.env'
    $providers = [ordered]@{ config_version = '1.0'; providers = [ordered]@{} }
    $models = [ordered]@{ models = [ordered]@{}; pools = [ordered]@{} }
    $keys = [ordered]@{}

    if (Test-Path -LiteralPath $providersPath) {
        Write-Host 'Existing ~/.prism/providers.json detected.'
        Write-Host '[1] append provider  [2] edit provider  [3] recreate with backup  [4] exit'
        $choice = Read-Answer 'Choose' '1'
        if ($choice -eq '4') { exit 0 }
        if ($choice -eq '3') {
            $stamp = Get-Date -Format 'yyyyMMdd'
            foreach ($path in @($providersPath, $modelsPath, $keysPath)) {
                if (Test-Path -LiteralPath $path -and -not $DryRun) { Copy-Item -LiteralPath $path -Destination "$path.backup-$stamp" -Force }
            }
        }
        else {
            $existingProviders = Read-JsonFile $providersPath
            if ($existingProviders) { $providers = ConvertTo-Hashtable $existingProviders }
            $existingModels = Read-JsonFile $modelsPath
            if ($existingModels) { $models = ConvertTo-Hashtable $existingModels }
        }
    }
    elseif (-not (Test-Path -LiteralPath $ConfigRoot)) {
        if (Confirm-Yes "Create $ConfigRoot ?" $true) {
            if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $ConfigRoot | Out-Null }
        }
        else { exit 0 }
    }

    $countText = Read-Answer 'How many providers to configure?' '2'
    $count = [Math]::Max(1, [Math]::Min(10, [int]$countText))
    for ($i = 1; $i -le $count; $i++) {
        $alias = Read-Answer "Provider #$i alias" $(if ($i -eq 1) { 'tokenopen' } elseif ($i -eq 2) { 'deepseek' } else { "provider$i" })
        if ($providers.providers.Contains($alias)) {
            if (-not (Confirm-Yes "Provider $alias exists. overwrite?" $false)) { continue }
        }
        $providers.providers[$alias] = New-ProviderConfig $alias
        $apiKey = Read-SecretAnswer "API key for $alias (blank to skip)"
        if ($apiKey) { $keys[$providers.providers[$alias].key_env] = $apiKey }
        if (Confirm-Yes "Test connectivity for $alias ?" $false) {
            Write-Host 'Connectivity test is skipped in this offline-safe implementation; save config and test with panel.ps1.'
        }
    }

    Write-Host 'Enter models as provider:model_id. Blank line ends.'
    while ($true) {
        $line = Read-Answer 'model'
        if ([string]::IsNullOrWhiteSpace($line)) { break }
        if ($line -notmatch '^[^:]+:.+$') { Write-Host 'Use provider:model_id format'; continue }
        $providerName, $modelId = $line.Split(':', 2)
        if (-not $providers.providers.Contains($providerName)) { Write-Host "Unknown provider $providerName"; continue }
        $type = Read-Answer "model_type for $modelId (standard/reasoning)" 'standard'
        if (@('standard','reasoning') -notcontains $type) { $type = 'standard' }
        $entry = [ordered]@{ provider = $providerName; model_id = $modelId; model_type = $type }
        if ($type -eq 'reasoning') { $entry.overrides = @{ max_tokens = 16000 } }
        $models.models[$modelId] = $entry
    }
    if ($models.models.Count -eq 0) {
        foreach ($name in $providers.providers.Keys) {
            $defaultId = if ($name -eq 'deepseek') { 'deepseek-v4-pro' } else { 'gpt-5.4-mini' }
            $defaultType = if ($defaultId -match 'v4|reason|gemini|deepseek') { 'reasoning' } else { 'standard' }
            $id = Read-Answer "Default model id for $name" $defaultId
            $entry = [ordered]@{ provider = $name; model_id = $id; model_type = $defaultType }
            if ($defaultType -eq 'reasoning') { $entry.overrides = @{ max_tokens = 16000 } }
            $models.models[$id] = $entry
        }
    }
    $models.pools = Build-RecommendPools $models.models
    Write-Host ('standard_pool: ' + (($models.pools.standard_pool) -join ', '))
    Write-Host ('deep_pool: ' + (($models.pools.deep_pool) -join ', '))
    if (-not (Confirm-Yes 'Accept generated pools?' $true)) {
        $models.pools.standard_pool = @((Read-Answer 'standard_pool comma list' (($models.pools.standard_pool) -join ',')).Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $models.pools.deep_pool = @((Read-Answer 'deep_pool comma list' (($models.pools.deep_pool) -join ',')).Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $models.pools.backup_pool = @((Read-Answer 'backup_pool comma list' (($models.pools.backup_pool) -join ',')).Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }

    Test-ProvidersConfig $providers
    Test-ModelsConfig $models
    $keyLines = @()
    foreach ($name in $keys.Keys) { $keyLines += "$name=$($keys[$name])" }
    Write-Utf8NoBomFile $providersPath $providers
    Write-Utf8NoBomFile $modelsPath $models
    if ($keyLines.Count -gt 0) { Write-Utf8NoBomFile $keysPath ($keyLines -join [Environment]::NewLine) }
    Write-Host 'Prism V4.2 config generated.'
}
catch {
    Write-Error "init-prism.ps1 failed: $($_.Exception.Message)"
    exit 1
}
