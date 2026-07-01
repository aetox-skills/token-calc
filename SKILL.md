---
name: token-calc
description: Token Auditor — cost control for self-hosted AI API users. Measure system prompt, project processing costs, guard against surprises.
---

# Token Auditor

**Script outputs in English.** AI must read the output and explain to the user in whatever language they spoke to you.

## CLI

```powershell
# Full inspection + projections
.\token-calc.ps1 -InputTokens 60000 -CachedInputTokens 52000 -OutputTokens 4000 -Calls 100

# Auto-measure OpenCode setup
.\token-calc.ps1 -Measure -Calls 100

# Guard against big prompts
.\token-calc.ps1 -Measure -Threshold 50000

# Track changes
.\token-calc.ps1 -Measure -Save baseline.json
.\token-calc.ps1 -Measure -Diff baseline.json
```

## AI Instructions

1. **Run the script** with `-Measure` (auto) or manual values
2. **Read the output** — all sections: FIRST CALL SHOCK, TOKEN BREAKDOWN, CACHE EFFICIENCY, PROCESSING PROJECTOR, RECOMMENDATIONS
3. **Explain to user in their language** — translate the key findings:
   - How many tokens they lose before typing (first call shock)
   - What's eating their system prompt (biggest components)
   - What happens at 10/20/50/100 calls (processing projector)
   - What they should do (recommendations)
4. **Keep technical terms in English**: token, cache hit, cache miss, MCP, context window, threshold
