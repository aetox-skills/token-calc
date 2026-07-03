<#
.SYNOPSIS
  Token Auditor -- cost control for self-hosted API users. Project your processing costs before they surprise you.

.DESCRIPTION
  Shows the "first call shock", then projects forward across call milestones
  how many tokens you'll actually pay to process (cache miss + output).
  Designed for anyone running their own API keys -- know your burn rate before it burns.

.PARAMETER InputTokens
  Total input tokens per call.

.PARAMETER CachedInputTokens
  Cache hit portion of input tokens.

.PARAMETER OutputTokens
  Estimated output tokens per call.

.PARAMETER Measure
  Auto-detect OpenCode system prompt.

.PARAMETER Calls
  Number of calls to project (default 1).

.PARAMETER CallsPerSession
  Calls per session (default 10).

.PARAMETER SessionsPerDay
  Sessions per day (default 3).

.PARAMETER Save
  Export current measurement as JSON baseline file.

.PARAMETER Diff
  Compare current measurement against a saved baseline JSON.

.PARAMETER Threshold
  Exit with error if InputTokens exceeds this value. For CI/guard use.

.PARAMETER ContextWindow
  Model context window size (default 200000) for % calculation.

.EXAMPLE
  .\token-calc.ps1 -InputTokens 60000 -CachedInputTokens 52000
  .\token-calc.ps1 -InputTokens 60000 -CachedInputTokens 52000 -Threshold 50000
  .\token-calc.ps1 -Measure -Calls 100
  .\token-calc.ps1 -Measure -Save baseline.json
  .\token-calc.ps1 -Measure -Diff baseline.json
#>

param(
    [long]$InputTokens = 0,
    [long]$CachedInputTokens = 0,
    [long]$OutputTokens = 0,
    [switch]$Measure,
    [long]$Calls = 1,
    [long]$CallsPerSession = 10,
    [long]$SessionsPerDay = 3,
    [string]$Save = '',
    [string]$Diff = '',
    [long]$Threshold = 0,
    [long]$ContextWindow = 200000,
    [string]$Platform = '',
    [string]$Milestones = '1,10,20,50,100'
)

# Force UTF-8 output
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

# --- Measure system prompt (multi-platform) ---
function Measure-SystemPrompt {
    param([string]$TargetPlatform = '')
    $homeDir = $env:USERPROFILE
    $result = @{ total = 0; details = @(); platforms = @{} }

    function Count-Tokens($text) {
        $thai = [regex]::Matches($text, '[\u0E00-\u0E7F]').Count
        $chinese = [regex]::Matches($text, '[\u4E00-\u9FFF]').Count
        return [math]::Ceiling(($text.Length - $thai - $chinese)/4 + $thai/3 + $chinese/3)
    }

    $r = $result
    # -- OpenCode --
    if (!$TargetPlatform -or $TargetPlatform -eq 'opencode') {
        $ocFiles = @(
            @{Path = "$homeDir\CONTEXT.md"; Name = 'CONTEXT.md'},
            @{Path = "$homeDir\PROFILE.md"; Name = 'PROFILE.md'},
            @{Path = "$homeDir\AGENTS.md"; Name = 'AGENTS.md'},
            @{Path = "$homeDir\opencode_data\index.md"; Name = 'index.md'}
        )
        foreach ($f in $ocFiles) {
            if (Test-Path $f.Path) { $tok = Count-Tokens (Get-Content -Raw $f.Path); $r.total += $tok; $r.details += [PSCustomObject]@{Component = $f.Name; Tokens = $tok; Platform = 'OpenCode'}; $r.platforms['OpenCode'] = $true }
        }
        $agentDir = "$homeDir\.config\opencode\agents"
        if (Test-Path $agentDir) {
            foreach ($af in (Get-ChildItem "$agentDir\*.md" -ErrorAction SilentlyContinue)) {
                $c = Get-Content -Raw $af.FullName
                if ($c -match "description:\s*['""]?([^'""\n]+)") {
                    $tok = [math]::Ceiling($Matches[1].Length/4) + [math]::Ceiling($af.BaseName.Length/4)
                    $r.total += $tok; $r.details += [PSCustomObject]@{Component = "$($af.BaseName) (agent)"; Tokens = $tok; Platform = 'OpenCode'}; $r.platforms['OpenCode'] = $true
                }
            }
        }
        $skillDir = "$homeDir\.config\opencode\skills"
        if (Test-Path $skillDir) {
            foreach ($sd in (Get-ChildItem $skillDir -Directory -ErrorAction SilentlyContinue)) {
                $sf = Join-Path $sd.FullName 'SKILL.md'
                if (Test-Path $sf) {
                    $c = Get-Content -Raw $sf
                    if ($c -match "description:\s*['""]?([^'""\n]+)") {
                        $tok = [math]::Ceiling($Matches[1].Length/4) + [math]::Ceiling($sd.Name.Length/4) + 30
                        $r.total += $tok; $r.details += [PSCustomObject]@{Component = "$($sd.Name) (skill)"; Tokens = $tok; Platform = 'OpenCode'}; $r.platforms['OpenCode'] = $true
                    }
                }
            }
        }
    }

    # -- ZCode --
    if (!$TargetPlatform -or $TargetPlatform -eq 'zcode') {
        $zAgentDir = "$homeDir\.zcode\agents"
        if (Test-Path $zAgentDir) {
            foreach ($af in (Get-ChildItem "$zAgentDir\*.md" -ErrorAction SilentlyContinue)) {
                $c = Get-Content -Raw $af.FullName
                if ($c -match "description:\s*['""]?([^'""\n]+)") {
                    $tok = [math]::Ceiling($Matches[1].Length/4) + [math]::Ceiling($af.BaseName.Length/4)
                    $r.total += $tok; $r.details += [PSCustomObject]@{Component = "$($af.BaseName) (agent)"; Tokens = $tok; Platform = 'ZCode'}; $r.platforms['ZCode'] = $true
                }
            }
        }
        $zSkillDir = "$homeDir\.zcode\skills"
        if (Test-Path $zSkillDir) {
            foreach ($sd in (Get-ChildItem $zSkillDir -Directory -ErrorAction SilentlyContinue)) {
                $sf = Join-Path $sd.FullName 'SKILL.md'
                if (Test-Path $sf) {
                    $c = Get-Content -Raw $sf
                    if ($c -match "description:\s*['""]?([^'""\n]+)") {
                        $tok = [math]::Ceiling($Matches[1].Length/4) + [math]::Ceiling($sd.Name.Length/4) + 30
                        $r.total += $tok; $r.details += [PSCustomObject]@{Component = "$($sd.Name) (skill)"; Tokens = $tok; Platform = 'ZCode'}; $r.platforms['ZCode'] = $true
                    }
                }
            }
        }
    }

    # -- Claude Code --
    if (!$TargetPlatform -or $TargetPlatform -eq 'claude') {
        $claudeFile = "$homeDir\.claude\instructions.md"
        if (Test-Path $claudeFile) { $tok = Count-Tokens (Get-Content -Raw $claudeFile); $r.total += $tok; $r.details += [PSCustomObject]@{Component = 'instructions.md'; Tokens = $tok; Platform = 'Claude'}; $r.platforms['Claude'] = $true }
    }

    # --- MCP Server Registry ---
    # Token counts measured from actual tool definitions (name + description + parameter schemas)
    $McpRegistry = @{
        'obsidian'            = @{ tools=15; tok=1150; desc='Obsidian vault (15 tools: read/write/search/manage)' }
        'sequential-thinking' = @{ tools=1;  tok=550;  desc='Sequential thinking (1 tool, 11 complex params)' }
        'exa'                 = @{ tools=2;  tok=250;  desc='Exa semantic search + fetch' }
        'context7'            = @{ tools=2;  tok=250;  desc='Context7 library docs resolve + query' }
        'gmail'               = @{ tools=4;  tok=600;  desc='Gmail send/read/search/draft' }
        'speak'               = @{ tools=1;  tok=100;  desc='Thai TTS speak tool' }
        'image-resolver'      = @{ tools=2;  tok=200;  desc='Pexels/Unsplash image search' }
        'pixabay'             = @{ tools=2;  tok=200;  desc='Pixabay media search' }
    }

    # Parse actual active MCP servers from opencode.jsonc
    $mcpConfigPath = "$homeDir\.config\opencode\opencode.jsonc"
    $activeServers = @()
    if (Test-Path $mcpConfigPath) {
        $mcpLines = Get-Content $mcpConfigPath
        $inMcp = $false; $mcpIndent = -1; $serverIndent = -1
        foreach ($line in $mcpLines) {
            $indent = $line.Length - $line.TrimStart().Length
            $trimmed = $line.Trim()
            
            if ($trimmed -match '"mcp"\s*:\s*\{') {
                $inMcp = $true
                $mcpIndent = $indent
                $serverIndent = $indent + 2
                continue
            }
            if (!$inMcp) { continue }
            
            # Leave mcp section when we hit a brace at mcp indent level or lower
            if ($indent -le $mcpIndent -and $trimmed -eq '}' -and $line -notmatch '\{') {
                $inMcp = $false; break
            }
            
            # Skip comments
            if ($trimmed -match '^//') { continue }
            
            # Match server names: at exactly serverIndent level
            if ($indent -eq $serverIndent -and $trimmed -match '^"([^"]+)"\s*:\s*\{') {
                $activeServers += $Matches[1]
            }
        }
    }

    # Calculate MCP tokens from real config
    $mcpTok = 0
    foreach ($srvName in $activeServers) {
        $known = $McpRegistry[$srvName]
        if ($known) {
            $mcpTok += $known.tok
            $r.details += [PSCustomObject]@{Component = "MCP: $srvName ($($known.tools) tools)"; Tokens = $known.tok; Platform = 'common'}
        } else {
            # Unknown server — rough estimate
            $est = 300
            $mcpTok += $est
            $r.details += [PSCustomObject]@{Component = "MCP: $srvName [unknown, est]"; Tokens = $est; Platform = 'common'}
        }
    }
    if ($activeServers.Count -gt 0) {
        # MCP instruction blocks + list/read_resource meta tools
        $mcpOverhead = 500
        $mcpTok += $mcpOverhead
        $r.details += [PSCustomObject]@{Component = "MCP: system overhead (instructions + meta)"; Tokens = $mcpOverhead; Platform = 'common'}
    }
    $r.total += $mcpTok

    $r.total += 2000; $r.details += [PSCustomObject]@{Component = 'System overhead'; Tokens = 2000; Platform = 'common'}
    $r.total += 5000; $r.details += [PSCustomObject]@{Component = 'History (capped ~10 msgs)'; Tokens = 5000; Platform = 'common'}

    $platformsList = ($r.platforms.Keys | Where-Object { $_ -ne 'common' }) -join ', '
    return @{ total = $r.total; details = $r.details; timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'); platforms = $platformsList }
}

# Load previous baseline
$previous = $null
if ($Diff -and (Test-Path $Diff)) { try { $previous = Get-Content -Raw $Diff | ConvertFrom-Json } catch {} }

# Auto-measure
$measureResult = $null
if ($Measure) {
    $platArg = if ($Platform) { $Platform.ToLower() } else { '' }
    Write-Host "`n[measure] Measuring system prompt..." -ForegroundColor Cyan
    $measureResult = Measure-SystemPrompt -TargetPlatform $platArg
    $InputTokens = $measureResult.total
    if ($CachedInputTokens -eq 0) { $CachedInputTokens = [long][math]::Round($measureResult.total * 0.3) }

    Write-Host "  Platforms detected: $($measureResult.platforms)" -ForegroundColor DarkGray
    $measureResult.details | Sort-Object Tokens -Descending | ForEach-Object {
        $comp = $_.Component.PadRight(40)
        $tok = $_.Tokens.ToString('N0').PadLeft(8)
        Write-Host "  $comp $tok"
    }
    Write-Host "  $("TOTAL system prompt".PadRight(44))$($measureResult.total.ToString('N0')) tok" -ForegroundColor Cyan

    if ($Save) {
        $measureResult.details | Select-Object Component, Tokens, Platform | ConvertTo-Json | Set-Content $Save
        Write-Host "`n[save] Baseline saved -> $Save" -ForegroundColor DarkGray
    }
}

# Validate
if ($InputTokens -le 0 -and $OutputTokens -le 0) {
    Write-Error "Need at least some tokens. Use -Measure or -InputTokens."
    exit 1
}

# Threshold guard
if ($Threshold -gt 0 -and $InputTokens -gt $Threshold) {
    Write-Host "`n[ALERT] THRESHOLD EXCEEDED!" -ForegroundColor Red -BackgroundColor Black
    Write-Host "  Input: $($InputTokens.ToString('N0')) tok > Limit: $($Threshold.ToString('N0')) tok" -ForegroundColor Red
    exit 2
}

# Calculations
$cacheMissTokens = [math]::Max(0, $InputTokens - $CachedInputTokens)
$totalSentPerCall = $InputTokens + $OutputTokens
$cacheHitRate  = if ($InputTokens -gt 0) { $CachedInputTokens / $InputTokens } else { 0 }
$cacheMissRate = 1 - $cacheHitRate
$ctxPct = if ($ContextWindow -gt 0) { $InputTokens / $ContextWindow * 100 } else { 0 }
$firstCallNew  = $totalSentPerCall
$eachRepeatedNew = $cacheMissTokens + $OutputTokens
$effectiveCumulative = $firstCallNew + ($eachRepeatedNew * ($Calls - 1))
$shockMultiplier = if ($eachRepeatedNew -gt 0) { [math]::Round($firstCallNew / $eachRepeatedNew, 1) } else { 1 }
$perSession = $totalSentPerCall * $CallsPerSession
$perDay     = $perSession * $SessionsPerDay

# Risk level
$riskColor = 'Green'; $riskLabel = 'LOW'
if ($InputTokens -gt 20000) { $riskColor = 'Yellow'; $riskLabel = 'CAUTION' }
if ($InputTokens -gt 50000) { $riskColor = 'Red';   $riskLabel = 'HIGH' }

# Recommendations
$recs = @()
if ($Measure -and $measureResult) {
    $mcpTotal = ($measureResult.details | Where-Object { $_.Component -like 'MCP*' } | Measure-Object Tokens -Sum).Sum
    $mcpPct = if ($measureResult.total -gt 0) { $mcpTotal / $measureResult.total * 100 } else { 0 }
    if ($mcpPct -gt 50) { $recs += "MCP tools dominate ($($mcpPct.ToString('N0'))%). Merge or disable unused servers." }
    $largest = $measureResult.details | Sort-Object Tokens -Descending | Select-Object -First 3
    $recs += "Top 3 optimization targets by platform: $($largest[0].Component) [$($largest[0].Platform)] ($($largest[0].Tokens.ToString('N0')) tok), $($largest[1].Component) [$($largest[1].Platform)] ($($largest[1].Tokens.ToString('N0')) tok), $($largest[2].Component) [$($largest[2].Platform)] ($($largest[2].Tokens.ToString('N0')) tok)"
}
if ($cacheHitRate -lt 0.4 -and $InputTokens -gt 0) {
    $recs += "Cache too low ($($cacheHitRate.ToString('P1'))). Structure prompt for reuse."
}
if ($InputTokens -gt 50000) {
    $recs += "CRITICAL: Input $($InputTokens.ToString('N0')) tok eats $($ctxPct.ToString('N0'))% of $($ContextWindow.ToString('N0')) context window."
}
if ($OutputTokens -eq 0) { $recs += "Add -OutputTokens for complete per-call picture (model response)." }
if ($Threshold -eq 0) { $recs += "Set -Threshold <tok> to guard against surprises in CI/scripts." }

# Diff
$diffs = @()
if ($previous -and $measureResult) {
    $prevTotal = ($previous | Measure-Object Tokens -Sum).Sum
    $diffTok = $measureResult.total - $prevTotal
    $pct = if ($prevTotal -gt 0) { [math]::Round($diffTok / $prevTotal * 100, 1) } else { 0 }
    $arrow = if ($diffTok -ge 0) { "+" } else { "-" }
    $diffs += "Overall: $arrow $([math]::Abs($diffTok).ToString('N0')) tok ($pct%)"
    $compMap = @{}; $previous | ForEach-Object { $compMap[$_.Component] = $_.Tokens }
    foreach ($d in $measureResult.details) {
        $old = if ($compMap.ContainsKey($d.Component)) { $compMap[$d.Component] } else { 0 }
        if ($old -ne $d.Tokens) {
            $dArrow = if ($d.Tokens -ge $old) { "+" } else { "-" }
            $diffs += "$($d.Component): $dArrow $([math]::Abs($d.Tokens - $old).ToString('N0')) tok"
        }
    }
}

# ============================================================
# DISPLAY
# ============================================================
function Write-Line { Write-Host ("-" * 60) -ForegroundColor DarkGray }

# Header with risk
Write-Line
Write-Host "  TOKEN AUDITOR  *  RISK: $riskLabel" -ForegroundColor $riskColor
Write-Line

# First call shock
if ($Calls -gt 1) {
    Write-Host "`n[!] FIRST CALL SHOCK" -ForegroundColor $riskColor
    Write-Host "  Opening this session costs you $($firstCallNew.ToString('N0')) tok before you type." -ForegroundColor $riskColor
    Write-Host "  That's $($ctxPct.ToString('N0'))% of your $($ContextWindow.ToString('N0')) context window." -ForegroundColor $riskColor
    Write-Host "  Each subsequent call costs only $($eachRepeatedNew.ToString('N0')) tok (cache kicks in)."
    Write-Host "  First call = $shockMultiplier`x the cost of a repeated call." -ForegroundColor $riskColor
}

# Breakdown
Write-Host "`n[chart] TOKEN BREAKDOWN (per call)" -ForegroundColor Yellow
Write-Host ("  " + "Input Sent".PadRight(30) + " " + $InputTokens.ToString('N0').PadLeft(12))
Write-Host ("  " + "  --> Cache Hit (reused)".PadRight(30) + " " + $CachedInputTokens.ToString('N0').PadLeft(12))
Write-Host ("  " + "  --> Cache Miss (fresh)".PadRight(30) + " " + $cacheMissTokens.ToString('N0').PadLeft(12))
if ($OutputTokens -gt 0) {
    Write-Host ("  " + "Output Received".PadRight(30) + " " + $OutputTokens.ToString('N0').PadLeft(12))
}
Write-Host ("  " + "Total Sent/Received".PadRight(30) + " " + $totalSentPerCall.ToString('N0').PadLeft(12)) -ForegroundColor Cyan
Write-Host ("  " + "Context Window Used".PadRight(30) + " " + ($ctxPct.ToString('N0') + "%").PadLeft(12))

# Cache
Write-Host "`n[chart] CACHE EFFICIENCY" -ForegroundColor Yellow
Write-Host ("  " + "Cache Hit Rate".PadRight(33) + " " + $cacheHitRate.ToString('P1').PadLeft(12))
Write-Host ("  " + "Cache Miss Rate".PadRight(33) + " " + $cacheMissRate.ToString('P1').PadLeft(12))
Write-Host ("  " + "Reused per Call".PadRight(33) + " " + $CachedInputTokens.ToString('N0').PadLeft(12))

# Processing projector
$mslist = $Milestones -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -match '^\d+$' } | ForEach-Object { [long]$_ } | Where-Object { $_ -le $Calls }
if ($mslist.Count -gt 1) {
    Write-Host "`n[loop] PROCESSING PROJECTOR" -ForegroundColor Yellow
    Write-Host "  What you'll actually pay to process at each stage:" -ForegroundColor DarkGray
    Write-Host ("  " + "Calls".PadRight(8) + "  " + "Total Sent".PadLeft(14) + "  " + "Processed (pay)".PadLeft(14))
    Write-Host ("  " + ("-" * 5).PadRight(8) + "  " + ("-" * 12).PadLeft(14) + "  " + ("-" * 14).PadLeft(14))
    foreach ($m in $mslist) {
        $msent = $totalSentPerCall * $m
        $mproc = $firstCallNew + ($eachRepeatedNew * ($m - 1))
        $mColor = if ($m -eq 1) { $riskColor } else { 'Gray' }
        Write-Host ("  " + $m.ToString().PadRight(6) + "  " + $msent.ToString('N0').PadLeft(14) + "  " + $mproc.ToString('N0').PadLeft(14)) -ForegroundColor $mColor
    }
    Write-Host ("  Note: 'Processed (pay)' = first call full + repeated fresh-only (cache miss + output)") -ForegroundColor DarkGray
}

# Recommendations
if ($recs.Count -gt 0) {
    Write-Host "`n[tip] RECOMMENDATIONS" -ForegroundColor Green
    foreach ($r in $recs) { Write-Host "  * $r" }
}

# Diff display
if ($diffs.Count -gt 0) {
    Write-Host "`n[down] DIFF vs BASELINE" -ForegroundColor Cyan
    foreach ($d in $diffs) { Write-Host "  * $d" }
}

Write-Line
Write-Host "  Token counts are approximate. Use exact tokenizer for billing." -ForegroundColor DarkGray
Write-Host
