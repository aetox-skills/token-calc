#!/usr/bin/env python3
"""
Token Auditor — measure your system prompt, identify waste, get prescriptions.
Cross-platform: Windows / macOS / Linux

Usage:
  python token-calc.py --measure --calls 100 --output-tokens 2000
  python token-calc.py --measure --platform opencode
  python token-calc.py --input-tokens 60000 --cached-input-tokens 52000 --calls 200
  python token-calc.py --measure --threshold 50000
  python token-calc.py --measure --save baseline.json
  python token-calc.py --measure --diff baseline.json
"""

import argparse
import json
import math
import os
import re
import sys
from pathlib import Path

# ─── UTF-8 output for Windows (emoji/unicode display) ────
if sys.platform == "win32" and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

# ─── MCP Server Registry ─────────────────────────────────────
# Token counts measured from actual tool definitions (name + description + parameter schemas)
MCP_REGISTRY = {
    'obsidian':            {'tools': 15, 'tok': 1150, 'desc': 'Obsidian vault (15 tools: read/write/search/manage)'},
    'sequential-thinking': {'tools': 1,  'tok': 550,  'desc': 'Sequential thinking (1 tool, 11 complex params)'},
    'exa':                 {'tools': 2,  'tok': 250,  'desc': 'Exa semantic search + fetch'},
    'context7':            {'tools': 2,  'tok': 250,  'desc': 'Context7 library docs resolve + query'},
    'gmail':               {'tools': 4,  'tok': 600,  'desc': 'Gmail send/read/search/draft'},
    'speak':               {'tools': 1,  'tok': 100,  'desc': 'Thai TTS speak tool'},
    'image-resolver':      {'tools': 2,  'tok': 200,  'desc': 'Pexels/Unsplash image search'},
    'pixabay':             {'tools': 2,  'tok': 200,  'desc': 'Pixabay media search'},
}

# ─── Helpers ────────────────────────────────────────────────

def count_tokens(text: str) -> int:
    """Estimate tokens: ~4 English chars, ~3 Thai/Chinese chars per token."""
    thai = len([c for c in text if '\u0E00' <= c <= '\u0E7F'])
    chinese = len([c for c in text if '\u4E00' <= c <= '\u9FFF'])
    english = len(text) - thai - chinese
    return math.ceil(english / 4 + thai / 3 + chinese / 3)


def fmt(n: int) -> str:
    """Format number with commas."""
    return f"{n:,}"


def read_agent_descriptions(agents_dir: Path, platform: str) -> tuple[int, list]:
    """Read agent descriptions from frontmatter."""
    total = 0
    details = []
    if not agents_dir.exists():
        return total, details
    for af in sorted(agents_dir.glob("*.md")):
        content = af.read_text(encoding="utf-8", errors="replace")
        m = re.search(r'description:\s*[\'"]?([^\'"\n]+)', content)
        if m:
            tok = math.ceil(len(m.group(1)) / 4) + math.ceil(len(af.stem) / 4)
            total += tok
            details.append({"component": f"{af.stem} (agent)", "tokens": tok, "platform": platform})
    return total, details


def read_skill_descriptions(skills_dir: Path, platform: str) -> tuple[int, list]:
    """Read skill descriptions from frontmatter."""
    total = 0
    details = []
    if not skills_dir.exists():
        return total, details
    for sd in sorted(skills_dir.iterdir()):
        if sd.is_dir():
            sf = sd / "SKILL.md"
            if sf.exists():
                content = sf.read_text(encoding="utf-8", errors="replace")
                m = re.search(r'description:\s*[\'"]?([^\'"\n]+)', content)
                if m:
                    tok = math.ceil(len(m.group(1)) / 4) + math.ceil(len(sd.name) / 4) + 30
                    total += tok
                    details.append({"component": f"{sd.name} (skill)", "tokens": tok, "platform": platform})
    return total, details


# ─── Platform Detectors ─────────────────────────────────────

def measure_opencode(home: Path) -> tuple[int, list, bool]:
    """Measure OpenCode system prompt components."""
    total = 0
    details = []
    config_dir = home / ".config" / "opencode"
    found = False

    # Common instruction files in home directory
    for fname in ["CONTEXT.md", "PROFILE.md", "AGENTS.md"]:
        f = home / fname
        if f.exists():
            tok = count_tokens(f.read_text(encoding="utf-8", errors="replace"))
            total += tok
            details.append({"component": fname, "tokens": tok, "platform": "OpenCode"})
            found = True

    # opencode_data/index.md (if exists)
    data_file = home / "opencode_data" / "index.md"
    if data_file.exists():
        tok = count_tokens(data_file.read_text(encoding="utf-8", errors="replace"))
        total += tok
        details.append({"component": "index.md", "tokens": tok, "platform": "OpenCode"})
        found = True

    # Agents
    t, d = read_agent_descriptions(config_dir / "agents", "OpenCode")
    total += t
    details.extend(d)
    if t:
        found = True

    # Skills
    t, d = read_skill_descriptions(config_dir / "skills", "OpenCode")
    total += t
    details.extend(d)
    if t:
        found = True

    return total, details, found


def measure_zcode(home: Path) -> tuple[int, list, bool]:
    """Measure ZCode system prompt components."""
    zcode_dir = home / ".zcode"
    if not zcode_dir.exists():
        return 0, [], False

    total = 0
    details = []
    found = False

    t, d = read_agent_descriptions(zcode_dir / "agents", "ZCode")
    total += t
    details.extend(d)
    if t:
        found = True

    t, d = read_skill_descriptions(zcode_dir / "skills", "ZCode")
    total += t
    details.extend(d)
    if t:
        found = True

    return total, details, found


def measure_claude(home: Path) -> tuple[int, list, bool]:
    """Measure Claude Code system prompt components."""
    claude_dir = home / ".claude"
    if not claude_dir.exists():
        return 0, [], False

    total = 0
    details = []
    found = False

    inst = claude_dir / "instructions.md"
    if inst.exists():
        tok = count_tokens(inst.read_text(encoding="utf-8", errors="replace"))
        total += tok
        details.append({"component": "instructions.md", "tokens": tok, "platform": "Claude"})
        found = True

    return total, details, found


def measure_mcp_opencode(home: Path, platform: str = "common") -> tuple[int, list]:
    """Measure MCP server tokens from actual opencode.jsonc config."""
    total = 0
    details = []

    config_path = home / ".config" / "opencode" / "opencode.jsonc"
    if not config_path.exists():
        return total, details

    # Parse active MCP servers from JSONC config (JSON with // comments)
    active_servers = []
    with open(config_path, encoding="utf-8") as f:
        lines = f.readlines()

    in_mcp = False
    mcp_indent = -1
    server_indent = -1

    for line in lines:
        stripped = line.strip()
        indent = len(line) - len(line.lstrip())

        if '"mcp"' in stripped and ':' in stripped and '{' in stripped:
            in_mcp = True
            mcp_indent = indent
            server_indent = indent + 2
            continue

        if not in_mcp:
            continue

        # Leave mcp section when we hit a closing brace at mcp indent level or lower
        if indent <= mcp_indent and stripped == '}' and '{' not in stripped:
            in_mcp = False
            break

        # Skip comments
        if stripped.startswith('//'):
            continue

        # Match server names at server indent level: "name": {
        m = re.match(r'^"([^"]+)"\s*:\s*\{', stripped)
        if m and indent == server_indent:
            active_servers.append(m.group(1))

    # Calculate tokens from registry
    for srv_name in active_servers:
        known = MCP_REGISTRY.get(srv_name)
        if known:
            total += known['tok']
            details.append({
                "component": f"MCP: {srv_name} ({known['tools']} tools)",
                "tokens": known['tok'],
                "platform": platform,
            })
        else:
            # Unknown server — rough estimate from name + typical overhead
            est = 300
            total += est
            details.append({
                "component": f"MCP: {srv_name} [unknown, est]",
                "tokens": est,
                "platform": platform,
            })

    if active_servers:
        # MCP instruction blocks + list/read_resource meta tools
        mcp_overhead = 500
        total += mcp_overhead
        details.append({
            "component": "MCP: system overhead (instructions + meta)",
            "tokens": mcp_overhead,
            "platform": platform,
        })

    return total, details


# ─── Display ────────────────────────────────────────────────

LINE = "─" * 60


def print_measurement(details: list, total: int, platforms: list):
    """Print system prompt measurement results."""
    print()
    print("📏 Measuring system prompt...")
    print(f"  Platforms detected: {', '.join(platforms) if platforms else 'none'}")
    for d in sorted(details, key=lambda x: x["tokens"], reverse=True):
        print(f"  {d['component']:<44} {fmt(d['tokens']):>8}")
    print(f"  {'TOTAL system prompt':<44} {fmt(total):>8} tok")


def display(risk_color: str, risk_label: str, input_tokens: int, cached_input_tokens: int,
            cache_miss_tokens: int, output_tokens: int, total_sent_per_call: int,
            ctx_pct: float, calls: int, first_call_new: int, each_repeated_new: int,
            shock_multiplier: float, cache_hit_rate: float, cache_miss_rate: float,
            milestones: list, recs: list, diffs: list):
    """Print the full token auditor output."""
    print()
    print(LINE)
    print(f"  TOKEN AUDITOR  ●  RISK: {risk_label}")
    print(LINE)

    # FIRST CALL SHOCK
    if calls > 1:
        print()
        print(f"⚠️  FIRST CALL SHOCK")
        print(f"  Opening this session costs you {fmt(first_call_new)} tok before you type.")
        print(f"  That's {ctx_pct:.0f}% of your context window.")
        print(f"  Each subsequent call costs only {fmt(each_repeated_new)} tok (cache kicks in).")
        print(f"  First call = {shock_multiplier}× the cost of a repeated call.")

    # TOKEN BREAKDOWN
    print()
    print("📊 TOKEN BREAKDOWN (per call)")
    print(f"  {'Input Sent':<33} {fmt(input_tokens):>12}")
    print(f"  {'  ↳ Cache Hit (reused)':<33} {fmt(cached_input_tokens):>12}")
    print(f"  {'  ↳ Cache Miss (fresh)':<33} {fmt(cache_miss_tokens):>12}")
    if output_tokens > 0:
        print(f"  {'Output Received':<33} {fmt(output_tokens):>12}")
    print(f"  {'Total Sent/Received':<33} {fmt(total_sent_per_call):>12}")
    print(f"  {'Context Window Used':<33} {ctx_pct:.0f}%")

    # CACHE
    print()
    print("📈 CACHE EFFICIENCY")
    print(f"  {'Cache Hit Rate':<33} {cache_hit_rate:.1%}")
    print(f"  {'Cache Miss Rate':<33} {cache_miss_rate:.1%}")
    print(f"  {'Reused per Call':<33} {fmt(cached_input_tokens):>12}")

    # PROCESSING PROJECTOR
    if len(milestones) > 1:
        print()
        print("🔄 PROCESSING PROJECTOR")
        print("  What you'll actually pay to process at each stage:")
        print(f"  {'Calls':>8}  {'Total Sent':>14}  {'Processed (pay)':>14}")
        print(f"  {'─'*5:>8}  {'─'*12:>14}  {'─'*14:>14}")
        for m in milestones:
            msent = total_sent_per_call * m
            mproc = first_call_new + (each_repeated_new * (m - 1))
            print(f"  {m:>6}  {fmt(msent):>14}  {fmt(mproc):>14}")
        print("  Note: 'Processed (pay)' = first call full + repeated fresh-only (cache miss + output)")

    # RECOMMENDATIONS
    if recs:
        print()
        print("💡 RECOMMENDATIONS")
        for r in recs:
            print(f"  • {r}")

    # DIFF
    if diffs:
        print()
        print("📉 DIFF vs BASELINE")
        for d in diffs:
            print(f"  • {d}")

    print(LINE)
    print("  Token counts are approximate. Use exact tokenizer for billing.")
    print()


# ─── Main ───────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Token Auditor — measure your system prompt, identify waste, get prescriptions."
    )
    parser.add_argument("--input-tokens", type=int, default=0,
                        help="Total input tokens per call")
    parser.add_argument("--cached-input-tokens", type=int, default=0,
                        help="Cache hit portion of input tokens")
    parser.add_argument("--output-tokens", type=int, default=0,
                        help="Estimated output tokens per call")
    parser.add_argument("--measure", action="store_true",
                        help="Auto-detect system prompt from installed ADEs")
    parser.add_argument("--platform", default="",
                        choices=["", "opencode", "zcode", "claude"],
                        help="Target platform (default: auto-detect all)")
    parser.add_argument("--calls", type=int, default=1,
                        help="Number of calls to project")
    parser.add_argument("--calls-per-session", type=int, default=30,
                        help="Calls per session")
    parser.add_argument("--sessions-per-day", type=int, default=1,
                        help="Sessions per day")
    parser.add_argument("--milestones", default="1,10,20,50,100",
                        help="Comma-separated projection steps")
    parser.add_argument("--threshold", type=int, default=0,
                        help="Exit with error if input tokens exceed this")
    parser.add_argument("--context-window", type=int, default=200000,
                        help="Model context window size")
    parser.add_argument("--save", default="",
                        help="Save measurement as JSON baseline")
    parser.add_argument("--diff", default="",
                        help="Compare against saved JSON baseline")

    args = parser.parse_args()
    home = Path.home()

    # ── Auto-measure ────────────────────────────────────────
    measure_result = None
    if args.measure:
        all_details = []
        total = 0
        platforms_detected = []
        target = args.platform.lower() if args.platform else ""

        if not target or target == "opencode":
            t, d, found = measure_opencode(home)
            total += t
            all_details.extend(d)
            if found:
                platforms_detected.append("OpenCode")

        if not target or target == "zcode":
            t, d, found = measure_zcode(home)
            total += t
            all_details.extend(d)
            if found:
                platforms_detected.append("ZCode")

        if not target or target == "claude":
            t, d, found = measure_claude(home)
            total += t
            all_details.extend(d)
            if found:
                platforms_detected.append("Claude")

        # MCP servers — read from actual OpenCode config
        mcp_tok, mcp_details = measure_mcp_opencode(home)
        total += mcp_tok
        all_details.extend(mcp_details)

        total += 2000  # system overhead
        all_details.append({"component": "System overhead", "tokens": 2000, "platform": "common"})

        total += 5000  # history cap estimate (~10 msgs)
        all_details.append({"component": "History (capped ~10 msgs)", "tokens": 5000, "platform": "common"})

        args.input_tokens = total
        if args.cached_input_tokens == 0:
            args.cached_input_tokens = round(total * 0.3)

        print_measurement(all_details, total, platforms_detected)

        measure_result = {
            "total": total,
            "details": all_details,
            "platforms": platforms_detected,
        }

        if args.save:
            with open(args.save, "w", encoding="utf-8") as f:
                out = [{"component": d["component"], "tokens": d["tokens"],
                        "platform": d["platform"]} for d in all_details]
                json.dump(out, f, indent=2)
            print(f"\n💾 Baseline saved → {args.save}")

    # ── Validate ────────────────────────────────────────────
    if args.input_tokens <= 0 and args.output_tokens <= 0:
        print("Need at least some tokens. Use --measure or --input-tokens.")
        sys.exit(1)

    # ── Threshold guard ─────────────────────────────────────
    if args.threshold > 0 and args.input_tokens > args.threshold:
        print(f"\n🚨 THRESHOLD EXCEEDED!")
        print(f"  Input: {fmt(args.input_tokens)} tok > Limit: {fmt(args.threshold)} tok")
        sys.exit(2)

    # ── Load baseline for diff ──────────────────────────────
    previous = None
    if args.diff:
        try:
            with open(args.diff, encoding="utf-8") as f:
                previous = json.load(f)
        except Exception:
            previous = None

    # ── Calculations ────────────────────────────────────────
    cache_miss_tokens = max(0, args.input_tokens - args.cached_input_tokens)
    total_sent_per_call = args.input_tokens + args.output_tokens
    cache_hit_rate = args.cached_input_tokens / args.input_tokens if args.input_tokens > 0 else 0
    cache_miss_rate = 1 - cache_hit_rate
    ctx_pct = args.input_tokens / args.context_window * 100 if args.context_window > 0 else 0

    first_call_new = total_sent_per_call
    each_repeated_new = cache_miss_tokens + args.output_tokens
    shock_multiplier = round(first_call_new / each_repeated_new, 1) if each_repeated_new > 0 else 1

    per_session = total_sent_per_call * args.calls_per_session
    per_day = per_session * args.sessions_per_day

    # ── Risk level ──────────────────────────────────────────
    if args.input_tokens > 50000:
        risk_label = "HIGH"
        risk_color = "red"
    elif args.input_tokens > 20000:
        risk_label = "CAUTION"
        risk_color = "yellow"
    else:
        risk_label = "LOW"
        risk_color = "green"

    # ── Milestones ──────────────────────────────────────────
    milestones = []
    for s in args.milestones.split(","):
        s = s.strip()
        if s.isdigit():
            m = int(s)
            if m <= args.calls:
                milestones.append(m)
    if args.calls not in milestones:
        milestones.append(args.calls)
    milestones = sorted(set(milestones))

    # ── Recommendations ─────────────────────────────────────
    recs = []
    if measure_result:
        mcp_total = sum(d["tokens"] for d in measure_result["details"]
                        if "MCP" in d["component"])
        mcp_pct = mcp_total / measure_result["total"] * 100 if measure_result["total"] > 0 else 0
        if mcp_pct > 50:
            recs.append(f"MCP tools dominate ({mcp_pct:.0f}%). Merge or disable unused servers.")

        sorted_d = sorted(measure_result["details"], key=lambda x: x["tokens"], reverse=True)
        top3 = sorted_d[:3]
        if top3:
            parts = []
            for d in top3:
                parts.append(f"{d['component']} [{d['platform']}] ({fmt(d['tokens'])} tok)")
            recs.append(f"Top 3 optimization targets by platform: {', '.join(parts)}")

    if cache_hit_rate < 0.4 and args.input_tokens > 0:
        recs.append(f"Cache too low ({cache_hit_rate:.1%}). Structure prompt for reuse.")
    if args.input_tokens > 50000:
        recs.append(f"CRITICAL: Input {fmt(args.input_tokens)} tok eats {ctx_pct:.0f}% of {fmt(args.context_window)} context window.")
    if args.output_tokens == 0:
        recs.append("Add --output-tokens for complete per-call picture (model response).")
    if args.threshold == 0:
        recs.append("Set --threshold <tok> to guard against surprises in CI/scripts.")

    # ── Diff ────────────────────────────────────────────────
    diffs = []
    if previous and measure_result:
        prev_total = sum(d["tokens"] for d in previous)
        curr_total = measure_result["total"]
        diff_tok = curr_total - prev_total
        pct = round(diff_tok / prev_total * 100, 1) if prev_total > 0 else 0
        arrow = "↑" if diff_tok >= 0 else "↓"
        diffs.append(f"Overall: {arrow} {fmt(abs(diff_tok))} tok ({pct}%)")

        prev_map = {}
        for d in previous:
            prev_map[d["component"]] = d["tokens"]
        for d in measure_result["details"]:
            old = prev_map.get(d["component"], 0)
            if old != d["tokens"]:
                d_arrow = "↑" if d["tokens"] >= old else "↓"
                diffs.append(f"{d['component']}: {d_arrow} {fmt(abs(d['tokens'] - old))} tok")

    # ── Display ─────────────────────────────────────────────
    display(
        risk_color=risk_color,
        risk_label=risk_label,
        input_tokens=args.input_tokens,
        cached_input_tokens=args.cached_input_tokens,
        cache_miss_tokens=cache_miss_tokens,
        output_tokens=args.output_tokens,
        total_sent_per_call=total_sent_per_call,
        ctx_pct=ctx_pct,
        calls=args.calls,
        first_call_new=first_call_new,
        each_repeated_new=each_repeated_new,
        shock_multiplier=shock_multiplier,
        cache_hit_rate=cache_hit_rate,
        cache_miss_rate=cache_miss_rate,
        milestones=milestones,
        recs=recs,
        diffs=diffs,
    )


if __name__ == "__main__":
    main()
