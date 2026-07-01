<#
.SYNOPSIS
  Token Auditor — measure system prompt, breakdown cache hit/miss, project cumulative tokens.

.DESCRIPTION
  Shows how many tokens every call consumes, how much cache can save,
  and what that adds up to over sessions, days, months, and years.
  Token-only — no pricing, no model, no money.

.PARAMETER InputTokens
  Total input tokens per call (manual mode).

.PARAMETER CachedInputTokens
  How many of those input tokens hit cache (manual mode).

.PARAMETER OutputTokens
  Estimated output tokens per call (optional, default 0).

.PARAMETER Measure
  Auto-detect OpenCode system prompt from config files.

.PARAMETER Calls
  Number of calls to project (default 1).

.PARAMETER CallsPerSession
  Calls in one session (default 10).

.PARAMETER SessionsPerDay
  Sessions per day (default 3).

.PARAMETER Days
  Days to project (default 1).

.EXAMPLE
  # Auto-measure + project a year
  .\token-calc.ps1 -Measure -Calls 100 -CallsPerSession 20 -SessionsPerDay 5 -Days 365

  # Manual
  .\token-calc.ps1 -InputTokens 50000 -CachedInputTokens 35000 -OutputTokens 2000 -Calls 100
#>

param(
    [long]$InputTokens = 0,
    [long]$CachedInputTokens = 0,
    [long]$OutputTokens = 0,
    [switch]$Measure,
    [long]$Calls = 1,
    [long]$CallsPerSession = 10,
    [long]$SessionsPerDay = 3
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

    $total = 0
    $details = @()

    # Instruction files
    foreach ($f in $files) {
        if (Test-Path $f) {
            $c = Get-Content -Raw $f
            $thai    = [regex]::Matches($c, '[\u0E00-\u0E7F]').Count
            $chinese = [regex]::Matches($c, '[\u4E00-\u9FFF]').Count
            $engLen  = $c.Length - $thai - $chinese
            $tok     = [math]::Ceiling($engLen/4 + $thai/3 + $chinese/3)
            $total += $tok
            $details += [PSCustomObject]@{Component = $f.Split('\')[-1]; Tokens = $tok}
        }
    }

    # Agents
    if (Test-Path $agentDir) {
        foreach ($af in (Get-ChildItem "$agentDir\*.md")) {
            $c = Get-Content -Raw $af.FullName
            if ($c -match "description:\s*['""]?([^'""\n]+)") {
                $desc = $Matches[1]
                $tok  = [math]::Ceiling($desc.Length/4) + [math]::Ceiling($af.BaseName.Length/4)
                $total += $tok
                $details += [PSCustomObject]@{Component = "$($af.BaseName) (agent)"; Tokens = $tok}
            }
        }
    }

    # Skills
    if (Test-Path $skillDir) {
        foreach ($sd in (Get-ChildItem $skillDir -Directory)) {
            $sf = Join-Path $sd.FullName 'SKILL.md'
            if (Test-Path $sf) {
                $c = Get-Content -Raw $sf
                if ($c -match "description:\s*['""]?([^'""\n]+)") {
                    $desc = $Matches[1]
                    $tok  = [math]::Ceiling($desc.Length/4) + [math]::Ceiling($sd.Name.Length/4) + 30
                    $total += $tok
                    $details += [PSCustomObject]@{Component = "$($sd.Name) (skill)"; Tokens = $tok}
                }
            }
        }
    }

    # MCP tools
    $mcpCount = 4
    $mcpTok   = $mcpCount * 3000
    $total   += $mcpTok
    $details += [PSCustomObject]@{Component = "MCP tools x$mcpCount"; Tokens = $mcpTok}

    # Overhead
    $overhead = 2000
    $total   += $overhead
    $details += [PSCustomObject]@{Component = 'OpenCode overhead'; Tokens = $overhead}

    return @{ total = $total; details = $details }
}

# ─── Auto-measure ─────────────────────────────────────────
if ($Measure) {
    Write-Host "`n📏 Measuring system prompt..." -ForegroundColor Cyan
    $m = Measure-SystemPrompt
    $InputTokens = $m.total
    if ($CachedInputTokens -eq 0) { $CachedInputTokens = [long][math]::Round($m.total * 0.3) }

    # Show breakdown
    $m.details | Sort-Object Tokens -Descending | ForEach-Object {
        Write-Host ("  {0,-40} {1,8:N0}" -f $_.Component, $_.Tokens)
    }
    Write-Host ("  " + "TOTAL system prompt".PadRight(44) + "$("{0:N0}" -f $m.total) tok" ) -ForegroundColor Cyan
}

# ─── Validate ─────────────────────────────────────────────
if ($InputTokens -le 0 -and $OutputTokens -le 0) {
    Write-Error "Need at least some tokens. Use -Measure or -InputTokens."
    exit 1
}

# ─── Token breakdown ──────────────────────────────────────
$cacheMissTokens = [math]::Max(0, $InputTokens - $CachedInputTokens)
$totalSentPerCall = $InputTokens + $OutputTokens

$cacheHitRate  = if ($InputTokens -gt 0) { $CachedInputTokens / $InputTokens } else { 0 }
$cacheMissRate = 1 - $cacheHitRate

# ─── Cumulative projections ───────────────────────────────
# Raw: every call sends full input + output
$rawCumulative     = $totalSentPerCall * $Calls

# Effective: cache means each repeated call only "processes" new input + output
$firstCallNew      = $totalSentPerCall                               # first call processes everything
$eachRepeatedNew   = $cacheMissTokens + $OutputTokens                # repeated calls process only fresh content
$effectiveCumulative = $firstCallNew + ($eachRepeatedNew * ($Calls - 1))

# ─── Session/day on raw total ─────────────────────────────
$perSession    = $totalSentPerCall * $CallsPerSession
$perDay        = $perSession * $SessionsPerDay

# ─── Display ──────────────────────────────────────────────
function Line { Write-Host ("─" * 60) -ForegroundColor DarkGray }

Line
Write-Host "  TOKEN AUDITOR" -ForegroundColor Cyan
Line

Write-Host "`n📊 TOKEN BREAKDOWN (per call)" -ForegroundColor Yellow
Write-Host ("  {0,-30} {1,12}" -f "Input Sent", ("{0:N0}" -f $InputTokens))
Write-Host ("  {0,-30} {1,12}" -f "  ↳ Cache Hit (reused)", ("{0:N0}" -f $CachedInputTokens))
Write-Host ("  {0,-30} {1,12}" -f "  ↳ Cache Miss (fresh)", ("{0:N0}" -f $cacheMissTokens))
if ($OutputTokens -gt 0) {
    Write-Host ("  {0,-30} {1,12}" -f "Output Received", ("{0:N0}" -f $OutputTokens))
}
Write-Host ("  {0,-30} {1,12}" -f "Total Sent/Received", ("{0:N0}" -f $totalSentPerCall)) -ForegroundColor Cyan

Write-Host "`n📈 CACHE EFFICIENCY" -ForegroundColor Yellow
Write-Host ("  {0,-30} {1,12:P1}" -f "Cache Hit Rate", $cacheHitRate)
Write-Host ("  {0,-30} {1,12:P1}" -f "Cache Miss Rate", $cacheMissRate)
Write-Host ("  {0,-30} {1,12:N0}" -f "Reused per Call (no reprocess)", $CachedInputTokens)

if ($Calls -gt 1) {
    Write-Host "`n🔄 CUMULATIVE ($Calls calls)" -ForegroundColor Yellow
    Write-Host ("  {0,-30} {1,12:N0}" -f "First Call (all fresh)", $firstCallNew)
    Write-Host ("  {0,-30} {1,12:N0}" -f "Each Repeated (fresh only)", $eachRepeatedNew)
    Write-Host ("  {0,-30} {1,12:N0}" -f "Cache Saved (not reprocessed)", ($CachedInputTokens * ($Calls - 1)))
    Write-Host ("  {0,-30} {1,12:N0}" -f "Total Sent (all calls)", $rawCumulative)
    Write-Host ("  {0,-30} {1,12:N0}" -f "Total Processed (fresh)", $effectiveCumulative) -ForegroundColor Cyan
}

Write-Host "`n📅 PROJECTIONS (total sent)" -ForegroundColor Yellow
Write-Host ("  {0,-33} {1,12:N0}" -f "Per Call", $totalSentPerCall)
Write-Host ("  {0,-33} {1,12:N0}" -f "Per Session ($CallsPerSession calls)", $perSession)
Write-Host ("  {0,-33} {1,12:N0}" -f "Per Day ($SessionsPerDay sessions)", $perDay)


Line
Write-Host "  Token counts are approximate. Use exact tokenizer for billing." -ForegroundColor DarkGray
Write-Host
