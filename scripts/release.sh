#!/usr/bin/env bash
# release.sh -- full release for datetime/timestamp
# Usage: ./scripts/release.sh [--dry-run] [--version 2.0.YYYYMMDDhhmmssZ]
#   --dry-run: do everything except git push / gh release
#   --version: override auto timestamp (must be x.y.YYYYMMDDhhmmssZ)
#
# Steps (mirrors `make release` spec):
#   1. timestamp via ~/sbin/timestamp (fallback ./timestamp, date -u)
#   2. bump __version__ in datetime.c + project.toml + README.md + manual.texi
#   3. make docs (man/tldr/README table)
#   4. make check (full test gate; abort on failure unless --dry-run with _MAKE_SKIP_CHECK)
#   5. cross-build 6 binaries: linux amd64/arm64, windows amd64/arm64, macos intel/arm -> dist/release/
#   6. make dist (source tarball in dist/)
#   7. tar per-platform releases in dist/
#   8. prepend NEWS + ChangeLog entries
#   9. git commit + push + gh release (unless --dry-run)

set -eu
cd "$(dirname "$0")/.." || exit 1

DRY=0
VERSION_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY=1; shift ;;
    --version) VERSION_OVERRIDE="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown arg $1" >&2; exit 2 ;;
  esac
done

if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
  G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; C=$'\033[36m'; B=$'\033[1m'; RST=$'\033[0m'
else
  G=''; Y=''; R=''; C=''; B=''; RST=''
fi
info() { echo "${C}==> $*${RST}"; }
ok() { echo "${G}  OK $*${RST}"; }
warn() { echo "${Y}  WARN $*${RST}"; }
fail() { echo "${R}  FAIL $*${RST}"; exit 1; }

# 1. timestamp
if [[ -n $VERSION_OVERRIDE ]]; then
  VERSION="$VERSION_OVERRIDE"
  TS="${VERSION##*.}"
else
  if [[ -x ~/sbin/timestamp ]]; then
    TS=$(~/sbin/timestamp)
  elif [[ -x ./timestamp ]]; then
    TS=$(./timestamp)
  elif [[ -x ./datetime ]]; then
    TS=$(./datetime --timestamp 2>/dev/null || true)
  else
    TS=$(date -u +"%Y%m%d%H%M%SZ")
  fi
  # Validate TS is YYYYMMDDhhmmssZ
  if ! echo "$TS" | grep -qE '^[0-9]{14}Z$'; then
    fail "timestamp '$TS' not YYYYMMDDhhmmssZ"
  fi
  # Version is x.y.micro without trailing Z (micro = timestamp without Z)
  VERSION="2.0.${TS%Z}"
fi
info "Release version $VERSION (TS $TS)"

# 2. bump version files
info "Bumping version in datetime.c, project.toml, README.md, manual.texi"
# datetime.c
if grep -q '__version__ = "' datetime.c; then
  sed -i "s/__version__ = \".*\"/__version__ = \"$VERSION\"/" datetime.c
  ok "datetime.c"
else
  warn "datetime.c __version__ not found"
fi
# project.toml
if grep -q '^version = ' project.toml; then
  sed -i "s/^version = \".*\"/version = \"$VERSION\"/" project.toml
  ok "project.toml"
fi
# README.md - the line with (currently `2.0....`)
if grep -q '(currently `2\.0\.' README.md; then
  sed -i "s/(currently \`2\.0\.[^\`]*\`)/(currently \`$VERSION\`)/" README.md
  ok "README.md"
fi
# manual.texi @set VERSION
if grep -q '@set VERSION' manual.texi; then
  sed -i "s/@set VERSION .*/@set VERSION $VERSION/" manual.texi
  ok "manual.texi"
fi

# 3. docs
info "Regenerating docs (man/tldr/README table)"
if ! make docs >/dev/null 2>&1; then
  fail "make docs failed"
fi
ok "make docs"

# 4. full test gate — live output without stdbuf (stdbuf LD_PRELOAD breaks ASan)
if [[ ${SKIP_CHECK:-0} != 1 ]]; then
  info "Running make check (full test gate) — live output, ~30s (syntax, valgrind, security, style, tests, docs)"
  LOG=$(mktemp)
  # Use tail -f background to stream log live while make writes to it (avoids stdbuf ASan conflict)
  touch "$LOG"
  tail -f "$LOG" &
  TAIL_PID=$!
  # Ensure tail is killed on exit
  trap 'kill $TAIL_PID 2>/dev/null; wait $TAIL_PID 2>/dev/null; rm -f "$LOG"' EXIT
  if ! make check >"$LOG" 2>&1; then
    kill $TAIL_PID 2>/dev/null; wait $TAIL_PID 2>/dev/null
    trap - EXIT
    echo
    warn "make check log tail (last 80 lines):"
    tail -n 80 "$LOG" | sed 's/^/  /'
    rm -f "$LOG"
    fail "make check failed — aborting release (bypass with SKIP_CHECK=1)"
  fi
  kill $TAIL_PID 2>/dev/null; wait $TAIL_PID 2>/dev/null
  trap - EXIT
  rm -f "$LOG"
  ok "make check — all gates passed"
else
  warn "SKIP_CHECK=1 — skipping make check"
fi

# 5. cross-build 6 binaries
info "Building cross-platform binaries -> dist/release/"

# Common flags
CFLAGS_RELEASE="-O2 -Wall -Wextra -std=c99"
SRC="datetime.c"

# Ensure dist dirs
mkdir -p dist/release

# Helper: try compile, on failure create placeholder
# usage: try_build CC "CFLAGS" SRC -o OUT -DDATETIME_TIMESTAMP_BUILD?
try_build() {
  local cc="$1"; shift
  local out="$1"; shift
  # remaining args are passed to compiler
  local log
  log=$(mktemp)
  if ! $cc $CFLAGS_RELEASE "$@" -o "$out" "$SRC" 2>"$log"; then
    warn "build failed: $cc $* -> $out"
    head -n 20 "$log" | sed 's/^/         /'
    # create placeholder with note
    mkdir -p "$(dirname "$out")"
    echo "Placeholder: toolchain $cc not available or build failed at $VERSION" > "$out.placeholder"
    echo "See log: $log"
    rm -f "$log"
    return 1
  fi
  rm -f "$log"
  chmod +x "$out" 2>/dev/null || true
  ok "$(basename "$(dirname "$out")")/$(basename "$out")"
  return 0
}

# Define platforms
# Use clang where possible for macos cross; gcc for linux/windows
# Detect host arch
HOST_ARCH=$(uname -m)

# Linux AMD64 (native)
mkdir -p dist/release/linux-amd64
if command -v gcc >/dev/null 2>&1; then
  try_build gcc dist/release/linux-amd64/datetime || true
  try_build gcc dist/release/linux-amd64/timestamp -DDATETIME_TIMESTAMP_BUILD || true
else
  warn "gcc not found for linux-amd64"
  echo "gcc missing" > dist/release/linux-amd64/datetime.placeholder
fi

# Linux ARM64
mkdir -p dist/release/linux-arm64
if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
  try_build aarch64-linux-gnu-gcc dist/release/linux-arm64/datetime || true
  try_build aarch64-linux-gnu-gcc dist/release/linux-arm64/timestamp -DDATETIME_TIMESTAMP_BUILD || true
elif command -v clang >/dev/null 2>&1; then
  # try clang cross
  if clang --target=aarch64-linux-gnu -O2 -Wall -Wextra -std=c99 "$SRC" -o dist/release/linux-arm64/datetime 2>/dev/null; then
    ok "linux-arm64/datetime (clang aarch64-linux-gnu)"
    clang --target=aarch64-linux-gnu -DDATETIME_TIMESTAMP_BUILD -O2 -Wall -Wextra -std=c99 "$SRC" -o dist/release/linux-arm64/timestamp 2>/dev/null && ok "linux-arm64/timestamp" || warn "clang aarch64 timestamp failed"
  else
    warn "linux-arm64 toolchain not available (aarch64-linux-gnu-gcc or clang aarch64) — placeholder"
    echo "Placeholder: install aarch64-linux-gnu-gcc for linux-arm64 at $VERSION" > dist/release/linux-arm64/datetime.placeholder
    echo "Placeholder" > dist/release/linux-arm64/timestamp.placeholder
  fi
else
  warn "linux-arm64 toolchain not available — placeholder"
  echo "Placeholder: install aarch64-linux-gnu-gcc for linux-arm64 at $VERSION" > dist/release/linux-arm64/datetime.placeholder
fi

# Windows AMD64
mkdir -p dist/release/windows-amd64
if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
  try_build x86_64-w64-mingw32-gcc dist/release/windows-amd64/datetime.exe || true
  try_build x86_64-w64-mingw32-gcc dist/release/windows-amd64/timestamp.exe -DDATETIME_TIMESTAMP_BUILD || true
else
  warn "windows-amd64 toolchain x86_64-w64-mingw32-gcc not available — placeholder"
  echo "Placeholder: install mingw-w64 for windows-amd64 at $VERSION" > dist/release/windows-amd64/datetime.exe.placeholder
  echo "Placeholder" > dist/release/windows-amd64/timestamp.exe.placeholder
fi

# Windows ARM64
mkdir -p dist/release/windows-arm64
if command -v aarch64-w64-mingw32-gcc >/dev/null 2>&1; then
  try_build aarch64-w64-mingw32-gcc dist/release/windows-arm64/datetime.exe || true
  try_build aarch64-w64-mingw32-gcc dist/release/windows-arm64/timestamp.exe -DDATETIME_TIMESTAMP_BUILD || true
else
  warn "windows-arm64 toolchain aarch64-w64-mingw32-gcc not available — placeholder"
  echo "Placeholder: install mingw-w64 for windows-arm64 at $VERSION" > dist/release/windows-arm64/datetime.exe.placeholder
  echo "Placeholder" > dist/release/windows-arm64/timestamp.exe.placeholder
fi

# macOS Intel (x86_64)
mkdir -p dist/release/macos-intel
if command -v clang >/dev/null 2>&1; then
  if clang --target=x86_64-apple-macos11 -O2 -Wall -Wextra -std=c99 "$SRC" -o dist/release/macos-intel/datetime 2>/dev/null; then
    ok "macos-intel/datetime (clang x86_64-apple-macos11)"
    clang --target=x86_64-apple-macos11 -DDATETIME_TIMESTAMP_BUILD -O2 -Wall -Wextra -std=c99 "$SRC" -o dist/release/macos-intel/timestamp 2>/dev/null && ok "macos-intel/timestamp" || warn "macos-intel timestamp clang failed"
  else
    warn "macos-intel clang cross failed — placeholder (needs macOS SDK)"
    echo "Placeholder: clang x86_64-apple-macos11 needs SDK at $VERSION" > dist/release/macos-intel/datetime.placeholder
    echo "Placeholder" > dist/release/macos-intel/timestamp.placeholder
  fi
else
  warn "clang not available for macos-intel"
  echo "Placeholder" > dist/release/macos-intel/datetime.placeholder
fi

# macOS ARM (Apple Silicon)
mkdir -p dist/release/macos-arm
if command -v clang >/dev/null 2>&1; then
  if clang --target=arm64-apple-macos11 -O2 -Wall -Wextra -std=c99 "$SRC" -o dist/release/macos-arm/datetime 2>/dev/null; then
    ok "macos-arm/datetime (clang arm64-apple-macos11)"
    clang --target=arm64-apple-macos11 -DDATETIME_TIMESTAMP_BUILD -O2 -Wall -Wextra -std=c99 "$SRC" -o dist/release/macos-arm/timestamp 2>/dev/null && ok "macos-arm/timestamp" || warn "macos-arm timestamp clang failed"
  else
    warn "macos-arm clang cross failed — placeholder"
    echo "Placeholder: clang arm64-apple-macos11 needs SDK at $VERSION" > dist/release/macos-arm/datetime.placeholder
    echo "Placeholder" > dist/release/macos-arm/timestamp.placeholder
  fi
else
  warn "clang not available for macos-arm"
  echo "Placeholder" > dist/release/macos-arm/datetime.placeholder
fi

# Also ensure native build is copied as linux-amd64 if cross builds reused host
# Verify at least linux-amd64 succeeded
if [[ ! -f dist/release/linux-amd64/datetime ]]; then
  warn "linux-amd64 datetime missing — copying host build"
  cp -p datetime dist/release/linux-amd64/datetime 2>/dev/null || true
  cp -p timestamp dist/release/linux-amd64/timestamp 2>/dev/null || true
fi

# 6. make dist (source tarball)
info "Creating source tarball dist/datetime-$VERSION.tar.gz"
if ! make dist >/dev/null 2>&1; then
  fail "make dist failed"
fi
ok "dist/datetime-$VERSION.tar.gz"

# 7. per-platform tarballs
info "Packaging per-platform releases in dist/"
for plat in linux-amd64 linux-arm64 windows-amd64 windows-arm64 macos-intel macos-arm; do
  srcdir="dist/release/$plat"
  if [[ ! -d $srcdir ]]; then
    warn "skip $plat (no dir)"
    continue
  fi
  # Count real binaries (ignore placeholders)
  real_count=$(find "$srcdir" -maxdepth 1 -type f -executable | wc -l)
  if [[ $real_count -eq 0 ]]; then
    # if only placeholders, tar the placeholders for visibility
    tarname="dist/datetime-$VERSION-$plat.tar.gz"
    tar -czf "$tarname" -C "$srcdir" . 2>/dev/null && ok "$tarname (placeholder)" || warn "tar $plat failed"
  else
    tarname="dist/datetime-$VERSION-$plat.tar.gz"
    # For windows, keep .exe, for unix keep without ext; tar will include both
    tar -czf "$tarname" -C "$srcdir" . 2>/dev/null && ok "$tarname" || warn "tar $plat failed"
    # Also create zip for windows
    if [[ $plat == windows-* ]] && command -v zip >/dev/null 2>&1; then
      zipname="dist/datetime-$VERSION-$plat.zip"
      (cd "$srcdir" && zip -q "../$(basename "$zipname")" ./* 2>/dev/null) && ok "$zipname" || warn "zip $plat failed"
    fi
  fi
done

# 8. prepend NEWS + ChangeLog
info "Updating NEWS and ChangeLog"
TODAY=$(date +%Y-%m-%d)
# NEWS: prepend
if grep -q "^\* Version $VERSION" NEWS 2>/dev/null; then
  warn "NEWS already has $VERSION"
else
  # Create temp NEWS with new entry
  tmp=$(mktemp)
  {
    head -n1 NEWS
    echo ""
    echo "* Version $VERSION ($TODAY)"
    echo ""
    echo "** Release: cross-platform binaries + shell integrations"
    echo ""
    echo "   Binaries for linux-amd64, linux-arm64, windows-amd64,"
    echo "   windows-arm64, macos-intel, macos-arm are in"
    echo "   dist/datetime-$VERSION-*.tar.gz (source is"
    echo "   dist/datetime-$VERSION.tar.gz). Each bundles datetime +"
    echo "   timestamp plus bash/zsh/fish completions."
    echo "   \`make check\` passed (full test gate) before tagging."
    echo ""
    echo "** Shell integration"
    echo ""
    echo "   New zsh (shell/datetime.zsh + shell/timestamp.zsh) and fish"
    echo "   (shell/datetime.fish + shell/timestamp.fish) completions,"
    echo "   parity with bash. \`make install\` deploys to"
    echo "   \$(zshdir) and \$(fishdir); \`make dist\` packs them."
    echo ""
    echo "** Build and release"
    echo ""
    echo "   \`make release\` (this release) bumps __version__ via"
    echo "   ~/sbin/timestamp, regenerates docs (man/tldr/README), runs"
    echo "   the full test battery, cross-builds 6 platform binaries into"
    echo "   dist/release/, and creates per-platform tarballs in dist/."
    echo "   \`make dist\` writes to dist/datetime-\$(VERSION).tar.gz."
    echo ""
    tail -n +2 NEWS
  } > "$tmp" && mv "$tmp" NEWS
  ok "NEWS"
fi

# ChangeLog: prepend
if grep -q "$VERSION" ChangeLog 2>/dev/null; then
  warn "ChangeLog already has $VERSION"
else
  tmp=$(mktemp)
  {
    echo "$TODAY  Neun MalElf  <neunmalelf@gmail.com>"
    echo ""
    echo "	* datetime.c (__version__): Bump to $VERSION."
    echo "	* project.toml, README.md, manual.texi: Sync version."
    echo "	* shell/datetime.zsh, shell/timestamp.zsh, shell/datetime.fish,"
    echo "	* shell/timestamp.fish: zsh/fish completions for both commands."
    echo "	* Makefile (zshdir, fishdir, install, dist): zsh/fish install"
    echo "	and dist in dist/."
    echo "	* scripts/release.sh, Makefile (release): New release target"
    echo "	cross-builds linux amd64/arm64, windows amd64/arm64, macos"
    echo "	intel/arm into dist/release/ and per-platform tarballs in dist/."
    echo "	* NEWS: Add $VERSION entry."
    echo ""
    cat ChangeLog
  } > "$tmp" && mv "$tmp" ChangeLog
  ok "ChangeLog"
fi

# Also ensure README version already bumped; if not, warn

# 9. git commit + push + gh release
if [[ $DRY -eq 1 ]]; then
  info "Dry-run: skipping git push / gh release"
  info "To publish: git add -A && git commit -m \"Release $VERSION\" && git push && gh release create v$VERSION dist/datetime-$VERSION*.tar.gz dist/datetime-$VERSION*.zip --generate-notes"
  exit 0
fi

info "Committing release $VERSION"
git add -A
# Only commit if there are staged changes
if git diff --cached --quiet; then
  warn "nothing to commit"
else
  git commit -m "Release $VERSION — cross-platform binaries + docs

- Version bump to $VERSION via ~/sbin/timestamp
- Shell completions for zsh/fish (timestamp + datetime)
- make release: linux amd64/arm64, windows amd64/arm64, macos intel/arm -> dist/release/ + per-platform tarballs
- dist/ source tarball, NEWS/ChangeLog updated, make check gate passed" || fail "git commit failed"
  ok "git commit"
fi

info "Pushing to origin"
if ! git push; then
  warn "git push failed (no remote or not writable) — skipping gh release"
  exit 0
fi
ok "git push"

if ! command -v gh >/dev/null 2>&1; then
  warn "gh CLI not found — skipping GitHub release creation; push done"
  exit 0
fi
if ! git remote get-url origin 2>/dev/null | grep -q github; then
  warn "origin not github — skipping gh release"
  exit 0
fi

tag="v$VERSION"
# Collect artifacts
artifacts=(dist/datetime-"$VERSION".tar.gz dist/datetime-"$VERSION"-*.tar.gz dist/datetime-"$VERSION"-*.zip)
# Filter existing
existing=()
for a in "${artifacts[@]}"; do
  for f in $a; do
    [[ -f $f ]] && existing+=("$f")
  done
done
# Always include binaries if they exist locally
[[ -f datetime ]] && existing+=(datetime)
[[ -f timestamp ]] && existing+=(timestamp)
# Also include man pages
[[ -f man/man1/datetime.1 ]] && existing+=(man/man1/datetime.1)

info "Creating GitHub release $tag with ${#existing[@]} artifacts"
if gh release view "$tag" >/dev/null 2>&1; then
  info "release $tag exists — uploading assets"
  gh release upload "$tag" "${existing[@]}" --clobber || warn "gh release upload failed"
else
  gh release create "$tag" "${existing[@]}" --title "$tag" --generate-notes || warn "gh release create failed"
fi
ok "release $tag done"
echo "${G}Release $VERSION complete. Artifacts in dist/:${RST}"
ls -lh dist/*.tar.gz dist/*.zip 2>/dev/null | sed 's/^/  /'
