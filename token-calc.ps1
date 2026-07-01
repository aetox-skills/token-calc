<#
.SYNOPSIS
  Token savings calculator — measure system prompt, estimate savings with compounding multipliers.

.DESCRIPTION
  Measures current instruction/agent/skill files, estimates token sizes,
  and projects savings with compounding across calls/sessions/months/agents/cache.

.PARAMETER Mode
  'solo' (default) | 'team' — how many agents in parallel

.PARAMETER Tier
  'free' (default) | 'paid' — model pricing tier

.PARAMETER CacheHit
  Cache hit rate 0.0-0.95 (default 0.0 for free, 0.7 for paid)

.PARAMETER Baseline
  Baseline system prompt size in tokens before any optimization (default 55000)

.EXAMPLE
  .\token-calc.ps1
  .\token-calc.ps1 -Mode team -Tier paid -CacheHit 0.7
  .\token-calc.ps1 -Mode team -Tier paid -CacheHit 0.7 -Baseline 60000
#>

param(
    [ValidateSet('solo','team')][string]$Mode = 'solo',
    [ValidateSet('free','paid')][string]$Tier = 'free',
    [double]$CacheHit = $(if ($Tier -eq 'paid') {0.7} else {0.0}),
    [int]$Baseline = 55000
)

# ─── Pricing ──────────────────────────────────────────────
$priceMiss  = 0.435  # $/M tokens cache miss
$priceHit   = 0.0036 # $/M tokens cache hit
$callsPerSession = 30
$sessionsPerMonth = 30

# ─── Measure current system prompt ────────────────────────
$instructionFiles = @(
    'C:\Users\Gigabyte\CONTEXT.md',
    'C:\Users\Gigabyte\PROFILE.md',
    'C:\Users\Gigabyte\AGENTS.md',
    'E:\MikeData\opencode_data\index.md'
)

$agentDir = 'C:\Users\Gigabyte\.config\opencode\agents'
$skillDir = 'C:\Users\Gigabyte\.config\opencode\skills'

$totalTokens = 0
$details = @()

Write-Host "`n══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " TOKEN SAVINGS CALCULATOR" -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════════════" -ForegroundColor Cyan

# Instructions
foreach ($f in $instructionFiles) {
    if (Test-Path $f) {
        $c = Get-Content -Raw $f
        # Count non-English chars for better estimate
        $thai   = [regex]::Matches($c, '[\u0E00-\u0E7F]').Count
        $chinese= [regex]::Matches($c, '[\u4E00-\u9FFF]').Count
        $engLen = $c.Length - $thai - $chinese
        $tok    = [math]::Ceiling($engLen/4 + $thai/3 + $chinese/3)
        $totalTokens += $tok
        $details += [PSCustomObject]@{Component = $f.Split('\')[-1]; Tokens = $tok; Type = 'instruction'}
    }
}

# Agents (frontmatter description only — full body loaded on demand)
if (Test-Path $agentDir) {
    foreach ($af in (Get-ChildItem "$agentDir\*.md")) {
        $c = Get-Content -Raw $af.FullName
        # Only count frontmatter description line + name (always in context)
        if ($c -match "description:\s*['""]?([^'""\n]+)") {
            $desc = $Matches[1]
            $tok  = [math]::Ceiling($desc.Length/4) + [math]::Ceiling($af.BaseName.Length/4)
            $totalTokens += $tok
            $details += [PSCustomObject]@{Component = "$($af.BaseName) (desc)"; Tokens = $tok; Type = 'agent'}
        }
    }
}

# Skills (description only — full content loaded on demand)
if (Test-Path $skillDir) {
    foreach ($sd in (Get-ChildItem $skillDir -Directory)) {
        $sf = Join-Path $sd.FullName 'SKILL.md'
        if (Test-Path $sf) {
            $c = Get-Content -Raw $sf
            if ($c -match "description:\s*['""]?([^'""\n]+)") {
                $desc = $Matches[1]
                $tok  = [math]::Ceiling($desc.Length/4) + [math]::Ceiling($sd.Name.Length/4) + 30 # XML wrapper
                $totalTokens += $tok
                $details += [PSCustomObject]@{Component = "$($sd.Name) (desc)"; Tokens = $tok; Type = 'skill'}
            }
        }
    }
}

# MCP tool definitions (estimate ~3K per MCP server)
$mcpCount = 4
$mcpTokens = $mcpCount * 3000
$totalTokens += $mcpTokens
$details += [PSCustomObject]@{Component = "MCP tools x$mcpCount"; Tokens = $mcpTokens; Type = 'mcp'}

# OpenCode system overhead (tools, permissions, metadata ~2K)
$overhead = 2000
$totalTokens += $overhead
$details += [PSCustomObject]@{Component = 'OpenCode overhead'; Tokens = $overhead; Type = 'system'}

# ─── Calculations ─────────────────────────────────────────
$savedPerCall = [math]::Max(0, $Baseline - $totalTokens)
$agentMultiplier = if ($Mode -eq 'team') {3} else {1}

$effectivePrice = ($priceMiss * (1 - $CacheHit)) + ($priceHit * $CacheHit)

$perSession     = $totalTokens * $callsPerSession * $agentMultiplier
$perMonth       = $perSession * $sessionsPerMonth
$perYear        = $perMonth * 12

$savedPerSession= $savedPerCall * $callsPerSession * $agentMultiplier
$savedPerMonth  = $savedPerSession * $sessionsPerMonth
$savedPerYear   = $savedPerMonth * 12

# Cost = tokens × calls × agents × price / 1,000,000 (price is per M tokens)
$costBaselineSession = $Baseline * $callsPerSession * $agentMultiplier * $priceMiss / 1e6
$costCurrentSession  = $totalTokens * $callsPerSession * $agentMultiplier * $effectivePrice / 1e6
$costBaselineMonth   = $costBaselineSession * $sessionsPerMonth
$costCurrentMonth    = $costCurrentSession * $sessionsPerMonth
$costBaselineYear    = $costBaselineMonth * 12
$costCurrentYear     = $costCurrentMonth * 12

# ─── Display ──────────────────────────────────────────────
Write-Host "`n📐 CURRENT MEASUREMENT" -ForegroundColor Yellow
Write-Host "──────────────────────────────"
$details | Sort-Object Tokens -Descending | ForEach-Object { 
    $tok = if ($_.Tokens -match '\.') { [int][math]::Round([double]$_.Tokens) } else { [int]$_.Tokens }
    Write-Host ("  " + $_.Component.PadRight(40) + $tok.ToString().PadLeft(8))
}

Write-Host ("  TOTAL system prompt".PadRight(50) + "$totalTokens tok".PadLeft(8)) -ForegroundColor Cyan

Write-Host "`n⚙️  MODE: $Mode  |  TIER: $Tier  |  CACHE HIT: $($CacheHit * 100)%" -ForegroundColor Yellow
Write-Host "──────────────────────────────────────────────────────────"

$savedPct = if ($Baseline -gt 0) { "{0:P0}" -f ($savedPerCall/$Baseline) } else { "0%" }
Write-Host "`n📊 SAVINGS (vs ${Baseline}K baseline)" -ForegroundColor Green
Write-Host "──────────────────────────────"
Write-Host "  Per call".PadRight(35) + "${savedPerCall} tok ($savedPct)".PadLeft(20)
Write-Host "  Per session ($callsPerSession calls)".PadRight(35) + "${savedPerSession} tok".PadLeft(20)
Write-Host "  Per month".PadRight(35) + "${savedPerMonth} tok".PadLeft(20)
Write-Host "  Per year".PadRight(35) + "${savedPerYear} tok".PadLeft(20)

$annualSaved = $costBaselineYear - $costCurrentYear
$annualSavedColor = if ($annualSaved -gt 100) {'Green'} elseif ($annualSaved -gt 10) {'Yellow'} else {'Gray'}

Write-Host "`n💰 COST PROJECTION (annual)" -ForegroundColor Magenta
Write-Host "──────────────────────────────"
Write-Host "  Without optimization (100% miss)".PadRight(50) + ("`$$($costBaselineYear.ToString('N2'))").PadLeft(12)
Write-Host ("  Current (`$$effectivePrice`/M effective)").PadRight(50) + ("`$$($costCurrentYear.ToString('N2'))").PadLeft(12)
Write-Host "  ANNUAL SAVINGS".PadRight(50) + ("`$$($annualSaved.ToString('N2'))").PadLeft(12) -ForegroundColor $annualSavedColor

Write-Host "`n🔄 COMPOUNDING VISUAL" -ForegroundColor Cyan
Write-Host "──────────────────────────────"
Write-Host "  1 call".PadRight(45) + "${savedPerCall} tok".PadLeft(12)
Write-Host "  1 session ($callsPerSession calls)".PadRight(45) + "${savedPerSession} tok".PadLeft(12)
Write-Host "  1 month ($sessionsPerMonth sessions)".PadRight(45) + "${savedPerMonth} tok".PadLeft(12)
Write-Host "  1 year (12 months)".PadRight(45) + "${savedPerYear} tok".PadLeft(12)

if ($Mode -eq 'team') {
    $teamYear = $savedPerYear * 3
    Write-Host "  1 year x 3 agents (team)".PadRight(45) + "${teamYear} tok".PadLeft(12) -ForegroundColor DarkCyan
}
if ($CacheHit -gt 0) {
    $effectiveMult = [math]::Round($priceMiss / $effectivePrice, 1)
    $cacheYear = [long]($savedPerYear * $priceMiss / $effectivePrice)
    Write-Host ("  With $($CacheHit*100)% cache hit").PadRight(45) + "${cacheYear} tok".PadLeft(12) -ForegroundColor DarkCyan
}

Write-Host "`n══════════════════════════════════════════════════" -ForegroundColor Cyan
