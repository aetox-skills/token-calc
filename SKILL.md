---
name: token-calc
description: Token Auditor — inspect system prompt, first call shock warning, cache breakdown, cumulative projections, threshold guard. Prevents surprise AI costs.
---

# Token Auditor

**AI can't measure itself.** This script exists because system prompt silently eats tokens before you type anything.

## Core Value

- **FIRST CALL SHOCK** — "เปิดมา 60K หายไปแล้ว" (visual warning)
- **Risk level** — GREEN / CAUTION / HIGH based on input size
- **Threshold guard** — `-Threshold 50000` exits with error if exceeded
- **Breakdown** — what's eating your prompt (MCP? skills? files?)
- **Projections** — per call → session → day

## CLI

```powershell
# See the shock + risk + breakdown
.\token-calc.ps1 -InputTokens 60000 -CachedInputTokens 52000 -OutputTokens 4000 -Calls 100 -CallsPerSession 20 -SessionsPerDay 5

# Guard mode: fail if system prompt > 50K
.\token-calc.ps1 -Measure -Threshold 50000

# Auto-measure your current OpenCode setup
.\token-calc.ps1 -Measure -Calls 100

# Track changes
.\token-calc.ps1 -Measure -Save baseline.json
.\token-calc.ps1 -Measure -Diff baseline.json
```

## Why use this (not AI itself)

| AI doing it | Script does it |
|:--|:--|
| Reads files one by one, estimates crudely | One-shot, consistent heuristic |
| Can't see its own bias | External measurement |
| No "warning" mode | Risk level + threshold guard |
| Forgets previous measurements | -Save / -Diff tracking |
