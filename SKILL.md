---
name: token-calc
description: Token Auditor — measure system prompt, breakdown cache hit/miss, project cumulative tokens. Token-only, no pricing.
---

# Token Auditor

ใช้ `token-calc.ps1` — ไม่ต้องคำนวณเอง ยกเว้นรัน PowerShell ไม่ได้

## CLI

### Auto-measure (OpenCode)
```powershell
.\token-calc.ps1 -Measure -Calls 100 -CallsPerSession 20 -SessionsPerDay 5 -Days 365
```

### Manual
```powershell
.\token-calc.ps1 -InputTokens 50000 -CachedInputTokens 35000 -OutputTokens 2000 -Calls 100
```

### แบบย่อ
```powershell
.\token-calc.ps1 -InputTokens 50000 -CachedInputTokens 35000
```

| Param | ค่า |
|:--|:--|
| `-InputTokens` | input tokens ทั้งหมด |
| `-CachedInputTokens` | ส่วนที่ cache ได้ |
| `-OutputTokens` | output tokens |
| `-Measure` | auto-detect system prompt |
| `-Calls`, `-CallsPerSession`, `-SessionsPerDay`, `-Days` | projection scale |
