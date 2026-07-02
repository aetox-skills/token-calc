---
name: token-calc
description: Token Auditor — cost control for self-hosted API users. Multi-platform: OpenCode, ZCode, Claude Code. Project processing costs, guard against surprises.
---

# Token Auditor

**AI reads output in English, then explains to user in their language.**

## CLI

```powershell
# Auto-detect any AI coding tool + full projection
.\token-calc.ps1 -Measure -Calls 100 -OutputTokens 2000

# Target specific platform
.\token-calc.ps1 -Measure -Platform opencode
.\token-calc.ps1 -Measure -Platform zcode
.\token-calc.ps1 -Measure -Platform claude

# Custom projection milestones
.\token-calc.ps1 -InputTokens 60000 -CachedInputTokens 52000 -Calls 200 -Milestones "1,5,25,50,100,200"

# Guard mode
.\token-calc.ps1 -Measure -Threshold 50000

# Track changes
.\token-calc.ps1 -Measure -Save baseline.json
.\token-calc.ps1 -Measure -Diff baseline.json

# Manual
.\token-calc.ps1 -InputTokens 60000 -CachedInputTokens 52000 -OutputTokens 4000
```

## New params

| Param | Default | Description |
|:--|:--|:--|
| `-Platform` | auto | opencode / zcode / claude |
| `-Milestones` | 1,10,20,50,100 | Custom projection steps |

## AI Workflow

1. Run the script
2. Read output sections: FIRST CALL SHOCK → BREAKDOWN → CACHE → PROCESSING PROJECTOR → RECOMMENDATIONS
3. Explain key findings in user's language
4. Keep technical terms in English (token, cache hit/miss, MCP, threshold)

### Translation examples

| English | User's language |
|:--|:--|
| "First call costs you 64K tok" | "แค่เปิด session คุณเสีย 64K tokens แล้ว" |
| "MCP tools dominate 73%" | "MCP tools กิน 73% ของ prompt — รวมหรือปิด unused servers" |
| "Cache hit rate 30%" | "Cache reuse แค่ 30% — ลองจัดโครงสร้าง prompt ให้ stable ขึ้น" |
| "At 100 calls, 1.25M processed" | "100 call = ประมวลผลจริง 1.25M tokens" |

## Optimization Strategy

If your measurement shows a large system prompt (>30K tok), here are proven ways to shrink it:

| If the problem is… | Try this | Expected savings |
|:--|:--|:--|
| History grows every call | **Cap history** — use a plugin that trims conversation to the last N messages before each API request. [opencode-history-trimmer](https://github.com/aetox-skills/opencode-history-trimmer) does this for OpenCode. | ~2–5K tok/call (and stays flat) |
| Bash tool output is verbose | **Filter command output** — a CLI proxy that intercepts bash commands and strips noise (progress bars, install logs, passed test lines). [token-saver (RTK)](https://github.com/aetox-skills/token-saver) saves 55–90% on git, test, install, find. | ~500–3000 tok/call per bash command |
| Instruction files are bloated | **Trim to essentials** — remove redundant descriptions, translate non-English instructions, cut finished-task history. | ~5–15K tok |
| MCP servers you don't use | **Disable or comment out** — each MCP injects tool schemas. Keep only what the current workflow needs. | ~2–4K tok/server |
| Too many skills registered | **Remove unused skills** — each skill adds name + description to `available_skills`. Keep what the agent actually loads. | ~300–500 tok/skill |

---

## Example: What Optimization Looks Like

Below is a real measurement from an OpenCode setup that applied all of the above: trimmed instructions, disabled unused MCPs, compressed bash output, and capped history at 6 messages.

**Per-call breakdown (input):**

| Component | Tokens | Note |
|:--|:--:|:--|
| Instructions | ~3,200 | Kept essential files only |
| Agent identity | ~2,000 | Removed redundant AGENTS.md |
| Available skills | ~300 | Short descriptions only |
| MCP tool definitions | ~5,000–10,000 | 4 servers (Obsidian heaviest at +14 tools) |
| Built-in tool defs + overhead | ~4,000 | Every ADE has this — unavoidable |
| History (capped) | ~2,000–5,000 | Plugin keeps it at N messages |
| **~Total input per call** | **~18,000–24,000** | |
| Output | ~2,000 | varies by query |

**Cache efficiency on DeepSeek V4 Flash ($0.435/M miss, $0.0036/M hit):**

| Metric | Value |
|:--|:--|
| Cache hit rate | ~77% |
| Cached per call | ~17,000 tok |
| Fresh per call | ~5,000 tok |
| Effective price | ~$0.103/M |

**Cost projection:**

| Calls | Processed (pay) | Cost |
|:--:|:--:|:--:|
| 1 (cold) | 24,000 tok | ~$0.010 |
| 10 | 87,000 tok | ~$0.038 |
| 20 | 157,000 tok | ~$0.068 |
| 30 (session) | 227,000 tok | ~$0.099 |
| Month (30 sessions) | 6.81M tok | ~$2.97 |
| Year | 81.7M tok | ~$35.6 |

**Key insight:** Cache hit pricing (120× cheaper) means once the session starts, you only pay for fresh input — everything else is reused. The biggest wins come from keeping your prompt lean and your history capped.
