# Token Auditor

**Cost control for self-hosted API users.** See your processing burn rate before it burns you.

## Quick Start

```powershell
# Measure your system + project processing costs
.\token-calc.ps1 -InputTokens 60000 -CachedInputTokens 52000 -OutputTokens 4000 -Calls 100
```

## What you get

- ⚠️ **First Call Shock** — what you pay before typing
- 🔄 **Processing Projector** — table of 1, 10, 20, 50, 100 calls
- 📊 **Cache Efficiency** — hit rate, miss rate, reused per call
- 💡 **Recommendations** — what to optimize
- 🚨 **Threshold Guard** — `-Threshold 50000` fails early

## Use cases

- **Know your burn rate**: "100 calls = 1.25M processed, not 6.4M sent"
- **Plan before you build**: "Adding an MCP server costs me X tok/call"
- **CI guard**: "Deploy fails if system prompt > 50K"
- **Track drift**: "My prompt grew 10% this week"

## License

MIT
