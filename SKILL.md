---
name: token-calc
description: Token Auditor — measure your system prompt, identify waste, project costs, and get prescriptions. Multi-platform: OpenCode, ZCode, Claude Code, or any ADE.
---

# Token Auditor

**We diagnose what your system prompt is made of, how much it costs, and what to do about it.**

Every AI coding tool sends a system prompt with every API call — instructions, tool definitions, MCP schemas, skills, history. It grows silently. You add one MCP server → permanent +3K tok. You chat for 20 messages → history eats 100K+ per call. Cache is 120× cheaper than miss, but most people never check their hit rate.

That's why this exists. **Measure before you optimize. Know before you pay.**

The goal isn't a smaller number. The goal is knowing where your tokens go so you can decide what's worth it.

**AI reads output in English, then explains to user in their language.**

## CLI

Both a Python script (cross-platform) and a PowerShell script (Windows) are provided. Same args, same output.

**Python — works on Windows / macOS / Linux:**
```bash
# Auto-detect any AI coding tool + full projection
python token-calc.py --measure --calls 100 --output-tokens 2000

# Target specific platform
python token-calc.py --measure --platform opencode
python token-calc.py --measure --platform zcode
python token-calc.py --measure --platform claude

# Custom projection milestones
python token-calc.py --input-tokens 60000 --cached-input-tokens 52000 --calls 200 --milestones "1,5,25,50,100,200"

# Guard mode
python token-calc.py --measure --threshold 50000

# Track changes
python token-calc.py --measure --save baseline.json
python token-calc.py --measure --diff baseline.json

# Manual
python token-calc.py --input-tokens 60000 --cached-input-tokens 52000 --output-tokens 4000
```

**PowerShell — Windows:**
```powershell
.\token-calc.ps1 -Measure -Calls 100 -OutputTokens 2000
```

## Args

| Python arg | PowerShell param | Default | Description |
|:--|:--|:--:|:--|
| `--platform` | `-Platform` | auto | opencode / zcode / claude |
| `--milestones` | `-Milestones` | 1,10,20,50,100 | Projection steps |
| `--calls` | `-Calls` | 1 | Calls to project |
| `--calls-per-session` | `-CallsPerSession` | 30 | Calls per session |
| `--sessions-per-day` | `-SessionsPerDay` | 1 | Sessions per day |
| `--threshold` | `-Threshold` | 0 | Exit if exceeded |
| `--context-window` | `-ContextWindow` | 200000 | Model context window |
| `--save` | `-Save` | '' | Save baseline JSON |
| `--diff` | `-Diff` | '' | Compare vs baseline |

## AI Workflow

1. Run the Python or PowerShell script with `--measure` or `-Measure`
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
| **Conversation history** | Grows every call, most of it irrelevant | **Cap at N messages.** OpenCode: [history-trimmer](https://github.com/aetox-skills/history-trimmer) plugin. Claude Code: use `compact` or `/compact`. Codex: lower `message_limit` in config. Other ADEs: apply the same principle — keep last few exchanges. | All ADEs | ~2–5K/call (stays flat) |
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
| History (capped) | ~5,000 | Plugin caps at ~10 messages |
| System overhead | ~2,000 | Built-in tool defs + runtime |
| CONTEXT.md | ~1,145 | Project context for agents |
| MCP: obsidian (15 tools) | ~1,150 | Measured from schema, not estimated |
| MCP: sequential-thinking (1 tool) | ~550 | Lightweight MCP |
| MCP: system overhead | ~500 | Instructions + meta (all servers) |
| PROFILE.md | ~487 | User profile |
| MCP: context7, exa (2 tools each) | ~500 | ~250 each |
| Available skills | ~690 | Short descriptions only (~70/skill) |
| Agent identities | ~145 | Names + descriptions only |
| **~Total input per call** | **~12,200** | Measured, not guessed |
| Output | ~2,000 | varies by query |

**Cache efficiency:**

| Metric | Value |
|:--|:--|
| Cache hit rate | ~30% |
| Cached per call | ~3,650 tok |
| Fresh per call | ~8,500 tok |

> Want to know what this costs in your currency? If you have a skill or tool installed that can look up your model's current API pricing, use it. Otherwise, skip the dollar amounts — the token counts above are all you need to optimize.

**Token projection (what you actually pay to process, not what you send):**

| Calls | Sent to API | Actually processed (pay) |
|:--:|:--:|:--:|
| 1 (cold) | 12,200 tok | 12,200 tok |
| 10 | 122,000 tok | 88,800 tok |
| 20 | 244,000 tok | 174,000 tok |
| 30 (session) | 366,000 tok | 259,200 tok |
| Month (30 sessions) | 10.98M tok | 7.78M tok |
| Year | 131.8M tok | 93.3M tok |

**Key insight:** "Sent" is what leaves your machine. **"Processed" is what you actually pay for** — only the cache miss + output. The gap gets wider the longer the session runs. Once your system prompt is cached, every call after the first is nearly free to send.
