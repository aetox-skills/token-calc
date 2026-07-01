# Token Auditor

**Multi-platform cost control for self-hosted AI API users.**

Auto-detect: **OpenCode** · **ZCode** · **Claude Code** (or manual mode).

---

## Quick Start

```powershell
# Auto-detect + full projection
.\token-calc.ps1 -Measure -Calls 100 -OutputTokens 2000

# Or manual
.\token-calc.ps1 -InputTokens 60000 -CachedInputTokens 52000 -OutputTokens 4000 -Calls 100
```

## What You Get

| Section | What it tells you |
|:--|:--|
| **⚠️ FIRST CALL SHOCK** | Tokens lost before you type anything |
| **📊 TOKEN BREAKDOWN** | Input = cache hit + cache miss, + output |
| **📈 CACHE EFFICIENCY** | Hit rate, miss rate, tokens saved |
| **🔄 PROCESSING PROJECTOR** | Table: 1 → 10 → 20 → 50 → 100 calls |
| **💡 RECOMMENDATIONS** | What to optimize (by platform) |
| **🚨 Threshold Guard** | `-Threshold 50000` fails early (exit 2) |

## New in v2

| Feature | What |
|:--|:--|
| **Multi-platform** | Auto-detects OpenCode, ZCode, Claude Code |
| **`-Platform`** | Filter: `opencode`, `zcode`, `claude` |
| **`-Milestones`** | Custom projection steps: `"1,5,25,100,500"` |
| **`-ContextWindow`** | Set model context window (default 200K) |

## Parameters

| Param | Default | Description |
|:--|:--|:--|
| `-InputTokens` | 0 | Total input tokens per call |
| `-CachedInputTokens` | 0 | Cache hit portion |
| `-OutputTokens` | 0 | Output tokens |
| `-Measure` | off | Auto-detect system prompt |
| `-Platform` | auto | `opencode` / `zcode` / `claude` |
| `-Calls` | 1 | Number of calls to project |
| `-CallsPerSession` | 10 | Calls per session |
| `-SessionsPerDay` | 3 | Sessions per day |
| `-Milestones` | 1,10,20,50,100 | Projection table steps |
| `-Threshold` | 0 | Exit with error if exceeded |
| `-ContextWindow` | 200000 | Model context window size |
| `-Save` | '' | Save baseline JSON |
| `-Diff` | '' | Compare vs baseline JSON |

## Use Cases

- **Know your burn rate**: "100 calls = 1.25M processed, not 6.4M sent"
- **Plan before adding**: "Adding MCP server costs 3K tok/call"
- **CI guard**: "Deploy fails if system prompt > 50K"
- **Track drift**: Compare baseline across config changes
- **Multi-tool**: Compare OpenCode vs ZCode prompt sizes

## Philosophy

**Token-only.** No pricing, no model, no money. We measure tokens — you handle costs. That keeps this tool maintainable without tracking ever-changing provider prices.

## License

MIT
