# Token Auditor

> **รู้ก่อนเสีย — วัด token consumption จริงของ AI coding tools ก่อน deploy**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-OpenCode%20|%20ZCode%20|%20Claude%20Code-orange)](#)
[![Python](https://img.shields.io/badge/Python-3.8+-brightgreen)](#)
[![PowerShell](https://img.shields.io/badge/PowerShell-7+-blue)](#)

---

```text
📏 Measuring system prompt...
  Platforms detected: OpenCode, ZCode
  TOTAL system prompt                            12,012 tok
  
⚠️  FIRST CALL SHOCK
  Opening this session costs you 14,012 tok before you type.
  
📊 TOKEN BREAKDOWN (per call)
  Input Sent                              12,012
    ↳ Cache Hit (reused)                   3,604
    ↳ Cache Miss (fresh)                   8,408
  Output Received                          2,000

📈 CACHE EFFICIENCY
  Cache Hit Rate                    30.0%
  
🔄 100 calls → 1,044,404 tok processed (not 1,401,200 sent)
💡 Top optimization: History (5,000 tok), MCP tools (2,700 tok)
```

**ตรวจจับ system prompt ของคุณ จริง จากไฟล์ config จริง**  
แล้วบอกว่าแต่ละ session เผาผลาญ tokens เท่าไหร่ — แยกตาม cache hit/miss, projection ถึง 100 calls, และแนะนำว่าควร optimize ตรงไหน

---

## Features

| | | |
|:--|:--|:--|
| 🔍 | **Auto-detect** | อ่าน system prompt จาก OpenCode, ZCode, Claude Code โดยตรง |
| 💰 | **First Call Shock** | รู้ว่าเปิด session แต่ละครั้งเสีย tokens เท่าไหร่ก่อนพิมพ์ |
| 📊 | **Token Breakdown** | แยก input = cache hit + cache miss + output |
| 📈 | **Cache Efficiency** | Hit rate, miss rate, tokens ที่ประหยัดได้จริง |
| 🔮 | **Processing Projector** | 1 → 10 → 20 → 50 → 100 calls จะเสียเท่าไหร่ |
| 💡 | **Recommendations** | แนะนำสิ่งที่ควร optimize แยกตาม platform |
| 🚨 | **Threshold Guard** | ตั้ง alert ถ้า system prompt เกิน limit (`exit 2`) |
| 📉 | **Baseline Tracking** | `--save` + `--diff` เปรียบเทียบเมื่อเปลี่ยน config |
| 🔄 | **Multi-model** | วัด AI coding tool ได้ทีเดียว — เทียบ prompt size |

---

## Quick Start

### Python (cross-platform)

```bash
# Auto-detect + projection 100 calls
python token-calc.py --measure --calls 100 --output-tokens 2000

# Custom input
python token-calc.py --input-tokens 60000 --cached-input-tokens 52000 --calls 200

# Threshold guard (exit 2 if exceeded)
python token-calc.py --measure --threshold 50000
```

### PowerShell (Windows)

```powershell
.\token-calc.ps1 -Measure -Calls 100 -OutputTokens 2000
.\token-calc.ps1 -InputTokens 60000 -CachedInputTokens 52000 -OutputTokens 4000 -Calls 100
```

---

## Use Cases

### 🎯 รู้ต้นทุนจริงต่อ session

```bash
python token-calc.py --measure --calls 50
```
→ "50 calls = 524K processed tokens, cache hit 30% → ลดได้อีก"

### 🚧 CI Guard

```bash
python token-calc.py --measure --threshold 50000
if ($LASTEXITCODE -eq 2) { throw "System prompt too large!" }
```
→ Deploy ล้มเหลวถ้า system prompt > 50K tok

### 📉 ติดตาม trend

```bash
python token-calc.py --measure --save baseline.json
# ... แก้ config ...
python token-calc.py --measure --diff baseline.json
```
→ "Cache hit rate ลดลงจาก 45% → 30% — MCP ตัวใหม่อาจเป็นปัญหา"

---

## All Parameters

| Flag | Default | Description |
|:--|:--|:--|
| `--measure` | off | Auto-detect system prompt ของ AI coding tools |
| `--platform` | auto | `opencode` / `zcode` / `claude` |
| `--input-tokens` | 0 | Input tokens ต่อ call |
| `--cached-input-tokens` | 0 | ส่วนที่เป็น cache hit |
| `--output-tokens` | 0 | Output tokens ต่อ call |
| `--calls` | 1 | จำนวน calls ที่ projection |
| `--milestones` | 1,10,20,50,100 | ขั้น projection custom |
| `--threshold` | 0 | Alert threshold (exit code 1/2) |
| `--save` | — | บันทึก baseline เป็น JSON |
| `--diff` | — | เทียบกับ baseline JSON |
| `--context-window` | 200000 | Context window ของ model |
| `--no-details` | — | แสดงแค่ summary |

---

## Philosophy

**Token-only.** ไม่มีราคา, ไม่มี model pricing, ไม่มีสกุลเงิน — วัดแค่ tokens  
เพราะ token consumption คือ metric ที่ stable ที่สุดสำหรับ AI agent ops

คุณจัดการ cost เอง — Token Auditor ทำให้คุณรู้ก่อนว่าเท่าไหร่

---

## Examples

- **OpenCode Steward** → system prompt ~22K, cache ~77%, $0.07/20 prompts (DeepSeek V4 Flash)
- **ZCode backend-py** → system prompt ~18K, cache ~65%
- **Claude Code** → system prompt ~40K, cache ~50%

ดูรายละเอียดใน [SKILL.md](SKILL.md)

---

## License

MIT
