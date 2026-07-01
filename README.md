# Token Auditor

**Cost control tool for anyone running their own AI API keys.**

Know what you're spending before the bill comes. Measure your system prompt, see the "first call shock", project processing costs across call milestones, and guard against surprises.

---

## The Problem

เปิด OpenCode ขึ้นมา → 60,000 tokens ถูกส่งไปแล้ว → ยังไม่ได้พิมพ์อะไรเลย

พอใช้ไปเรื่อยๆ **cache hit** สะสมเป็น 40 ล้าน tokens → สงสัยทำไมค่าบริการถึงสูงขึ้นเรื่อยๆ

สกิลนี้ถูกสร้างขึ้นเพื่อตอบคำถามเดียว: **"กูใช้ token ไปเท่าไหร่ และมันหายไปกับอะไรบ้าง"**

---

## Output Example

```
⚠️  FIRST CALL SHOCK
  Opening this session costs you 64,000 tok before you type.
  That's 30% of your 200,000 context window.
  First call = 5.3× the cost of a repeated call.

📊 TOKEN BREAKDOWN (per call)
  Input Sent                           60,000
    ↳ Cache Hit (reused)               52,000
    ↳ Cache Miss (fresh)                8,000
  Output Received                       4,000
  Total Sent/Received                  64,000
  Context Window Used                     30%

📈 CACHE EFFICIENCY
  Cache Hit Rate                           86.7%
  Cache Miss Rate                          13.3%
  Reused per Call                         52,000

🔄 PROCESSING PROJECTOR
     Calls      Total Sent  Processed (pay)
   ─────    ────────────  ──────────────
       1          64,000          64,000
      10         640,000         172,000
      20       1,280,000         292,000
      50       3,200,000         652,000
     100       6,400,000       1,252,000

💡 RECOMMENDATIONS
  • CRITICAL: Input 60,000 tok eats 30% of 200,000 context window.
  • Set -Threshold <tok> to guard against surprises in CI/scripts.
```

---

## Key Sections

| Section | What it tells you |
|:--|:--|
| **⚠️ FIRST CALL SHOCK** | คุณเสีย token เท่าไหร่ก่อนพิมพ์อะไร — สาเหตุหลักของค่าใช้จ่ายสูง |
| **📊 TOKEN BREAKDOWN** | input = cache hit + cache miss, + output |
| **📈 CACHE EFFICIENCY** | สัดส่วน cache ที่ช่วยคุณไว้ |
| **🔄 PROCESSING PROJECTOR** | projection 1 → 10 → 20 → 50 → 100 calls (Total Sent vs Processed = จ่ายจริง) |
| **💡 RECOMMENDATIONS** | optimization targets + critical warnings |

---

## Installation

```powershell
# Clone repo
git clone https://github.com/aetox-skills/token-calc.git
cd token-calc

# Or just download the script directly
iwr -Uri https://raw.githubusercontent.com/aetox-skills/token-calc/main/token-calc.ps1 -OutFile token-calc.ps1
```

---

## CLI Reference

### Basic inspection

```powershell
# Manual mode — you know your token counts
.\token-calc.ps1 -InputTokens 60000 -CachedInputTokens 52000 -OutputTokens 4000 -Calls 100

# Auto-measure OpenCode system prompt
.\token-calc.ps1 -Measure -Calls 100
```

### Guard mode

```powershell
# Fail if system prompt exceeds 50K (exit code 2)
.\token-calc.ps1 -Measure -Threshold 50000

# Use in CI pipeline:
if (!(.\token-calc.ps1 -Measure -Threshold 50000)) { exit 1 }
```

### Snapshot tracking

```powershell
# Save current state as baseline
.\token-calc.ps1 -Measure -Save .\baseline.json

# Compare current vs baseline (detect drift)
.\token-calc.ps1 -Measure -Diff .\baseline.json
```

### Projection customization

```powershell
# Default: Calls=1, CallsPerSession=10, SessionsPerDay=3
.\token-calc.ps1 -InputTokens 60000 -CachedInputTokens 52000

# Custom projection
.\token-calc.ps1 -InputTokens 60000 -CachedInputTokens 52000 -OutputTokens 4000 `
    -Calls 200 -CallsPerSession 25 -SessionsPerDay 8

# Set context window (default 200K)
.\token-calc.ps1 -InputTokens 60000 -CachedInputTokens 52000 -ContextWindow 128000
```

---

## How Cache Works (For This Tool)

**Cache hit** = tokens ที่ถูกส่งซ้ำจาก call ก่อนหน้า → provider คิดราคาถูกกว่า (หรือฟรี)
**Cache miss** = tokens ใหม่ที่ยังไม่เคยส่ง → คิดราคาเต็ม

Script นี้ใช้ heuristic ง่ายๆ: **stable content = cache hit, new content = cache miss**

- **Cache hit**: system prompt, instruction files, skill descriptions, agent descriptions, MCP tool definitions, conversation history prefix
- **Cache miss**: user prompt, tool outputs, new conversation turns

ใน reality cache hit ratio อาจสูงถึง 85-90% (อย่างที่ Mike เจอ: 45M tokens, 40M cache hit = 88%)

---

## Use Cases

### 1. รู้จัก burn rate ของตัวเอง

เปิดมา 64K → ตกใจ → แก้ prompt → ลดเหลือ 30K → ประหยัด 53% ต่อ call

### 2. ตัดสินใจก่อนเพิ่ม components

"ถ้าเพิ่ม MCP server 1 ตัว → input เพิ่ม 3K → processing cost เพิ่ม 25%"
→ รู้ก่อน deploy แทนที่จะมารู้ทีหลังตอนบิลมา

### 3. CI/CD Guard

ใน pipeline build: `token-calc -Measure -Threshold 50000`
ถ้า system prompt ใหญ่เกินไป → build fail → แก้ก่อน merge

### 4. ติดตามการเปลี่ยนแปลง

- `-Save` ไว้ก่อนแก้ config
- `-Diff` หลังแก้ → "MCP tools โตขึ้น 3K, skills เพิ่ม 150 tok" → เห็นผลกระทบ

---

## Limitations

- **Token counts are approximate** — ไม่ได้ใช้ tokenizer จริงของ provider (ใช้ formula chars/4)
- **Cache heuristic** — cache จริงขึ้นกับ provider/prompt structure อาจต่างจากที่คำนวณ
- **Measure mode** — วัดเฉพาะ OpenCode config files (instruction files + agent/skill descriptions + MCP estimate + overhead)
  - ไม่รวม conversation history, tool outputs, project files ที่โหลดตอนใช้งานจริง
  - ฉะนั้น `-Measure` มักได้ต่ำกว่าของจริง (17K vs 60K+) — ใช้ manual mode ถ้าต้องการตัวเลขที่ตรงกว่า

---

## License

MIT
