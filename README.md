# Token Auditor

Self-inspect your AI coding tool's system prompt. One-shot measurement of:
- **System prompt breakdown** — every component measured
- **Cache efficiency** — hit rate, miss rate, reused tokens
- **Cumulative projections** — per call → session → day
- **Optimization recommendations** — tells you what to do
- **Snapshot tracking** — save baseline, diff changes over time

**Token-only** — no pricing, no model, no money.

## Usage

```powershell
# Measure + recommendations
.\token-calc.ps1 -Measure -Calls 100

# Save baseline
.\token-calc.ps1 -Measure -Save .\baseline.json

# Check what changed
.\token-calc.ps1 -Measure -Diff .\baseline.json

# Manual
.\token-calc.ps1 -InputTokens 50000 -CachedInputTokens 35000 -OutputTokens 2000
```

## License

MIT
