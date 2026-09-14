#!/usr/bin/env python3
"""Generate doc artifacts that must mirror the datetime binary.

Usage:
    gen-docs.py            regenerate README format table + tldr page
    gen-docs.py --check    verify all are current; exit 1 on drift

Generated regions:
  * README.md        - only the invocation/format table (between
                       <!-- BEGIN/END GENERATED: format-table --> markers);
                       everything else in the README stays hand-written.
  * tldr/datetime.md - the whole page (curated examples live in this
                       script; format names come from the binary).

Additionally --check verifies that every long option printed by
`datetime --help` appears in man/man1/datetime.1 (option parity).

The binary is the single source of truth: nothing here hardcodes
formats or option lists.
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BIN = ROOT / "datetime"
README = ROOT / "README.md"
TLDR = ROOT / "tldr" / "datetime.md"
TLDR_TS = ROOT / "tldr" / "timestamp.md"
MAN = ROOT / "man" / "man1" / "datetime.1"
MAN_TS = ROOT / "man" / "man1" / "timestamp.1"

BEGIN = "<!-- BEGIN GENERATED: format-table -->"
END = "<!-- END GENERATED: format-table -->"
BEGIN_RE = r"<!-- BEGIN GENERATED: format-table[^>]*-->"
END_RE = r"<!-- END GENERATED: format-table[^>]*-->"

# Long options with curated tldr examples (key = canonical long name).
EXAMPLES = {
    "date": [
        'datetime -d "@2147483647" -u',
        'datetime -d "2020-01-02 03:04:05" +"%F %T"',
        'datetime -d "next Fri" +"%F %A"',
        'datetime -d \'TZ="America/Los_Angeles" 09:00 next Fri\'',
    ],
    "file": [
        'datetime -f dates.txt +"%F"',
        'printf "2020-01-02\\n" | datetime -f - +"%F"',
    ],
    "iso-8601": [
        "datetime -I",
        "datetime -Iseconds",
        "datetime --iso-8601=ns",
    ],
    "reference": ['datetime -r Makefile +"%F %T"'],
    "resolution": ["datetime --resolution"],
    "rfc-email": ["datetime -R"],
    "rfc-3339": ["datetime --rfc-3339=seconds"],
    "set": ['sudo datetime -s "2020-01-02 00:00:00"'],
    "utc": ['datetime -u +"%Y-%m-%d %H:%M:%S %Z"'],
    "debug": ['datetime --debug -d "2020-01-02"'],
    "timestamp": ["timestamp", "datetime --timestamp", 'TS=$(timestamp); echo "2.0.$TS"'],
}

# Long options that need no tldr example of their own.
SKIP = {"help", "version", "universal"}

SECTION_TITLES = {
    "date": "Parse a date string (epoch, ISO, relative)",
    "file": "Show time via file list",
    "iso-8601": "ISO-8601 output",
    "reference": "Show time of file modification",
    "resolution": "Show available timestamp resolution",
    "rfc-email": "RFC 5322 (email)",
    "rfc-3339": "RFC 3339",
    "set": "Set system time (requires root; otherwise warns)",
    "utc": "UTC / custom format",
    "debug": "Debug parsing (annotate to stderr)",
    "timestamp": "Timestamp (UTC YYYYMMDDhhmmssZ)",
}


def help_text() -> str:
    return subprocess.run([str(BIN), "--help"], check=True,
                          capture_output=True, text=True).stdout


def parse_legacy(help_out):
    """Return [(invocation, output)] from the 'Legacy output formats' block."""
    rows = []
    in_block = False
    for line in help_out.splitlines():
        if line.startswith("Legacy output formats"):
            in_block = True
            continue
        if in_block:
            if not line.strip():
                if rows:
                    break
                continue
            # Aligned rows: <names><2+ spaces><FMT>[  (note)].  FMT may
            # contain single spaces (e.g. 'YYYY-MM-DD hh:mm:ss'); the
            # column boundary is the run of 2+ spaces.
            m = re.match(r"^\s*(.+?\S)(?:\s{2,}(.+?))?(?:\s{2,}\(.*\))?\s*$",
                         line)
            if m:
                names, fmt = m.group(1), (m.group(2) or "").strip()
                if not fmt and names.strip().count(" ") >= 1:
                    # Column collapsed to a single space (longest-name
                    # row): last whitespace token is the format.
                    head, _, tail = names.rstrip().rpartition(" ")
                    if head:
                        names, fmt = head, tail
                rows.append((names, fmt))
                continue
            if rows:
                break
    return rows


def parse_long_options(help_out):
    """Long option names from the OPTIONS region of --help."""
    names = []
    for line in help_out.splitlines():
        m = re.match(r"^\s+(?:-\S+,\s*)?--([a-z0-9-]+)", line)
        if m:
            names.append(m.group(1))
    return sorted(set(names))


def gen_table(help_out) -> str:
    rows = parse_legacy(help_out)
    invs, outs = [], []
    for inv, out in rows:
        if inv == "(default)":
            invs.append("`datetime` (default)")
        elif not inv.startswith("-"):
            invs.append(f"`datetime {inv}`")
        else:
            invs.append(f"`datetime {inv}`")
        core, _, rest = out.partition(" (")
        outs.append(f"`{core}` ({rest}" if rest else f"`{core}`")
    w1 = max(len(s) for s in invs)
    w2 = max(len(s) for s in outs)
    lines = [
        "| Invocation" + " " * (w1 - 11) + " | Output" + " " * (w2 - 6) + " |",
        "|" + "-" * (w1 + 2) + "|" + "-" * (w2 + 2) + "|",
    ]
    lines += [f"| {i.ljust(w1)} | {o.ljust(w2)} |" for i, o in zip(invs, outs)]
    return "\n".join(lines)


def gen_tldr(help_out) -> str:
    longs = parse_long_options(help_out)
    legacy_rows = parse_legacy(help_out)
    legacy_longs = {inv.split(", ")[-1].lstrip("-").split()[0]
                    for inv, _ in legacy_rows if inv.startswith("-")}

    missing = [o for o in longs
               if o not in EXAMPLES and o not in SKIP and o not in legacy_longs]
    if missing:
        sys.exit(f"gen-docs: no curated tldr example for {missing}; "
                 f"add one to EXAMPLES in {Path(__file__).name}")

    out = [
        "# datetime",
        "",
        "> Small C99 `datetime` utility – prints or sets the system date and "
        "time. GNU `date` compatible, plus legacy formats. `--timestamp` "
        "prints UTC `YYYYMMDDhhmmssZ`.",
        "",
        "> See also: `date`.",
        "",
        "- Print current local time (default `YYYYMMDDhhmmss`):",
        "",
        "`datetime`",
        "",
        "- Print human-readable local time:",
        "",
        "`datetime -hr`",
        "",
        "- Show help:",
        "",
        "`datetime --help`",
        "",
        "- Show version and timezone:",
        "",
        "`datetime --version`",
        "",
        "- Set system time by positional operand (MMDDhhmm, requires root):",
        "",
        "`sudo datetime 09091100`",
    ]
    for opt in longs:
        if opt in EXAMPLES:
            out += ["", f"- {SECTION_TITLES[opt]}:", ""]
            out += [f"`{cmd}`" for cmd in EXAMPLES[opt]]

    out += ["", "- Legacy formats:", ""]
    for inv, outfmt in legacy_rows:
        if inv.startswith("-"):
            core = outfmt.split(" (")[0]
            out.append(f"`datetime {inv}`   # `{core}`")
    out.append("")
    return "\n".join(out)


def man_parity(help_out):
    """Long options missing from the man pages (both datetime and timestamp)."""
    man = MAN.read_text() if MAN.exists() else ""
    missing = [o for o in parse_long_options(help_out) if f"--{o}" not in man]
    # timestamp man must exist (typically .so include of datetime)
    if not MAN_TS.exists():
        missing.append("timestamp man page missing (man/man1/timestamp.1)")
    else:
        ts_text = MAN_TS.read_text()
        # .so include is okay – verify it points at datetime
        if "datetime" not in ts_text and ".so" not in ts_text:
            missing.append("timestamp man page does not reference datetime")
    return missing


def main():
    check = "--check" in sys.argv
    help_out = help_text()

    readme = README.read_text()
    if not re.search(BEGIN_RE, readme) or not re.search(END_RE, readme):
        sys.exit(f"gen-docs: {BEGIN} / {END} markers missing in README.md")
    new_table = gen_table(help_out)
    new_readme = re.sub(
        BEGIN_RE + r".*?" + END_RE,
        BEGIN + "\n" + new_table + "\n" + END,
        readme, flags=re.S)

    new_tldr = gen_tldr(help_out)
    missing_man = man_parity(help_out)

    problems = []
    if new_readme != readme:
        problems.append("README.md format table is stale")
    if TLDR.read_text() != new_tldr:
        problems.append("tldr/datetime.md is stale")
    if not TLDR_TS.exists():
        problems.append("tldr/timestamp.md is missing")
    else:
        ts_tldr = TLDR_TS.read_text()
        if "# timestamp" not in ts_tldr or "timestamp --help" not in ts_tldr:
            problems.append("tldr/timestamp.md is stale or incomplete")
    if missing_man:
        problems.append(f"man page missing options: {missing_man}")

    if check:
        if problems:
            sys.exit("check-docs FAILED:\n  - " + "\n  - ".join(problems))
        print("check-docs: README table, tldr page and man options are current")
        return

    README.write_text(new_readme)
    TLDR.write_text(new_tldr)
    print("gen-docs: regenerated README format table + tldr/datetime.md")
    if problems:
        print("gen-docs: WARNING " + "; ".join(problems))
    else:
        # also report timestamp artifacts are present
        if TLDR_TS.exists() and MAN_TS.exists():
            print("gen-docs: timestamp artifacts (man/timestamp.1, tldr/timestamp.md) present")


if __name__ == "__main__":
    main()
