<#
.SYNOPSIS
  Token Auditor — inspect system prompt, warn against surprise costs.

.DESCRIPTION
  One-shot inspection that shows what you're spending before you spend it.
  Highlights the "first call shock" — the 60K+ tokens gone before you type anything.
  Includes risk levels, context window %, and optional threshold guard.

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
    [long]$ContextWindow = 200000
)

# ─── Measure system prompt ────────────────────────────────
function Measure-SystemPrompt {
    $files = @(
        'C:\Users\Gigabyte\CONTEXT.md',
        'C:\Users\Gigabyte\PROFILE.md',
        'C:\Users\Gigabyte\AGENTS.md',
        'E:\MikeData\opencode_data\index.md'
    )
    $agentDir = 'C:\Users\Gigabyte\.config\opencode\agents'
    $skillDir = 'C:\Users\Gigabyte\.config\opencode\skills'
    $total = 0; $details = @()

    foreach ($f in $files) {
        if (Test-Path $f) {
            $c = Get-Content -Raw $f
            $thai = [regex]::Matches($c, '[\u0E00-\u0E7F]').Count
            $chinese = [regex]::Matches($c, '[\u4E00-\u9FFF]').Count
            $tok = [math]::Ceiling(($c.Length - $thai - $chinese)/4 + $thai/3 + $chinese/3)
            $total += $tok; $details += [PSCustomObject]@{Component = $f.Split('\')[-1]; Tokens = $tok}
        }
    }
    if (Test-Path $agentDir) {
        foreach ($af in (Get-ChildItem "$agentDir\*.md")) {
            $c = Get-Content -Raw $af.FullName
            if ($c -match "description:\s*['""]?([^'""\n]+)") {
                $tok = [math]::Ceiling($Matches[1].Length/4) + [math]::Ceiling($af.BaseName.Length/4)
                $total += $tok; $details += [PSCustomObject]@{Component = "$($af.BaseName) (agent)"; Tokens = $tok}
            }
        }
    }
    if (Test-Path $skillDir) {
        foreach ($sd in (Get-ChildItem $skillDir -Directory)) {
            $sf = Join-Path $sd.FullName 'SKILL.md'
            if (Test-Path $sf) {
                $c = Get-Content -Raw $sf
                if ($c -match "description:\s*['""]?([^'""\n]+)") {
                    $tok = [math]::Ceiling($Matches[1].Length/4) + [math]::Ceiling($sd.Name.Length/4) + 30
                    $total += $tok; $details += [PSCustomObject]@{Component = "$($sd.Name) (skill)"; Tokens = $tok}
                }
            }
        }
    }
    $mcp = 4 * 3000; $ov = 2000; $total += $mcp + $ov
    $details += [PSCustomObject]@{Component = "MCP tools x4"; Tokens = $mcp}
    $details += [PSCustomObject]@{Component = 'OpenCode overhead'; Tokens = $ov}
    return @{ total = $total; details = $details; timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') }
}

# ─── Load previous baseline ───────────────────────────────
$previous = $null
if ($Diff -and (Test-Path $Diff)) { try { $previous = Get-Content -Raw $Diff | ConvertFrom-Json } catch {} }

# ─── Auto-measure ─────────────────────────────────────────
$measureResult = $null
if ($Measure) {
    Write-Host "`n📏 Measuring system prompt..." -ForegroundColor Cyan
    $measureResult = Measure-SystemPrompt
    $InputTokens = $measureResult.total
    if ($CachedInputTokens -eq 0) { $CachedInputTokens = [long][math]::Round($measureResult.total * 0.3) }

    $measureResult.details | Sort-Object Tokens -Descending | ForEach-Object {
        Write-Host ("  {0,-40} {1,8:N0}" -f $_.Component, $_.Tokens)
    }
    Write-Host ("  " + "TOTAL system prompt".PadRight(44) + "$("{0:N0}" -f $measureResult.total) tok") -ForegroundColor Cyan

    if ($Save) {
        $measureResult.details | Select-Object Component, Tokens | ConvertTo-Json | Set-Content $Save
        Write-Host "`n💾 Baseline saved → $Save" -ForegroundColor DarkGray
    }
}

# ─── Validate ─────────────────────────────────────────────
if ($InputTokens -le 0 -and $OutputTokens -le 0) {
    Write-Error "Need at least some tokens. Use -Measure or -InputTokens."
    exit 1
}

# ─── Threshold guard ──────────────────────────────────────
if ($Threshold -gt 0 -and $InputTokens -gt $Threshold) {
    Write-Host "`n🚨 THRESHOLD EXCEEDED!" -ForegroundColor Red -BackgroundColor Black
    Write-Host "  Input: $("{0:N0}" -f $InputTokens) tok > Limit: $("{0:N0}" -f $Threshold) tok" -ForegroundColor Red
    exit 2
}

# ─── Calculations ─────────────────────────────────────────
$cacheMissTokens = [math]::Max(0, $InputTokens - $CachedInputTokens)
$totalSentPerCall = $InputTokens + $OutputTokens
$cacheHitRate  = if ($InputTokens -gt 0) { $CachedInputTokens / $InputTokens } else { 0 }
$cacheMissRate = 1 - $cacheHitRate
$ctxPct = if ($ContextWindow -gt 0) { $InputTokens / $ContextWindow * 100 } else { 0 }
$rawCumulative = $totalSentPerCall * $Calls
$firstCallNew  = $totalSentPerCall
$eachRepeatedNew = $cacheMissTokens + $OutputTokens
$effectiveCumulative = $firstCallNew + ($eachRepeatedNew * ($Calls - 1))
$shockMultiplier = if ($eachRepeatedNew -gt 0) { [math]::Round($firstCallNew / $eachRepeatedNew, 1) } else { 1 }
$perSession = $totalSentPerCall * $CallsPerSession
$perDay     = $perSession * $SessionsPerDay

# ─── Risk level ───────────────────────────────────────────
$riskColor = 'Green'; $riskLabel = 'LOW'
if ($InputTokens -gt 20000) { $riskColor = 'Yellow'; $riskLabel = 'CAUTION' }
if ($InputTokens -gt 50000) { $riskColor = 'Red';   $riskLabel = 'HIGH' }

# ─── Recommendations ──────────────────────────────────────
$recs = @()
if ($Measure -and $measureResult) {
    $mcpTotal = ($measureResult.details | Where-Object { $_.Component -like 'MCP*' } | Measure-Object Tokens -Sum).Sum
    $mcpPct = if ($measureResult.total -gt 0) { $mcpTotal / $measureResult.total * 100 } else { 0 }
    if ($mcpPct -gt 50) { $recs += "MCP tools dominate ($("{0:N0}" -f $mcpPct)%). Merge or disable unused servers." }
    $largest = $measureResult.details | Sort-Object Tokens -Descending | Select-Object -First 3
    $recs += "Top 3 optimization targets: $($largest[0].Component) ($("{0:N0}" -f $largest[0].Tokens) tok), $($largest[1].Component) ($("{0:N0}" -f $largest[1].Tokens) tok), $($largest[2].Component) ($("{0:N0}" -f $largest[2].Tokens) tok)"
}
if ($cacheHitRate -lt 0.4 -and $InputTokens -gt 0) {
    $recs += "Cache too low ($("{0:P1}" -f $cacheHitRate)). Structure prompt for reuse."
}
if ($InputTokens -gt 50000) {
    $recs += "CRITICAL: Input $("{0:N0}" -f $InputTokens) tok eats $("{0:N0}" -f $ctxPct)% of $("{0:N0}" -f $ContextWindow) context window."
}
if ($OutputTokens -eq 0) { $recs += "Add -OutputTokens for complete per-call picture (model response)." }
if ($Threshold -eq 0) { $recs += "Set -Threshold <tok> to guard against surprises in CI/scripts." }

# ─── Diff ─────────────────────────────────────────────────
$diffs = @()
if ($previous -and $measureResult) {
    $prevTotal = ($previous | Measure-Object Tokens -Sum).Sum
    $diffTok = $measureResult.total - $prevTotal
    $pct = if ($prevTotal -gt 0) { [math]::Round($diffTok / $prevTotal * 100, 1) } else { 0 }
    $arrow = if ($diffTok -ge 0) { "↑" } else { "↓" }
    $diffs += "Overall: $arrow $("{0:N0}" -f [math]::Abs($diffTok)) tok ($pct%)"
    $compMap = @{}; $previous | ForEach-Object { $compMap[$_.Component] = $_.Tokens }
    foreach ($d in $measureResult.details) {
        $old = if ($compMap.ContainsKey($d.Component)) { $compMap[$d.Component] } else { 0 }
        if ($old -ne $d.Tokens) {
            $dArrow = if ($d.Tokens -ge $old) { "↑" } else { "↓" }
            $diffs += "$($d.Component): $dArrow $("{0:N0}" -f [math]::Abs($d.Tokens - $old)) tok"
        }
    }
}

# ══════════════════════════════════════════════════════════
# DISPLAY
# ══════════════════════════════════════════════════════════
function Line { Write-Host ("─" * 60) -ForegroundColor DarkGray }

# ─── HEADER WITH RISK ─────────────────────────────────────
Line
Write-Host "  TOKEN AUDITOR  ●  RISK: $riskLabel" -ForegroundColor $riskColor
Line

# ─── FIRST CALL SHOCK ─────────────────────────────────────
if ($Calls -gt 1) {
    Write-Host "`n⚠️  FIRST CALL SHOCK" -ForegroundColor $riskColor
    Write-Host "  Opening this session costs you $("{0:N0}" -f $firstCallNew) tok before you type." -ForegroundColor $riskColor
    Write-Host "  That's $("{0:N0}" -f $ctxPct)% of your $("{0:N0}" -f $ContextWindow) context window." -ForegroundColor $riskColor
    Write-Host "  Each subsequent call costs only $("{0:N0}" -f $eachRepeatedNew) tok (cache kicks in)."
    Write-Host "  First call = $shockMultiplier× the cost of a repeated call." -ForegroundColor $riskColor
}

# ─── BREAKDOWN ────────────────────────────────────────────
Write-Host "`n📊 TOKEN BREAKDOWN (per call)" -ForegroundColor Yellow
Write-Host ("  {0,-30} {1,12}" -f "Input Sent", ("{0:N0}" -f $InputTokens))
Write-Host ("  {0,-30} {1,12}" -f "  ↳ Cache Hit (reused)", ("{0:N0}" -f $CachedInputTokens))
Write-Host ("  {0,-30} {1,12}" -f "  ↳ Cache Miss (fresh)", ("{0:N0}" -f $cacheMissTokens))
if ($OutputTokens -gt 0) {
    Write-Host ("  {0,-30} {1,12}" -f "Output Received", ("{0:N0}" -f $OutputTokens))
}
Write-Host ("  {0,-30} {1,12}" -f "Total Sent/Received", ("{0:N0}" -f $totalSentPerCall)) -ForegroundColor Cyan
Write-Host ("  {0,-30} {1,12}" -f "Context Window Used", "$("{0:N0}" -f $ctxPct)%")

# ─── CACHE ────────────────────────────────────────────────
Write-Host "`n📈 CACHE EFFICIENCY" -ForegroundColor Yellow
Write-Host ("  {0,-33} {1,12:P1}" -f "Cache Hit Rate", $cacheHitRate)
Write-Host ("  {0,-33} {1,12:P1}" -f "Cache Miss Rate", $cacheMissRate)
Write-Host ("  {0,-33} {1,12:N0}" -f "Reused per Call", $CachedInputTokens)

# ─── CUMULATIVE ───────────────────────────────────────────
if ($Calls -gt 1) {
    Write-Host "`n🔄 CUMULATIVE ($Calls calls)" -ForegroundColor Yellow
    Write-Host ("  {0,-35} {1,14:N0}" -f "Total Sent (all calls)", $rawCumulative) -ForegroundColor Cyan
    Write-Host ("  {0,-35} {1,14:N0}" -f "Total Processed (fresh only)", $effectiveCumulative)
    Write-Host ("  {0,-35} {1,14:N0}" -f "Cache Saved (not reprocessed)", ($CachedInputTokens * ($Calls - 1))) -ForegroundColor Green
    Write-Host ("  {0,-35} {1,14:N0}" -f "First Call (fresh)", $firstCallNew)
    Write-Host ("  {0,-35} {1,14:N0}" -f "Each Repeated (fresh only)", $eachRepeatedNew)
}

# ─── PROJECTIONS ──────────────────────────────────────────
Write-Host "`n📅 PROJECTIONS (total sent)" -ForegroundColor Yellow
Write-Host ("  {0,-35} {1,14:N0}" -f "Per Call", $totalSentPerCall)
Write-Host ("  {0,-35} {1,14:N0}" -f "Per Session ($CallsPerSession calls)", $perSession)
Write-Host ("  {0,-35} {1,14:N0}" -f "Per Day ($SessionsPerDay sessions)", $perDay)

# ─── RECOMMENDATIONS ──────────────────────────────────────
if ($recs.Count -gt 0) {
    Write-Host "`n💡 RECOMMENDATIONS" -ForegroundColor Green
    foreach ($r in $recs) { Write-Host "  • $r" }
}

# ─── DIFF ─────────────────────────────────────────────────
if ($diffs.Count -gt 0) {
    Write-Host "`n📉 DIFF vs BASELINE" -ForegroundColor Cyan
    foreach ($d in $diffs) { Write-Host "  • $d" }
}

Line
Write-Host "  Token counts are approximate. Use exact tokenizer for billing." -ForegroundColor DarkGray
Write-Host
