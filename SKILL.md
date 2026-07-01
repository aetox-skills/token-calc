---
name: token-calc
description: Token Auditor — cost control for self-hosted API users. Project processing costs across call milestones. Know your burn rate.
---

# Token Auditor

**Cost control tool for anyone running their own API keys.** Shows what you'll actually pay to process — not just how many tokens you send.

## Why this exists

First call costs 64K. Cache hides the rest. By call 100 you've sent 6.4M but only paid for 1.25M. Without this tool, you don't know your burn rate.

## CLI

```powershell
# Full inspection + processing projector (1, 10, 20, 50, 100 calls)
.\token-calc.ps1 -InputTokens 60000 -CachedInputTokens 52000 -OutputTokens 4000 -Calls 100

# Auto-measure your setup
.\token-calc.ps1 -Measure -Calls 100

# Guard against surprises
.\token-calc.ps1 -Measure -Threshold 50000

# Track changes
.\token-calc.ps1 -Measure -Save baseline.json
.\token-calc.ps1 -Measure -Diff baseline.json
```

## Key output

| Section | What it tells you |
|:--|:--|
| FIRST CALL SHOCK | Cost of opening the session |
| PROCESSING PROJECTOR | Table: 1 → 10 → 20 → 50 → 100 calls |
| RECOMMENDATIONS | What to optimize |
