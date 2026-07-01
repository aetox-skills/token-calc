---
name: token-calc
description: Token savings calculator — measure system prompt, project savings with compounding multipliers (calls/sessions/months/agents/cache). Use when asked to calculate token costs.
---

# Token Savings Calculator

> Load when asked: "calculate token savings" / "project costs" / "compare scenarios"

## Rules
- Measure first. Use formula, not guess.
- Report: tok (per call/session/month/year) + USD annual.
- No baseline given → default 55,000 tok.

## Formula

```
C=30 (calls/session), S=30 (sessions/month), A=agentCount
ep = missP×(1-cacheHit) + hitP×cacheHit   (effective price)
saved/call = baseline - current
saved/session = saved/call × C × A
saved/year = saved/session × S × 12
costNoOpt/year = baseline × C × S × 12 × A × missP / 1e6
costOpt/year  = current × C × S × 12 × A × ep / 1e6
savings/year = costNoOpt - costOpt
```

## Constants

| Constant | Value |
|:--|:--|
| `callsPerSession` | 30 |
| `sessionsPerMonth` | 30 |
| `missPrice` (V4 Pro) | $0.435/M tok |
| `hitPrice` (V4 Pro) | $0.0036/M tok |
| `defaultBaseline` | 55,000 tok |

## Measuring

```
total = sum(CONTEXT.md + PROFILE.md + index.md + AGENTS.md)
      + sum(agent name + desc) + sum(skill name + desc + ~30)
      + MCPcount × 3000 + 2000 (overhead)
Token/file = ⌈english/4 + thai/3 + chinese/3⌉
```

## Cache factor
Hit $0.0036/M vs miss $0.435/M = 120× diff.
At 70% hit → effective $0.133/M = 3.3× cheaper.

## Parameters
| Param | Options | Default |
|:--|:--|:--|
| `mode` | `solo`/`team` | `solo` |
| `tier` | `free`/`paid` | `free` |
| `cacheHit` | 0.0–0.95 | 0 (free) / 0.7 (paid) |
| `baseline` | custom tok | 55,000 |

## Script
```powershell
C:\Users\Gigabyte\scripts\token-calc.ps1 -Mode team -Tier paid -CacheHit 0.7
```
