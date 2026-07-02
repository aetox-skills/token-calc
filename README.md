# Token Auditor

<<<<<<< HEAD
**Measure your system prompt. Identify waste. Get prescriptions.**

Your API calls cost more than they should. You just don't know how much — yet.

Every AI coding tool sends a system prompt with every call. Add an MCP server? Permanent +3K tok. Chat for 20 messages? History eats 100K+. Cache is 120× cheaper than a miss, but most people never check their hit rate.

We fix that. **Measure → Diagnose → Prescribe.** Platform-agnostic: OpenCode, ZCode, Claude Code, Codex, Cursor — any ADE that calls an API.
=======
**ควบคุมค่าใช้จ่าย AI API สำหรับ self-hosted — รองรับหลายแพลตฟอร์ม**

ตรวจจับอัตโนมัติ: **OpenCode** · **ZCode** · **Claude Code** (หรือระบุเองได้)
>>>>>>> f986abb (Thai README: แปล README ทั้งหมดเป็นภาษาไทย)

---

## เริ่มต้น

<<<<<<< HEAD
**Python (cross-platform — Windows / macOS / Linux):**
```bash
python token-calc.py --measure --calls 100 --output-tokens 2000
python token-calc.py --input-tokens 60000 --cached-input-tokens 52000 --calls 200
```

**PowerShell (Windows):**
```powershell
.\token-calc.ps1 -Measure -Calls 100 -OutputTokens 2000
=======
```powershell
# Auto-detect + คำนวณครบ
.\token-calc.ps1 -Measure -Calls 100 -OutputTokens 2000

# หรือระบุเอง
>>>>>>> f986abb (Thai README: แปล README ทั้งหมดเป็นภาษาไทย)
.\token-calc.ps1 -InputTokens 60000 -CachedInputTokens 52000 -OutputTokens 4000 -Calls 100
```

## สิ่งที่คุณได้

| หัวข้อ | คำอธิบาย |
|:--|:--|
| **⚠️ FIRST CALL SHOCK** | Tokens ที่เสียก่อนพิมพ์อะไรเลย |
| **📊 TOKEN BREAKDOWN** | Input = cache hit + cache miss, + output |
| **📈 CACHE EFFICIENCY** | Hit rate, miss rate, tokens ที่ประหยัดได้ |
| **🔄 PROCESSING PROJECTOR** | ตาราง: 1 → 10 → 20 → 50 → 100 calls |
| **💡 RECOMMENDATIONS** | ว่าควร optimize อะไร (แยกตาม platform) |
| **🚨 Threshold Guard** | `-Threshold 50000` เตือนก่อน deploy (exit 2) |

## มีอะไรใหม่ใน v2

| ฟีเจอร์ | รายละเอียด |
|:--|:--|
| **Multi-platform** | ตรวจจับ OpenCode, ZCode, Claude Code อัตโนมัติ |
| **`-Platform`** | กรองเฉพาะ: `opencode`, `zcode`, `claude` |
| **`-Milestones`** | กำหนดขั้น projection เอง: `"1,5,25,100,500"` |
| **`-ContextWindow`** | ตั้งขนาด context window ของ model (default 200K) |

## พารามิเตอร์

| Param | Default | คำอธิบาย |
|:--|:--|:--|
| `-InputTokens` | 0 | Input tokens ทั้งหมดต่อ 1 call |
| `-CachedInputTokens` | 0 | ส่วนที่เป็น cache hit |
| `-OutputTokens` | 0 | Output tokens |
| `-Measure` | off | ตรวจจับ system prompt อัตโนมัติ |
| `-Platform` | auto | `opencode` / `zcode` / `claude` |
| `-Calls` | 1 | จำนวน calls ที่จะ projection |
| `-CallsPerSession` | 10 | จำนวน calls ต่อ session |
| `-SessionsPerDay` | 3 | จำนวน sessions ต่อวัน |
| `-Milestones` | 1,10,20,50,100 | ขั้นในตาราง projection |
| `-Threshold` | 0 | ถ้าเกินให้ exit ด้วย error |
| `-ContextWindow` | 200000 | ขนาด context window ของ model |
| `-Save` | '' | บันทึก baseline เป็น JSON |
| `-Diff` | '' | เปรียบเทียบกับ baseline JSON |

## กรณีการใช้งาน

- **รู้อัตราการเผาผลาญ**: "100 calls = 1.25M processed, ไม่ใช่ 6.4M sent"
- **วางแผนก่อนเพิ่มอะไร**: "เพิ่ม MCP server ต้นทุน 3K tok/call"
- **CI guard**: "Deploy ล้มเหลวถ้า system prompt > 50K"
- **ติดตามการเปลี่ยนแปลง**: เปรียบเทียบ baseline เมื่อเปลี่ยน config
- **Multi-tool**: เปรียบเทียบขนาด prompt ระหว่าง OpenCode vs ZCode

<<<<<<< HEAD
## Optimization Guide

> Read this after you've measured. Don't guess what to fix — let the numbers tell you.

See [SKILL.md](SKILL.md) → **Optimization Strategy** for a full table of problems → solutions, cross-platform. Cap history, filter command output, trim MCPs, slim instructions — all with expected token savings. Includes a processed-token projection: ~22K tok/call at ~77% cache hit (6.8M tok/month vs 21.6M sent).

**Prescriptions link to tools that fix each problem:** [history-trimmer](https://github.com/aetox-skills/history-trimmer) for history bloat, [token-saver (RTK)](https://github.com/aetox-skills/token-saver) for noisy command output.
=======
## ตัวอย่างจริง

ดู [SKILL.md](SKILL.md) สำหรับตัวอย่างสมบูรณ์: **OpenCode Steward (หลัง optimization)** —  
system prompt ~22K, cache hit ~77%, ต้นทุน ~$0.07 สำหรับ 20 prompts บน DeepSeek V4 Flash
>>>>>>> f986abb (Thai README: แปล README ทั้งหมดเป็นภาษาไทย)

## ปรัชญา

<<<<<<< HEAD
### Tokens only
We measure what leaves your machine — cache hit, cache miss, output, processed totals. **No pricing, no model, no money.** Prices change, models change, but token waste is universal.

> If you have a pricing lookup skill, use it alongside this one. If not, the token counts are all you need — cutting waste saves money regardless of rate.

### Measure before you optimize
Don't guess what to cut. Run the script first. The numbers tell you where the waste is — instructions, MCPs, history, skills. **The goal isn't a smaller number. The goal is knowing where your tokens go so you can decide what's worth it.**

### "Sent" ≠ "Processed"
What you send to the API is not what you pay for. Cache reuse means the first call carries the full system prompt; every call after that only pays for fresh input. **The gap between "sent" and "processed" is where optimization lives.**

### Cross-platform by design
This works on any AI coding tool that calls an API — OpenCode, Claude Code, Codex, Cursor, ZCode, Gemini CLI. The problems are the same: bloat is universal, and so are the solutions. **We don't care which tool you use. We care about what you send.**

### Diagnose → Prescribe
This is not a calculator. A calculator tells you a number. We tell you what's eating tokens, how much each layer costs, and where to look for savings. **We exist because waste is invisible until someone measures it.**
=======
**Token-only.** ไม่มีราคา, ไม่มี model, ไม่มีเงิน — วัดแค่ tokens คุณจัดการ cost เอง ทำให้ maintainable โดยไม่ต้องตามราคาที่เปลี่ยนตลอด
>>>>>>> f986abb (Thai README: แปล README ทั้งหมดเป็นภาษาไทย)

## License

MIT
