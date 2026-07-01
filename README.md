# Token Auditor

Measure system prompt, breakdown cache hit/miss, project cumulative tokens.

**Token-only** — no pricing, no model, no money.

## Usage

```powershell
# Auto-measure your OpenCode system prompt
.\token-calc.ps1 -Measure -Calls 100

# Manual mode
.\token-calc.ps1 -InputTokens 50000 -CachedInputTokens 35000 -OutputTokens 2000

# Project a year
.\token-calc.ps1 -Measure -Calls 100 -CallsPerSession 20 -SessionsPerDay 5 -Days 365
```

## Output

- Token breakdown: input / cache hit / cache miss / output
- Cache analysis: hit rate, miss rate, saved per call
- Call comparison: first call (no cache) vs repeated vs total
- Cumulative projections: session → day → month → year

## License

MIT
