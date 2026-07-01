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
