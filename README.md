# Token Auditor

**Measure your system prompt. Identify waste. Get prescriptions.**

Your API calls cost more than they should. You just don't know how much — yet.

Every AI coding tool sends a system prompt with every call. Add an MCP server? Permanent +3K tok. Chat for 20 messages? History eats 100K+. Cache is 120× cheaper than a miss, but most people never check their hit rate.

We fix that. **Measure → Diagnose → Prescribe.** Platform-agnostic: OpenCode, ZCode, Claude Code, Codex, Cursor — any ADE that calls an API.

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

## Optimization Guide

> Read this after you've measured. Don't guess what to fix — let the numbers tell you.

See [SKILL.md](SKILL.md) → **Optimization Strategy** for a full table of problems → solutions, cross-platform. Cap history, filter command output, trim MCPs, slim instructions — all with expected token savings. Includes a processed-token projection: ~22K tok/call at ~77% cache hit (6.8M tok/month vs 21.6M sent).

**Prescriptions link to tools that fix each problem:** [opencode-history-trimmer](https://github.com/aetox-skills/opencode-history-trimmer) for history bloat, [token-saver (RTK)](https://github.com/aetox-skills/token-saver) for noisy command output.

## Philosophy

**Tokens only.** We measure what leaves your machine — cache hit, cache miss, output, processed totals. No pricing, no model, no money. Prices change, models change, but token waste is universal.

> Have a pricing lookup skill installed? Use it alongside this one to convert tokens to dollars. Don't have one? The token counts are all you need to optimize — cutting waste saves money regardless of what you pay per token.

## License

MIT
