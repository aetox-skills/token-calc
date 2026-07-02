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

## Real-world Example: OpenCode Steward (post-optimization)

A reference for what a well-optimized system prompt looks like after trimming instructions, disabling unused MCPs, compressing tool output (RTK), and capping history (history-trimmer).

**Per-call breakdown (input):**

| Component | Tokens | Note |
|:--|:--:|:--|
| Instructions (3 files) | ~3,200 | CONTEXT.md + PROFILE.md + index.md |
| Agent identity (steward) | ~2,000 | AGENTS.md emptied |
| Available skills (7) | ~300 | Name + short description only |
| MCP tool defs (4 servers) | ~5,000–10,000 | Obsidian (+14 tools) + Exa + Context7 + ST |
| OpenCode built-in (tools, system) | ~4,000 | Read/Write/Bash/Grep tools + permissions |
| History (6 messages, capped) | ~2,000–5,000 | history-trimmer plugin keeps it flat |
| **~Total input per call** | **~18,000–24,000** | |
| Output (model response) | ~2,000 | varies |

**Cache efficiency:**

| Metric | Value |
|:--|:--|
| Cache hit rate | ~77% |
| Cached per call (system + history overlap) | ~17,000 tok |
| Fresh per call (user message + new history) | ~5,000 tok |
| Effective price (DeepSeek V4 Flash) | ~$0.103/M |

**Cost projection (DeepSeek V4 Flash: $0.435/M miss, $0.0036/M hit):**

| Calls | Processed (pay) | Cost |
|:--:|:--:|:--:|
| 1 (cold) | 24,000 tok | ~$0.010 |
| 10 | 87,000 tok | ~$0.038 |
| 20 | 157,000 tok | ~$0.068 |
| 30 (session) | 227,000 tok | ~$0.099 |
| Month (30 sessions) | 6.81M tok | ~$2.97 |
| Year | 81.7M tok | ~$35.6 |

**Key insight:** Cache hit pricing ($0.0036/M) is 120× cheaper than miss ($0.435/M). Once the session starts, the system prompt is fully cached — each subsequent call only pays for the user message, new history deltas, and output.
