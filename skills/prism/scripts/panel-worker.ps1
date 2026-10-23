# panel-worker.ps1 -- shared functions for panel.ps1
# Dot-sourced by main script and by PS7 parallel runspaces.
# Depends on caller providing $ConfigRoot, $UserPrismRoot, $ProgressFile in the scope where needed.

function Write-Utf8NoBomFile {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)]$Content)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $encoding = New-Object System.Text.UTF8Encoding($false)
    if ($Content -is [string]) { $text = $Content } else { $text = ($Content | ConvertTo-Json -Depth 100) }
    [System.IO.File]::WriteAllText($Path, $text, $encoding)
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "JSON file not found: $Path" }
    try {
        $raw = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path), [System.Text.Encoding]::UTF8)
        if ([string]::IsNullOrWhiteSpace($raw)) { throw 'JSON content is empty' }
        return ($raw | ConvertFrom-Json)
    }
    catch { throw "Invalid JSON in ${Path}: $($_.Exception.Message)" }
}

function Read-KeyFile {
    param([string]$Path)
    $map = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $map }
    foreach ($line in [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        $idx = $trimmed.IndexOf('=')
        if ($idx -le 0) { continue }
        $name = $trimmed.Substring(0, $idx).Trim()
        $value = $trimmed.Substring($idx + 1).Trim().Trim('"').Trim("'")
        if ($name) { $map[$name] = $value }
    }
    return $map
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

function Merge-Object {
    param($Base, $Override)
    if ($null -eq $Override) { return $null }
    if ($null -eq $Base) { return (ConvertTo-Hashtable $Override) }
    $baseHash = ConvertTo-Hashtable $Base
    $overrideHash = ConvertTo-Hashtable $Override
    if ($baseHash -isnot [System.Collections.IDictionary] -or $overrideHash -isnot [System.Collections.IDictionary]) {
        return $overrideHash
    }
    $merged = [ordered]@{}
    foreach ($key in $baseHash.Keys) { $merged[$key] = $baseHash[$key] }
    foreach ($key in $overrideHash.Keys) {
        if ($null -eq $overrideHash[$key]) {
            $merged[$key] = $null
        }
        elseif ($merged.Contains($key) -and $merged[$key] -is [System.Collections.IDictionary] -and $overrideHash[$key] -is [System.Collections.IDictionary]) {
            $merged[$key] = Merge-Object $merged[$key] $overrideHash[$key]
        }
        else {
            $merged[$key] = $overrideHash[$key]
        }
    }
    return $merged
}

function Get-ConfigValue {
    param([string]$Name, [hashtable]$UserKeyMap, [hashtable]$SkillKeyMap)
    $value = [Environment]::GetEnvironmentVariable($Name, 'Process')
    if ($value) { return $value }
    if ($UserKeyMap.ContainsKey($Name)) { return $UserKeyMap[$Name] }
    if ($SkillKeyMap.ContainsKey($Name)) { return $SkillKeyMap[$Name] }
    return $null
}

function Get-RetryPolicy {
    param($Provider)
    $policy = @{ max_attempts = 3; retry_on_status = @(429,503,504); retry_on_body_match = @(); backoff_seconds = @(2,5) }
    if ($null -ne $Provider.retry) {
        foreach ($name in @('max_attempts','retry_on_status','retry_on_body_match','backoff_seconds')) {
            if ($Provider.retry.Contains($name) -and $null -ne $Provider.retry[$name]) { $policy[$name] = $Provider.retry[$name] }
        }
    }
    return $policy
}

function Get-SafeErrorMessage {
    param($ErrorRecord)
    $msg = [string]$ErrorRecord.Exception.Message
    $status = $null
    try { $status = [int]$ErrorRecord.Exception.Response.StatusCode } catch { }
    if ($msg -match 'fake_sse_empty_response') { return 'Provider returned empty SSE stream (upstream model unavailable)' }
    if ($status -eq 401 -or $status -eq 403 -or $msg -match '(?i)unauthorized|forbidden|invalid api key|authentication') { return 'API authentication failed or key is invalid' }
    if ($status) { return "HTTP $status call failed" }
    if ($msg.Length -gt 240) { return $msg.Substring(0, 240) }
    return $msg
}

function Repair-JsonTail {
    param([string]$Raw)
    if ([string]::IsNullOrWhiteSpace($Raw)) { return $Raw }
    $trimmed = $Raw.TrimEnd()
    for ($i = 0; $i -lt 3; $i++) {
        try { $null = $trimmed | ConvertFrom-Json; return $trimmed } catch { }
        if ($trimmed.EndsWith('}') -or $trimmed.EndsWith(']')) { $trimmed = $trimmed.Substring(0, $trimmed.Length - 1).TrimEnd() }
        else { return $Raw }
    }
    return $Raw
}

function Build-Body {
    param($Request, $Model, $Provider, [string]$Format)
    $temperature = 0.7
    if ($Provider.request_defaults -and $Provider.request_defaults.Contains('temperature') -and $null -ne $Provider.request_defaults.temperature) { $temperature = [double]$Provider.request_defaults.temperature }
    if ($Request.temperature) { $temperature = [double]$Request.temperature }
    if ($Model.overrides -and $Model.overrides.Contains('temperature') -and $null -ne $Model.overrides.temperature) { $temperature = [double]$Model.overrides.temperature }

    $maxTokens = 8000
    if ($Provider.request_defaults -and $Provider.request_defaults.Contains('max_tokens') -and $null -ne $Provider.request_defaults.max_tokens) { $maxTokens = [int]$Provider.request_defaults.max_tokens }
    if ($Request.max_tokens) { $maxTokens = [int]$Request.max_tokens }
    if ($Model.overrides -and $Model.overrides.Contains('max_tokens') -and $null -ne $Model.overrides.max_tokens) { $maxTokens = [int]$Model.overrides.max_tokens }
    if ([string]$Model.model_type -eq 'reasoning' -and $maxTokens -lt 16000) { $maxTokens = 16000 }

    $body = [ordered]@{
        model = [string]$Model.model_id
        messages = @(
            @{ role = 'system'; content = [string]$Request.system_prompt },
            @{ role = 'user'; content = [string]$Request.user_prompt }
        )
        temperature = $temperature
        max_tokens = $maxTokens
    }
    if ($Format -eq 'json_schema') {
        $schema = $Request.schema
        if ($null -eq $schema) { $schema = @{ type = 'object' } }
        $schemaName = ('prism_' + ([string]$Request.id -replace '[^A-Za-z0-9_]', '_'))
        $body.response_format = @{ type = 'json_schema'; json_schema = @{ name = $schemaName; schema = $schema; strict = $true } }
    }
    elseif ($Format -eq 'json_object') { $body.response_format = @{ type = 'json_object' } }
    return $body
}

function Invoke-ChatOnce {
    param($Request, $Model, $Provider, [string]$Key, [int]$TimeoutSec, [string]$Format, [string]$ProviderName)
    $uri = ([string]$Provider.base_url).TrimEnd('/') + [string]$Provider.chat_path
    $headers = @{ Authorization = "Bearer $Key"; 'Content-Type' = 'application/json' }
    if ($Provider.extra_headers) {
        foreach ($name in $Provider.extra_headers.Keys) {
            if ($null -ne $Provider.extra_headers[$name]) { $headers[$name] = [string]$Provider.extra_headers[$name] }
        }
    }
    $sanitizedRequest = $Request.PSObject.Copy()
    $sysPrompt = [string]$Request.system_prompt
    $usrPrompt = [string]$Request.user_prompt
    # deepseek backend rejects U+00B7 middle dot with HTTP 400 empty body. Sanitize.
    if ($ProviderName -eq 'deepseek') {
        $sysPrompt = $sysPrompt -replace [char]0x00B7, ','
        $usrPrompt = $usrPrompt -replace [char]0x00B7, ','
    }
    # P1-4: response_format=json_object requires messages contain lowercase 'json'. Auto-append if missing.
    if ($Format -eq 'json_object') {
        $combined = $sysPrompt + ' ' + $usrPrompt
        if ($combined -cnotmatch 'json') {
            $usrPrompt = $usrPrompt + ' Please reply in json format.'
        }
    }
    $sanitizedRequest | Add-Member -NotePropertyName system_prompt -NotePropertyValue $sysPrompt -Force
    $sanitizedRequest | Add-Member -NotePropertyName user_prompt -NotePropertyValue $usrPrompt -Force
    $body = Build-Body -Request $sanitizedRequest -Model $Model -Provider $Provider -Format $Format
    $json = $body | ConvertTo-Json -Depth 100
    $jsonBytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $resp = Invoke-WebRequest -Method Post -Uri $uri -Headers $headers -Body $jsonBytes -TimeoutSec $TimeoutSec -UseBasicParsing
    $rawBody = [System.Text.Encoding]::UTF8.GetString($resp.RawContentStream.ToArray())
    if ($rawBody.TrimStart().StartsWith('data:')) {
        if ($rawBody -match 'choices\s*"?\s*:\s*\[\s*\]' -or $rawBody -match 'data:\s*\[DONE\]') { throw 'fake_sse_empty_response' }
        throw 'SSE response is not supported by panel.ps1'
    }
    return ($rawBody | ConvertFrom-Json)
}

function Invoke-Model {
    param($Request, $ModelName, $ModelsConfig, $ProvidersConfig, [hashtable]$UserKeyMap, [hashtable]$SkillKeyMap, [int]$TimeoutSec)
    $model = $ModelsConfig.models[$ModelName]
    if ($null -eq $model) { throw "Unknown model: $ModelName" }
    $providerName = [string]$model.provider
    $provider = $ProvidersConfig.providers[$providerName]
    if ($null -eq $provider) { throw "Unknown provider $providerName for model $ModelName" }
    $baseOverride = $null
    if ($provider.Contains('base_env') -and $provider.base_env) { $baseOverride = Get-ConfigValue -Name ([string]$provider.base_env) -UserKeyMap $UserKeyMap -SkillKeyMap $SkillKeyMap }
    if ($baseOverride) {
        $overrideUri = $null
        if (-not [Uri]::TryCreate([string]$baseOverride, [UriKind]::Absolute, [ref]$overrideUri)) { throw 'Configured base URL override is not an absolute URL' }
        if ($overrideUri.Scheme -ne 'https' -and -not ($overrideUri.Scheme -eq 'http' -and @('localhost','127.0.0.1','::1') -contains $overrideUri.Host)) { throw 'Configured base URL override must use HTTPS (HTTP is allowed only for localhost)' }
        $provider = Merge-Object $provider @{ base_url = $baseOverride }
    }
    $key = Get-ConfigValue -Name ([string]$provider.key_env) -UserKeyMap $UserKeyMap -SkillKeyMap $SkillKeyMap
    if (-not $key) { throw "Missing $($provider.key_env); see INSTALL.md or run init-prism.ps1" }
    if ($key -match '^(sk-your-|your-|fake($|-)|dummy($|-)|placeholder($|-)|sk-test($|-))') { throw 'API authentication failed or key is invalid (placeholder/test key detected; request not sent)' }

    $policy = Get-RetryPolicy $provider
    $maxAttempts = [int]$policy.max_attempts
    if ($maxAttempts -lt 1) { $maxAttempts = 1 }
    $format = if ($Request.response_format) { [string]$Request.response_format } else { 'json_schema' }
    $retryCount = 0
    $downgraded = $false
    $lastError = $null
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            return @{ response = (Invoke-ChatOnce -Request $Request -Model $model -Provider $provider -Key $key -TimeoutSec $TimeoutSec -Format $format -ProviderName $providerName); retry_count = $retryCount; provider = $providerName; downgraded = $downgraded; model = $ModelName }
        }
        catch {
            $lastError = $_
            $status = 0
            try { $status = [int]$_.Exception.Response.StatusCode } catch { $status = 0 }
            if ($status -eq 400 -and $format -eq 'json_schema') { $format = 'json_object'; $downgraded = $true }
            elseif ($status -eq 400 -and $format -eq 'json_object') { $format = 'text'; $downgraded = $true }
            $retryable = $false
            if (@($policy.retry_on_status) -contains $status) { $retryable = $true }
            foreach ($pattern in @($policy.retry_on_body_match)) {
                if ([string]$_.Exception.Message -match $pattern) { $retryable = $true }
            }
            if (-not $retryable -and [string]$_.Exception.Message -match 'fake_sse_empty_response') { $retryable = $true }
            if ($attempt -lt $maxAttempts -and $retryable) {
                $delay = 1
                if (@($policy.backoff_seconds).Count -ge $attempt) { $delay = [int]@($policy.backoff_seconds)[$attempt - 1] }
                Start-Sleep -Seconds $delay
                $retryCount++
                continue
            }
            throw $lastError
        }
    }
    throw $lastError
}

function Invoke-Request {
    param($Request, $ModelsConfig, $ProvidersConfig, [hashtable]$UserKeyMap, [hashtable]$SkillKeyMap, [int]$TimeoutSec)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $rawContent = ''
    $requestedModel = [string]$Request.model
    $failedAttempts = @()
    try {
        $modelQueue = @([string]$Request.model)
        foreach ($backup in @($ModelsConfig.pools.backup_pool)) {
            $backupName = [string]$backup
            $backupModel = $ModelsConfig.models[$backupName]
            if ($null -ne $backupModel -and $backupModel.Contains('disabled_by_default') -and $backupModel.disabled_by_default -eq $true) { continue }
            if ($modelQueue -notcontains $backupName) { $modelQueue += $backupName }
        }
        $lastFailure = $null
        foreach ($modelName in $modelQueue) {
            try {
                $result = Invoke-Model -Request $Request -ModelName $modelName -ModelsConfig $ModelsConfig -ProvidersConfig $ProvidersConfig -UserKeyMap $UserKeyMap -SkillKeyMap $SkillKeyMap -TimeoutSec $TimeoutSec
                $apiResponse = $result.response
                $rawContent = [string]$apiResponse.choices[0].message.content
                if ([string]::IsNullOrWhiteSpace($rawContent)) { throw 'Model returned empty content' }
                $content = $rawContent
                $status = 'success'
                $requestedFormat = if ($Request.response_format) { [string]$Request.response_format } else { 'json_schema' }
                if ($requestedFormat -ne 'text') {
                    $parsed = $false
                    try { $content = $rawContent | ConvertFrom-Json; $parsed = $true } catch { $parsed = $false }
                    if (-not $parsed) {
                        $repaired = Repair-JsonTail -Raw $rawContent
                        try { $content = $repaired | ConvertFrom-Json; $parsed = $true; $rawContent = $repaired } catch { $parsed = $false }
                    }
                    if (-not $parsed) { $status = 'invalid_response'; $content = $null }
                }
                $sw.Stop()
                $actualModel = [string]$result.model
                $backupUsed = ($actualModel -ne $requestedModel)
                return [pscustomobject]@{
                    id = [string]$Request.id; status = $status; content = $content; raw_content = $rawContent
                    tokens_used = $(if ($apiResponse.usage) { $apiResponse.usage } else { @{} }); latency_ms = [int]$sw.ElapsedMilliseconds
                    error = $(if ($status -eq 'success') { $null } else { 'Model returned invalid JSON' })
                    retry_count = [int]$result.retry_count; provider = [string]$result.provider; model = $actualModel
                    response_format_downgraded = [bool]$result.downgraded
                    requested_model = $requestedModel
                    backup_used = $backupUsed
                    failed_attempts = @($failedAttempts)
                }
            }
            catch {
                $lastFailure = $_
                $failMsg = Get-SafeErrorMessage $_
                $failedAttempts += @{ model = $modelName; error = $failMsg }
                # Do not forward the same user prompt to another provider after a
                # client/auth/config error. Fallback is reserved for transient
                # upstream failures (429/5xx/timeouts and empty responses).
                $status = 0
                try { $status = [int]$_.Exception.Response.StatusCode } catch { $status = 0 }
                if ($status -in @(400,401,403,404,422)) { break }
            }
        }
        throw $lastFailure
    }
    catch {
        $sw.Stop()
        $message = Get-SafeErrorMessage $_
        $status = if ($message -match '(?i)timed out|timeout') { 'timeout' } else { 'failed' }
        return [pscustomobject]@{
            id = [string]$Request.id; status = $status; content = $null; raw_content = $rawContent
            tokens_used = @{}; latency_ms = [int]$sw.ElapsedMilliseconds
            error = $message; retry_count = 0; provider = ''; model = $requestedModel
            response_format_downgraded = $false
            requested_model = $requestedModel
            backup_used = $false
            failed_attempts = @($failedAttempts)
        }
    }
}
