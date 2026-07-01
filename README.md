# Token Savings Calculator

Measure system prompt size, project cost savings with compounding multipliers.

## Quick Start

Load `SKILL.md` as an AI skill. The skill teaches any agent the formula directly — no external dependencies.

```powershell
# Or run the measurement script (Windows):
.\token-calc.ps1
.\token-calc.ps1 -Mode team -Tier paid -CacheHit 0.7
```

## Files

| File | Purpose |
|:--|:--|
| `SKILL.md` | AI agent skill — self-contained formula + constants |
| `token-calc.ps1` | PowerShell script for automated measurement |

## Compatibility

- OpenCode — auto-discover from `.config/opencode/skills/`
- ZCode — import from skill-library path
- Codex / Claude / Gemini CLI — read SKILL.md directly
- Any AI agent — formula is in the skill, no platform lock-in

## Formula (brief)

```
saved/call = baseline - current
saved/year = saved/call × 30 × 30 × 12 × agentCount
costNoOpt  = baseline × 30 × 30 × 12 × A × $0.435/M
costOpt    = current  × 30 × 30 × 12 × A × effectivePrice/M
```

See [SKILL.md](SKILL.md) for full constants and cache compounding.
