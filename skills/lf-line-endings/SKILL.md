---
name: lf-line-endings
version: 1.0.20260813095857Z
description: >
  Enforces Unix-style (LF) line endings in every file you create or edit in
  this project. Never write Windows-style (CRLF) line endings.
---

# LF line endings skill

## Rule

Every text file you create or edit in this project — bash scripts, test files,
markdown files, Python files, config files — MUST use Unix line endings (LF,
`\n`). Never write CRLF (`\r\n`).

## Why

Files with CRLF line endings can behave unpredictably in bash (stray `\r`
characters break command substitution, `read`, and `grep` patterns), and the
project hook rejects them. The repository stores LF and the pre-commit hook
blocks commits while CRLF files exist in the working tree.

## When to apply

- When you create a new file with the write_file tool or a terminal command.
- When you edit an existing file.
- When you copy or move a file between systems.
- When a diff or `git status` shows line-ending noise (every line changed but
  no real content change).

## How to create LF files

- When writing a file, use `\n` as the newline in your content — never `\r\n`.
- When a tool or editor has a "line ending" or "EOL" option, choose LF (Unix).
- In Python, use `Path.write_bytes(...)` with `\n`-joined content or open files
  with `newline="\n"`. Avoid text mode writes that translate to CRLF on Windows.
- In bash, prefer `printf` over `echo` when generating multi-line content.

## How to fix a CRLF file

Convert line endings in place:

```bash
sed -i 's/\r$//' <file>
```

For multiple files (e.g. all tracked text files):

```bash
git ls-files | while read -r f; do
    [ -f "$f" ] || continue
    LC_ALL=C grep -q $'\r' "$f" && sed -i 's/\r$//' "$f"
done
```

## How to verify

Check a single file:

```bash
file <file>            # should NOT say "CRLF line terminators"
grep -c $'\r' <file>   # should print 0
```

Check the whole repo (working tree):

```bash
git ls-files --eol | grep 'w/crlf'   # should print nothing
```

The project hook (`_check_version`, run from the repo root) reports any file
with CR bytes as `[CRLF]` and exits 1 — the commit is blocked until the file is
converted. Run it before committing:

```bash
./_check_version
```

## Commit convention

Follow the version-commit convention for the file you changed (see the
`version-commit` skill). Do not include line-ending-only changes in the same
commit as content changes — convert first, then commit content separately when
possible.

## Verification checklist

- [ ] Created/edited files use LF only (no `\r` bytes).
- [ ] `git ls-files --eol` shows no `w/crlf` entries.
- [ ] `./_check_version` reports 0 errors.
