---
name: token-calc
description: Token Auditor — measure system prompt, cache efficiency, cumulative projections, and optimization recommendations. Self-inspect any AI coding tool.
---

# Token Auditor

**AI can't measure itself objectively.** This script measures from outside — no bias, no reading limitations, consistent every time.

## CLI

```powershell
# See what your system prompt is made of + what to do about it
.\token-calc.ps1 -Measure -Calls 100 -CallsPerSession 20 -SessionsPerDay 5

# Save baseline for tracking changes
.\token-calc.ps1 -Measure -Save .\baseline.json

# Check what changed since last time
.\token-calc.ps1 -Measure -Diff .\baseline.json

# Manual
.\token-calc.ps1 -InputTokens 50000 -CachedInputTokens 35000 -OutputTokens 2000
```

## What AI gets from this

| Can't do itself | Gets from script |
|:--|:--|
| Objectively measure own prompt size | Accurate breakdown per component |
| Know cache hit/miss ratio | Heuristic based on stable vs fresh content |
| See cumulative impact across time | Per call → session → day projections |
| Track changes over time | -Save / -Diff for before/after |
| Know what to optimize | Built-in recommendations |
