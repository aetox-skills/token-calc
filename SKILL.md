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

Every AI coding tool sends the same categories of tokens. The tools differ, but the levers are the same. Here's how to shrink each layer — regardless of which ADE you use (OpenCode, Claude Code, Codex, Cursor, ZCode, Gemini CLI).

| Layer | Problem | Solution | Works on | Expected savings |
|:--|:--|:--|:--|:--:|
| **Conversation history** | Grows every call, most of it irrelevant | **Cap at N messages.** OpenCode: [opencode-history-trimmer](https://github.com/aetox-skills/opencode-history-trimmer) plugin. Claude Code: use `compact` or `/compact`. Codex: lower `message_limit` in config. Other ADEs: apply the same principle — keep last few exchanges. | All ADEs | ~2–5K/call (stays flat) |
| **Command/tool output** | Noise from progress bars, install logs, passed tests | **Filter output at the CLI level.** [token-saver (RTK)](https://github.com/aetox-skills/token-saver) intercepts any bash command and strips noise before the ADE sees it — works with any tool that runs bash. | Any tool via bash | ~500–3000/call per command |
| **Instruction files** | Bloated docs, redundant descriptions, non-English instructions | **Trim to essentials.** Only load what the agent actually needs. Translate non-English content. Cut finished-task references. | All ADEs | ~5–15K |
| **MCP servers** | Each server injects full tool schemas into every call | **Disable unused ones.** Comment out servers that aren't needed for the current task. Activate on demand. | All ADEs with MCP | ~2–4K/server |
| **Skills / tools metadata** | Every registered skill adds name + description | **Remove unused.** Only keep skills the agent actually loads via `skill()` or equivalent. Shorten descriptions. | OpenCode, ZCode, Claude Code | ~300–500/skill |

> The pattern is universal: **identify what's in your prompt → ask if it changes between calls → if it doesn't, it's probably cached already. If it does, minimize it.**

---

## Example: What Optimization Looks Like

Below is a real measurement from an OpenCode setup that applied all of the above: trimmed instructions, disabled unused MCPs, compressed bash output, and capped history at 6 messages. The same techniques work on any ADE.

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
