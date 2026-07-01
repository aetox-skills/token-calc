# Token Auditor

**Stop surprise AI costs.** Inspect your system prompt before it eats tokens.

## Key Features

| Feature | What it does |
|:--|:--|
| **⚠️ First Call Shock** | Shows the 60K+ tokens gone before you type |
| **🔴 Risk Level** | GREEN / CAUTION / HIGH based on input size |
| **🚨 Threshold Guard** | `-Threshold 50000` exits with error code 2 if exceeded |
| **📊 Breakdown** | MCP, skills, agents, files — what's eating your prompt |
| **📈 Cache Analysis** | Hit/miss breakdown + cumulative projections |
| **💾 Snapshot** | `-Save` baseline, `-Diff` changes over time |

## Usage

```powershell
# Full inspection + shock warning
.\token-calc.ps1 -InputTokens 60000 -CachedInputTokens 52000 -OutputTokens 4000 -Calls 100

# Guard: fail in CI if prompt too big
.\token-calc.ps1 -Measure -Threshold 50000

# Track changes
.\token-calc.ps1 -Measure -Save baseline.json
.\token-calc.ps1 -Measure -Diff baseline.json
```

## License

MIT
