[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RequestFile,
    [Parameter(Mandatory = $true)][string]$OutputFile,
    [string]$ProgressFile,
    [switch]$IncludeRawContent
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillRoot = Split-Path -Parent $ScriptRoot
$ConfigRoot = Join-Path $SkillRoot 'config'
$UserPrismRoot = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.prism'
$WorkerPath = Join-Path $ScriptRoot 'panel-worker.ps1'

# Dot-source shared worker functions
. $WorkerPath

# P1-5: progress hook -- main agent may poll -ProgressFile while requests are in flight.
function Write-Progress-Snapshot {
    param([string]$Stage, [array]$Requests, [hashtable]$Statuses, [datetime]$StartedAt)
    if (-not $ProgressFile) { return }
    $snap = [ordered]@{
        stage = $Stage
        started_at = $StartedAt.ToString('o')
        elapsed_ms = [int]((Get-Date) - $StartedAt).TotalMilliseconds
        total = @($Requests).Count
        statuses = @(foreach ($r in $Requests) {
            $id = [string]$r.id
            $st = if ($Statuses.ContainsKey($id)) { $Statuses[$id] } else { 'pending' }
            @{ id = $id; model = [string]$r.model; status = $st }
        })
    }
    try { Write-Utf8NoBomFile -Path $ProgressFile -Content $snap } catch { }
}

# Config validation (main-script only -- not needed inside parallel workers)

function Test-ProvidersConfig {
    param($Config, [string]$Label)
    $cfg = ConvertTo-Hashtable $Config
    if ($null -eq $cfg.config_version -or [string]$cfg.config_version -ne '1.0') { throw "$Label must have config_version 1.0" }
    if ($null -eq $cfg.providers) { throw "$Label missing providers" }
    foreach ($providerName in $cfg.providers.Keys) {
        $p = $cfg.providers[$providerName]
        if ([string]$p.api_style -ne 'openai-compatible') { throw "$Label provider $providerName must use api_style openai-compatible" }
        foreach ($field in @('base_url','chat_path','auth_type','key_env')) {
            if ($null -eq $p.$field -or [string]::IsNullOrWhiteSpace([string]$p.$field)) { throw "$Label provider $providerName missing $field" }
        }
        if ([string]$p.auth_type -ne 'bearer') { throw "$Label provider $providerName auth_type must be bearer" }
        $uri = $null
        if (-not [Uri]::TryCreate([string]$p.base_url, [UriKind]::Absolute, [ref]$uri)) { throw "$Label provider $providerName base_url must be an absolute URL" }
        if ($uri.Scheme -ne 'https' -and -not ($uri.Scheme -eq 'http' -and @('localhost','127.0.0.1','::1') -contains $uri.Host)) { throw "$Label provider $providerName base_url must use HTTPS (HTTP is allowed only for localhost)" }
        $json = $p | ConvertTo-Json -Depth 50
        if ($json -match 'sk-[A-Za-z0-9]') { throw "$Label provider $providerName appears to contain an API key" }
    }
}

function Test-ProvidersOverrideConfig {
    param($Config, [string]$Label)
    $cfg = ConvertTo-Hashtable $Config
    if ($null -eq $cfg.config_version -or [string]$cfg.config_version -ne '1.0') { throw "$Label must have config_version 1.0" }
    if ($null -eq $cfg.providers) { throw "$Label missing providers" }
    foreach ($topKey in $cfg.Keys) {
        if (@('config_version','providers') -notcontains [string]$topKey) { throw "$Label has unknown top-level field $topKey" }
    }
    $allowedProviderFields = @(
        'api_style','base_url','chat_path','auth_type','key_env','base_env','extra_headers',
        'request_defaults','timeout_seconds','retry'
    )
    foreach ($providerName in $cfg.providers.Keys) {
        $p = $cfg.providers[$providerName]
        if ($null -eq $p -or $p -isnot [System.Collections.IDictionary]) { throw "$Label provider $providerName override must be an object" }
        foreach ($field in $p.Keys) {
            if ($allowedProviderFields -notcontains [string]$field) { throw "$Label provider $providerName has unknown field $field" }
        }
        if ($p.Contains('api_style') -and $null -ne $p.api_style -and [string]$p.api_style -ne 'openai-compatible') { throw "$Label provider $providerName must use api_style openai-compatible" }
        if ($p.Contains('auth_type') -and $null -ne $p.auth_type -and [string]$p.auth_type -ne 'bearer') { throw "$Label provider $providerName auth_type must be bearer" }
        foreach ($field in @('base_url','chat_path','key_env','base_env')) {
            if ($p.Contains($field) -and $null -ne $p[$field] -and [string]::IsNullOrWhiteSpace([string]$p[$field])) { throw "$Label provider $providerName has blank $field" }
        }
        $json = $p | ConvertTo-Json -Depth 50
        if ($json -match 'sk-[A-Za-z0-9]') { throw "$Label provider $providerName appears to contain an API key" }
        if ($p.Contains('base_url') -and $null -ne $p.base_url) {
            $uri = $null
            if (-not [Uri]::TryCreate([string]$p.base_url, [UriKind]::Absolute, [ref]$uri)) { throw "$Label provider $providerName base_url must be an absolute URL" }
            if ($uri.Scheme -ne 'https' -and -not ($uri.Scheme -eq 'http' -and @('localhost','127.0.0.1','::1') -contains $uri.Host)) { throw "$Label provider $providerName base_url must use HTTPS (HTTP is allowed only for localhost)" }
        }
    }
}

function Test-ModelsConfig {
    param($Config, [string]$Label)
    $cfg = ConvertTo-Hashtable $Config
    if ($null -eq $cfg.models) { throw "$Label missing models" }
    if ($null -eq $cfg.pools) { throw "$Label missing pools" }
    if (-not $cfg.pools.Contains('standard_pool') -or @($cfg.pools.standard_pool).Count -lt 1) { throw "$Label must define standard_pool with at least 1 model" }
    if (-not $cfg.pools.Contains('deep_pool') -or @($cfg.pools.deep_pool).Count -lt 2) { throw "$Label must define deep_pool with at least 2 models" }
    foreach ($modelName in $cfg.models.Keys) {
        $m = $cfg.models[$modelName]
        foreach ($field in @('provider','model_id','model_type')) {
            if ($null -eq $m.$field -or [string]::IsNullOrWhiteSpace([string]$m.$field)) { throw "$Label model $modelName missing $field" }
        }
        if (@('standard','reasoning') -notcontains [string]$m.model_type) { throw "$Label model $modelName has invalid model_type" }
    }
    foreach ($poolName in $cfg.pools.Keys) {
        foreach ($modelName in @($cfg.pools[$poolName])) {
            if ($cfg.models.Keys -notcontains [string]$modelName) { throw "$Label pool $poolName references unknown model $modelName" }
        }
    }
}

function Merge-ModelsConfig {
    param($Base, $Override)
    $baseHash = ConvertTo-Hashtable $Base
    if ($null -eq $Override) { return $baseHash }
    $overrideHash = ConvertTo-Hashtable $Override
    $merged = ConvertTo-Hashtable $Base
    if ($overrideHash.Contains('models')) {
        foreach ($modelName in $overrideHash.models.Keys) {
            if ($merged.models.Contains($modelName)) { $merged.models[$modelName] = Merge-Object $merged.models[$modelName] $overrideHash.models[$modelName] }
            else { $merged.models[$modelName] = $overrideHash.models[$modelName] }
        }
    }
    if ($overrideHash.Contains('pools')) {
        foreach ($poolName in $overrideHash.pools.Keys) { $merged.pools[$poolName] = $overrideHash.pools[$poolName] }
    }
    return $merged
}

function Load-ProvidersConfig {
    $basePath = Join-Path $ConfigRoot 'providers.json'
    $userPath = Join-Path $UserPrismRoot 'providers.json'
    $base = Read-JsonFile $basePath
    Test-ProvidersConfig $base 'skill providers.json'
    $merged = ConvertTo-Hashtable $base
    if (Test-Path -LiteralPath $userPath) {
        $user = Read-JsonFile $userPath
        Test-ProvidersOverrideConfig $user '~/.prism/providers.json'
        $merged = Merge-Object $merged $user
        Test-ProvidersConfig ([pscustomobject]$merged) 'merged providers config'
    }
    return $merged
}

function Load-ModelsConfig {
    $basePath = Join-Path $ConfigRoot 'models.json'
    $userPath = Join-Path $UserPrismRoot 'models.local.json'
    $base = Read-JsonFile $basePath
    if ($base.PSObject.Properties.Name -contains 'providers') { throw 'Legacy V4.1 models.json detected; run init-prism.ps1 or migrate to V4.2 models/pools format' }
    Test-ModelsConfig $base 'skill models.json'
    $merged = ConvertTo-Hashtable $base
    if (Test-Path -LiteralPath $userPath) {
        $user = Read-JsonFile $userPath
        if ($user.PSObject.Properties.Name -contains 'providers') { throw 'Legacy models.local.json detected; migrate to V4.2 models/pools format' }
        $merged = Merge-ModelsConfig $merged $user
        Test-ModelsConfig ([pscustomobject]$merged) 'merged models config'
    }
    return $merged
}

function Test-PanelRequest {
    param($InputObject)
    if ($null -eq $InputObject.requests) { throw 'in.json missing required field: requests' }
    if ($null -eq $InputObject.timeout_seconds) { throw 'in.json missing required field: timeout_seconds' }
    if ($null -eq $InputObject.parallel) { throw 'in.json missing required field: parallel' }
    $requests = @($InputObject.requests)
    if ($requests.Count -lt 1 -or $requests.Count -gt 4) { throw 'requests count must be between 1 and 4' }
    foreach ($request in $requests) {
        foreach ($field in @('id','model','system_prompt','user_prompt')) {
            if ([string]::IsNullOrWhiteSpace([string]$request.$field)) { throw "request missing required field: $field" }
        }
        if ($request.response_format -and @('text','json_object','json_schema') -notcontains [string]$request.response_format) {
            throw "request $($request.id) has invalid response_format"
        }
    }
}

try {
    $started = Get-Date
    $inputJson = Read-JsonFile -Path $RequestFile
    Test-PanelRequest -InputObject $inputJson
    $providersConfig = Load-ProvidersConfig
    $modelsConfig = Load-ModelsConfig
    foreach ($modelName in $modelsConfig.models.Keys) {
        $providerName = [string]$modelsConfig.models[$modelName].provider
        if (-not $providersConfig.providers.Contains($providerName)) { throw "model $modelName references unknown provider $providerName" }
    }
    $userKeyMap = Read-KeyFile (Join-Path $UserPrismRoot 'keys.env')
    $skillKeyMap = Read-KeyFile (Join-Path $ScriptRoot 'keys.env')
    $requests = @($inputJson.requests)
    $timeoutSec = [int]$inputJson.timeout_seconds
    $parallel = [bool]$inputJson.parallel
    $statusMap = [System.Collections.Hashtable]::Synchronized(@{})
    foreach ($r in $requests) { $statusMap[[string]$r.id] = 'pending' }
    Write-Progress-Snapshot -Stage 'starting' -Requests $requests -Statuses $statusMap -StartedAt $started

    # PS7 parallel: real concurrent execution via runspaces
    if ($parallel -and $requests.Count -gt 1 -and $PSVersionTable.PSVersion.Major -ge 7) {
        $results = $requests | ForEach-Object -Parallel {
            . $using:WorkerPath
            $req = $_
            $statusMap = $using:statusMap
            $statusMap[[string]$req.id] = 'in_progress'
            $r = Invoke-Request -Request $req -ModelsConfig $using:modelsConfig -ProvidersConfig $using:providersConfig -UserKeyMap $using:userKeyMap -SkillKeyMap $using:skillKeyMap -TimeoutSec $using:timeoutSec
            $statusMap[[string]$req.id] = [string]$r.status
            $r
        } -ThrottleLimit 4
        $mode = 'parallel-ps7'
        Write-Progress-Snapshot -Stage 'finished' -Requests $requests -Statuses $statusMap -StartedAt $started
    }
    # PS5 fallback: Start-Job (真并行 but heavier)
    elseif ($parallel -and $requests.Count -gt 1) {
        $jobScript = {
            param($WorkerPath, $Request, $ModelsConfig, $ProvidersConfig, $UserKeyMap, $SkillKeyMap, $TimeoutSec)
            . $WorkerPath
            Invoke-Request -Request $Request -ModelsConfig $ModelsConfig -ProvidersConfig $ProvidersConfig -UserKeyMap $UserKeyMap -SkillKeyMap $SkillKeyMap -TimeoutSec $TimeoutSec
        }
        $jobs = foreach ($request in $requests) {
            $statusMap[[string]$request.id] = 'in_progress'
            @{
                Id = [string]$request.id
                Model = [string]$request.model
                Job = Start-Job -ScriptBlock $jobScript -ArgumentList $WorkerPath, $request, $modelsConfig, $providersConfig, $userKeyMap, $skillKeyMap, $timeoutSec
            }
        }
        Write-Progress-Snapshot -Stage 'in_progress' -Requests $requests -Statuses $statusMap -StartedAt $started
        $results = @()
        foreach ($j in $jobs) {
            if (Wait-Job -Job $j.Job -Timeout ($timeoutSec + 30)) {
                $r = Receive-Job -Job $j.Job
                $results += $r
                $statusMap[$j.Id] = [string]$r.status
            }
            else {
                Stop-Job -Job $j.Job | Out-Null
                $results += [pscustomobject]@{ id = $j.Id; status = 'timeout'; content = $null; raw_content = ''; tokens_used = @{}; latency_ms = ($timeoutSec * 1000); error = 'job timeout'; retry_count = 0; provider = ''; model = $j.Model; response_format_downgraded = $false; requested_model = $j.Model; backup_used = $false; failed_attempts = @() }
                $statusMap[$j.Id] = 'timeout'
            }
            Remove-Job -Job $j.Job -Force | Out-Null
            Write-Progress-Snapshot -Stage 'in_progress' -Requests $requests -Statuses $statusMap -StartedAt $started
        }
        $mode = 'parallel-ps51-job'
    }
    # Single-request or parallel=false: sequential
    else {
        $results = foreach ($request in $requests) {
            $statusMap[[string]$request.id] = 'in_progress'
            Write-Progress-Snapshot -Stage 'in_progress' -Requests $requests -Statuses $statusMap -StartedAt $started
            $r = Invoke-Request -Request $request -ModelsConfig $modelsConfig -ProvidersConfig $providersConfig -UserKeyMap $userKeyMap -SkillKeyMap $skillKeyMap -TimeoutSec $timeoutSec
            $statusMap[[string]$request.id] = [string]$r.status
            Write-Progress-Snapshot -Stage 'in_progress' -Requests $requests -Statuses $statusMap -StartedAt $started
            $r
        }
        $mode = 'sequential-explicit'
    }

    $cleanResults = foreach ($result in @($results)) {
        [ordered]@{
            id = [string]$result.id
            status = [string]$result.status
            content = $result.content
            # Model output can contain user data. Keep it out of the durable
            # result by default; enable only for local, short-lived debugging.
            raw_content = $(if ($IncludeRawContent -and $null -ne $result.raw_content) { [string]$result.raw_content } else { '' })
            tokens_used = $(if ($null -ne $result.tokens_used) { $result.tokens_used } else { @{} })
            latency_ms = [int]$result.latency_ms
            error = $(if ($null -ne $result.error) { [string]$result.error } else { $null })
            retry_count = [int]$result.retry_count
            provider = [string]$result.provider
            model = [string]$result.model
            response_format_downgraded = [bool]$result.response_format_downgraded
            requested_model = [string]$result.requested_model
            backup_used = [bool]$result.backup_used
            failed_attempts = @($(if ($null -ne $result.failed_attempts) { $result.failed_attempts } else { @() }))
        }
    }
    $finished = Get-Date
    $out = [ordered]@{
        results = @($cleanResults)
        meta = [ordered]@{
            started_at = $started.ToString('o')
            finished_at = $finished.ToString('o')
            total_duration_ms = [int](New-TimeSpan -Start $started -End $finished).TotalMilliseconds
            concurrency_mode = $mode
        }
    }
    Write-Utf8NoBomFile -Path $OutputFile -Content $out
    exit 0
}
catch {
    Write-Error "panel.ps1 input error: $($_.Exception.Message)"
    exit 1
}
