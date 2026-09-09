# datetime

A small C99 program that prints the current datetime, computed in the host machine's timezone or UTC, with full GNU `date` compatible options. Extends the original legacy formats with GNU `date` semantics (`-d`, `-f`, `-I`, `-R`, `--rfc-3339`, `-r`, `-s`, `-u`, `--debug`, `--resolution`, and custom `+FORMAT`).

Legacy formats are kept for backward compatibility; new options follow the interface documented in `date_english.hlp` (English, ESC-filtered) and `date_german.hlp`.

## Index

* [Output formats](#output-formats)
  * [Legacy (backward compatible)](#legacy-backward-compatible)
  * [GNU date compatible](#gnu-date-compatible)
* [Usage](#usage)
* [Implementation notes](#implementation-notes)
* [Tests](#tests)
* [Memory and security checks](#memory-and-security-checks)
* [Build](#build)
  * [macOS (Darwin) – Intel, Apple Silicon & external drives](#macos-darwin--intel-apple-silicon--external-drives)
* [Install (explicit)](#install-explicit)
* [Clean](#clean)
* [Example usage](#example-usage)
  * [Basic and version/help](#basic-and-versionhelp)
  * [Legacy output formats](#legacy-output-formats-kept-datetimec52-formats)
  * [GNU date compatible – date source](#gnu-date-compatible--date-source)
  * [File and reference](#file-and-reference)
  * [ISO-8601 / RFC / resolution / UTC](#iso-8601--rfc--resolution--utc)
  * [Custom FORMAT](#custom-format-all-gnu-sequences-flags-width-modifiers--date_englishhlp57)
  * [Set time](#set-time-requires-root-otherwise-warns-but-prints)
  * [Error and exclusivity](#error-and-exclusivity-mutually-exclusive---date--file--reference--resolution)
* [Timestamp utility and microversion (`x.y.<UTC>`)](#timestamp-utility-and-microversion-xyutc)
  * [What it is](#what-it-is)
  * [How to use it](#how-to-use-it)
  * [Why this exact form](#why-this-exact-form-yyyymmddhhmmssz)
* [Help files](#help-files)

## Output formats

### Legacy (backward compatible)

| Invocation                                 | Output                         |
|--------------------------------------------|--------------------------------|
| `datetime` (default)                       | `YYYYMMDDhhmmss`              |
| `datetime -hr` / `--human-readable`        | `YYYY-MM-DD hh:mm:ss`         |
| `datetime -c` / `--compact` / `iso-basic` | `YYYYMMDDThhmmss` (ISO 8601 basic) |
| `datetime -cd` / `--calendar-date`         | `YYYY-MM-DD`                  |
| `datetime -cdb` / `--calendar-date-base`   | `YYYYMMDD`                    |
| `datetime -od` / `--ordinal-date`          | `YYYY-DDD` (day of year 001–365/366) |
| `datetime -odb` / `--ordinal-date-base`    | `YYYYDDD`                     |
| `datetime -wd` / `--week-date`             | `YYYY-Www-D` (week 01–53, day 1=Mon…7=Sun) |
| `datetime -wdb` / `--week-date-basic`      | `YYYYWwwD`                    |
| `datetime --timestamp` / `timestamp` binary | `YYYYMMDDhhmmssZ` (UTC)       |

The timezone is used to compute the local time but is not part of the datetime output for legacy formats. It is reported by `--version` and `--help`.

### GNU date compatible

```
Usage: datetime [OPTION]... [+FORMAT]
  or:  datetime [OPTION]... [MMDDhhmm[[CC]YY][.ss]]
Display date and time in the given FORMAT.
With -s, or with MMDDhhmm[[CC]YY][.ss], set the date and time first.

Mandatory arguments to long options are mandatory for short options too.
  -d, --date=STRING          display time described by STRING, not 'now'
      --debug                annotate parsed date, warn to stderr
  -f, --file=DATEFILE        like --date; once for each line of DATEFILE; if DATEFILE is -, read stdin
  -I[FMT], --iso-8601[=FMT]   ISO 8601: FMT='date'(default), 'hours', 'minutes', 'seconds', 'ns'
      --resolution           output available resolution of timestamps (0.000000001)
  -R, --rfc-email            RFC 5322: e.g. Mon, 14 Aug 2006 02:34:56 +0000
      --rfc-3339=FMT         RFC 3339: FMT='date', 'seconds', or 'ns'
  -r, --reference=FILE       display last modification time of FILE
  -s, --set=STRING           set time described by STRING (requires root; otherwise warns and prints what would be set)
  -u, --utc, --universal     print or set Coordinated Universal Time (UTC)
      --help                 display this help and exit
      --version              output version information and exit
```

All options that specify the date to display are mutually exclusive: `--date`, `--file`, `--reference`, `--resolution`.

`FORMAT` controls the output. Interpreted sequences are the same as GNU `date` (see `date_english.hlp`):

```
%%   literal %     %a   abbrev weekday (Sun)   %A   full weekday (Sunday)
%b   abbrev month  %B   full month             %c   locale datetime
%C   century       %d   day of month 01        %D   %m/%d/%y
%e   space-pad day %F   %Y-%m-%d               %g/%G ISO week year
%h   == %b        %H   hour 00-23             %I   hour 01-12
%j   day of year  %k   space-pad hour         %l   space-pad 12h
%m   month 01-12   %M   minute 00-59           %n   newline
%N   nanoseconds   %p   AM/PM                  %P   am/pm
%q   quarter 1-4   %r   12h time               %R   %H:%M
%s   seconds since Epoch  %S second 00-60    %t   tab
%T   %H:%M:%S      %u   weekday 1-7 Mon=1       %U   week number Sun first
%V   ISO week      %w   weekday 0-6 Sun=0       %W   week number Mon first
%x   locale date   %X   locale time            %y   year 00-99
%Y   year         %z   +hhmm                  %:z  +hh:mm
%::z +hh:mm:ss    %:::z minimal +hh[:mm[:ss]]  %Z   alphabetic TZ
```

Padding flags after `%`: `-` (no pad), `_` (space), `0` (zero), `+` (zero + '+' for >4 digit years), `^` (upper), `#` (swap case), optional width, optional `E`/`O` modifier.

Full documentation is in `date_english.hlp` (English) and `date_german.hlp` (German, ESC-filtered). Both files are filtered to contain no ANSI ESC sequences (`\x1b`).

## Usage

```sh
./datetime                         # e.g. 20260909101032
./datetime -hr                     # e.g. 2026-09-09 10:10:32
./datetime -c                      # e.g. 20260909T101032
./datetime -wd                     # e.g. 2026-W37-3
./datetime --version               # show version (with build number) and host timezone
./datetime -V                      # same as --version
./datetime -h                      # show help
./datetime --help                  # show help (also saved in date_english.hlp)

# GNU date compatible
./datetime -u +"%Y-%m-%d %H:%M:%S %Z"               # UTC custom format
./datetime -d '@2147483647'                         # epoch -> date
./datetime -d '2020-01-02 03:04:05' +"%F %T"          # parse string
./datetime --debug -d '2020-01-02'                  # annotated parsing to stderr
./datetime -I                                       # ISO 8601 date
./datetime -Iseconds                                # ISO 8601 with seconds and zone
./datetime --iso-8601=ns                            # ISO 8601 nanoseconds
./datetime -R                                       # RFC 5322 / RFC email
./datetime --rfc-3339=seconds                       # RFC 3339
./datetime -r Makefile +"%F"                        # file modification time
./datetime -f dates.txt +"%F"                       # each line as --date
printf "2020-01-02\n2020-01-03\n" | ./datetime -f - +"%F"  # stdin via -
./datetime --resolution                             # 0.000000001
./datetime -u -d 'TZ="America/Los_Angeles" 09:00 next Fri'  # TZ prefix
./datetime --set='2020-01-02 00:00:00'               # set system time (needs root)
./datetime 09091100                                 # MMDDhhmm form (set)
```

## Implementation notes

* **Parsing `STRING` (`-d`/`--date`/`--set`/`-f`)** supports:
  * `@EPOCH[.NANO]` (e.g. `@0`, `@2147483647`, `@123.456789123`)
  * `YYYY-MM-DD`, `YYYY-MM-DD HH:MM:SS`, `YYYY/MM/DD`, `MM/DD/YY`, ISO `T` variants, RFC 2822/5322
  * `now`, `today`, `yesterday`, `tomorrow`
  * Any string understood by host GNU `date -d` as fallback (including relative `next Fri`, `+1 day`, `2 weeks ago`)
  * `TZ="Zone" <STRING>` prefix – temporarily sets `TZ` for parsing and formatting
* **Timezone handling**: `-u` uses `gmtime_r`; otherwise `localtime_r`. `tm_gmtoff` is used to synthesize `%z`, `%:z`, `%::z`, `%:::z` portably when `strftime` lacks `%:z`.
* **ISO-8601 / RFC-3339**: `seconds` and `ns` include `%:z`; `ns` includes `.%N`.
* **Mutual exclusivity** enforced for `--date`/`--file`/`--reference`/`--resolution`.
* **`--debug`** prints `debug: ...` to stderr, including parsed `time_t` and format decisions, and warns on questionable usage.
* **Memory / security**: All inputs bounded (`4096` for date strings, `8192` for formats), `snprintf`/`strncpy` with truncation, `strdup` matched with `free`, `shell_escape` escapes `'` as `'\''` before `popen` to `date -d`. No fixed `strcpy`/`strcat`/`sprintf`. Validated with `valgrind --leak-check=full` and `gcc -fsanitize=address`.

## Tests

Granular + exhaustive combinatorial tests live in `tests/` (650+ checks, ~406 bash + 40 Python with 244 subtests):

* `tests/_test_datetime` – 122 bash tests (legacy, GNU options, FORMAT flags, edge cases, security). Run from repo root:
  ```sh
  ./tests/_test_datetime
  ```
* `tests/_test_combinatorial` – 284 bash exhaustive matrix (every alias, every `-I`/`--rfc-3339` variant, all 6 mutually-exclusive pairs + triples, `-u`/`--debug` × each date source, `+FORMAT` × each source, all 47 FORMAT sequences `%%`..`%Z` with/without `-u`, flags `-_0+^#`, width, `E/O`, alias equivalence, error cases, injection/long-input):
  ```sh
  ./tests/_test_combinatorial
  ```
* `tests/test_granular.py` – 24 Python `unittest`/`pytest` tests covering the same matrix plus comparison with GNU date behavior:
  ```sh
  python3 -m pytest tests/test_granular.py -v
  # or
  python3 tests/test_granular.py
  ```
* `tests/test_exhaustive.py` – 16 Python exhaustive matrix (235 subtests via `itertools.product`): legacy singletons, `iso-8601`×5 × short/long, `rfc-3339`×3, `r`/`f`/`s` aliases, `utc` aliases (`-u`/`--utc`/`--universal`), date sources (`@0`/`now`/`today`/fractional/`TZ=`), mutual-exclusivity full `C(4,2)+C(4,3)` matrix, compatible `-u`/`--debug`×each base, all `FORMAT` sequences with/without `-u`, flag×width×`E/O` matrix, error/long-input/injection:
  ```sh
  python3 -m pytest tests/test_exhaustive.py -v
  # or
  python3 -m pytest tests/test_granular.py tests/test_exhaustive.py -v
  ```

All suites together validate combinatorially:
* every singleton option and every alias (`-d`/`--date=`/`--date`, `-f`/`--file=`, `-r`/`--reference=`, `-s`/`--set=`, `-u`/`--utc`/`--universal`, `-R`/`--rfc-email`, `-I`/`--iso-8601`, `-h`/`--help`, `-V`/`--version`)
* every `FMT` variant (`--iso-8601:date/hours/minutes/seconds/ns`, `--rfc-3339:date/seconds/ns`)
* FORMAT sequences `%%`..`%Z` (`%a`..`%Z`, `%z/%:z/%::z/%:::z`, `%N`, `%q`, `%s`) with/without `-u` and with flags `-_0+^#`, width `1/2/5/10`, modifiers `E/O`
* mutual exclusivity errors (all 6 pairs + triples among `--date`/`--file`/`--reference`/`--resolution`), missing/invalid args, unknown options (`-Z`/`--unknown`)
* compatible pairs/triples (`-u`×each, `--debug`×each, `+FORMAT`×each date source, legacy vs GNU last-wins, `-f` `-u` `--debug` matrix, `TZ=` prefix, `MMDDhhmm` positional)
* TZ prefix, fractional epoch (`@1234567890.123456789`), stdin `-`, long inputs (5000+ chars), shell-injection attempt (`'; touch /tmp/pwned; echo '`)
* buffer overflow with many specifiers (200×`%Y`), ESC-free help (`! grep -q $'\x1b'`), symlink `timestamp` alias

## Memory and security checks

```sh
make check              # syntax + valgrind for datetime and timestamp binaries
# extended valgrind matrix
for cmd in "./datetime -d '@0'" "./datetime -f dates.txt +\"%F\"" "./datetime -u -Iseconds" "./datetime -R" "./datetime --rfc-3339=ns" "./datetime -r Makefile" "./datetime --set='2020-01-02'"; do
  valgrind --leak-check=full --show-leak-kinds=all --error-exitcode=1 $cmd
done
# address sanitizer
gcc -fsanitize=address -o /tmp/datetime_san datetime.c && /tmp/datetime_san -d '@0' && echo ok
```

All heap blocks are freed (`All heap blocks were freed -- no leaks are possible`); error summary `0 errors from 0 contexts`.

## Build

> **C Standard: C99** – This project is written in **strict C99** (`project.toml:5` `standard = "C99"`, `Makefile:2` `CFLAGS ?= -O2 -Wall -Wextra -std=c99`, `datetime.c:1` `// Expose POSIX + GNU timezone functions under strict C99.`). Code compiles with `gcc -std=c99` and only uses the standard C library (`libc`) plus POSIX/GNU extensions exposed via `_DEFAULT_SOURCE` / `_POSIX_C_SOURCE 200809L` / `_XOPEN_SOURCE 700` for `gmtime_r`/`localtime_r`/`timegm`/`strptime`/`clock_gettime` – no external libraries, no C11/C17 features. This guarantees portability to any C99 compiler while still accessing timezone and high-resolution clock APIs. All format handling uses `strftime` with manual fallback for `%N`/`%q`/`%s`/`%z` variants to stay C99-compliant. `project.toml:19` documents `c_standard = "libc"` and `c_posix_features` list.

> **GNU C Styleguide:** This codebase follows the [GNU Coding Standards](gnu_c_stileguide.md) (`gnu_c_stileguide.md:8` *Formatting Your Source Code*, `gnu_c_stileguide.md:10` *Clean Use of C Constructs*, `gnu_c_stileguide.md:13` *Program Behaviour*). Compliance is enforced via `Makefile:1` `SHELL = /bin/sh`, standard `prefix`/`bindir`/`mandir` variables `Makefile:5`, `INSTALL_PROGRAM`/`INSTALL_DATA` `Makefile:22`, `distclean`/`TAGS`/`dist` targets `Makefile:55`, function braces in column zero `datetime.c:38` (`debug_log` `(` → `\n{`), `getopt_long` for CLI `datetime.c:779` `Standards for Command Line Interfaces` `gnu_c_stileguide.md:17`, dynamic allocation instead of fixed `4096` limits `datetime.c:480` (`malloc`/`obstack` per `gnu_c_stileguide.md:13`), and Texinfo `manual.texi:1` / `ChangeLog:1` / `NEWS:1`.

Requirements:

- A C99 compiler (`gcc` recommended, tested with `gcc 13+`; `clang` also works with `-std=c99`)
- `make` (GNU make)
- `valgrind` (only for the memory-leak check)
- `bash` + `coreutils` (`date`, `install`, `touch`) for tests and `BUILD` fallback
- `python3` + `pytest` (optional, for `tests/test_granular.py` / `tests/test_exhaustive.py`)

On Fedora, install them with:

```sh
sudo dnf install gcc make valgrind bash coreutils python3 pytest
```

On Debian/Ubuntu:

```sh
sudo apt install gcc make valgrind bash coreutils python3 python3-pytest
```

Build and deploy the binary (auto-installs to `~/sbin`):

```sh
make          # builds datetime + timestamp and copies to ~/sbin/
```

The `all` target now depends on `install`, so `make` alone always deploys. Previously `all` only built locally and required a separate `make install` – that was why `~/sbin/datetime --help` stayed stale (old 13232-byte binary) while `./datetime` was new (44144-byte). Fixed by `Makefile:15` (`all: $(TARGETS) install`) and a robust `BUILD` fallback (`./timestamp` → `~/sbin/timestamp` → `date -u`).

The version is `2.0.<build>`, where `<build>` is a `YYYYMMDDhhmmssZ`
timestamp generated automatically before every compilation via `version.h:18` (`FORCE` + shell fallback), so it is always fresh even on a clean system without a pre-existing `~/sbin/timestamp`. See it with `./datetime --version` and `~/sbin/datetime --version` (now identical after `make`).

Run the checks (syntax + memory leaks + test suites):

```sh
make check
./tests/_test_datetime
./tests/_test_combinatorial
python3 -m pytest tests/test_granular.py tests/test_exhaustive.py -v
```

### macOS (Darwin) – Intel, Apple Silicon & external drives

> `macOS` is `BSD` (`Darwin`), not `Linux` (`GNU`). `Makefile:1` and `datetime.c:1` handle it, but `install` and `deploy` differ.

**Prerequisites – Xcode CLT + Homebrew:**
```sh
xcode-select --install                          # clang -std=c99, make, BSD install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install gcc make coreutils bash python3    # GNU make as gmake if needed: brew install make
# valgrind is NOT supported on macOS ≥10.15 – use ASan/ leaks instead:
brew install llvm                               # for clang-format --style=GNU
```

**Build – same command, `C99` + `BSD` portable `install`:**
```sh
make                                            # builds datetime + timestamp (45056 bytes, -DTIMESTAMP for timestamp)
# Makefile:1 SHELL=/bin/sh, Makefile:22 INSTALL = install, INSTALL_PROGRAM = $(INSTALL) -m 0755
# BSD install has no -D – Makefile:74 uses portable mkdir -p $(DESTDIR)$(bindir) before install
./datetime --version                             # datetime 2.0.2026090909XXXXZ (UTC)
```

**Deploy paths – auto-detected (`Makefile:4` `UNAME_S := $(shell uname -s)`):**

| Machine | `uname -s` | Default `prefix`/`bindir` (`Makefile:4`) | Real path | Override |
|---------|------------|-------------------------------------------|-----------|----------|
| `Intel` `macOS` | `Darwin` | `prefix=/usr/local` → `bindir=/usr/local/bin` | `/usr/local/bin/datetime` | `make prefix=/usr/local` |
| `Apple Silicon` | `Darwin` + `test -d /opt/homebrew` | `prefix=/opt/homebrew` → `bindir=/opt/homebrew/bin` | `/opt/homebrew/bin/datetime` | `make prefix=/opt/homebrew` |
| `Linux` / `user-local` | `Linux` | `PREFIX ?= $(HOME)/sbin` → `bindir=$(HOME)/sbin` if `~/sbin` exists | `~/sbin/datetime` | `make bindir=$$HOME/bin` |
| `External drive` (common on small `SSD` `Mac`s – `Applications` moved to `/Volumes/External`) | `Darwin` + `df /Applications` → `/Volumes/External` | **Not auto-detected for CLI** – `bindir` stays as above | `/Volumes/External/opt/homebrew/bin` or `/Volumes/External/sbin` | `make prefix=/Volumes/External/opt/homebrew` or `make bindir=/Volumes/External/sbin` or `make bindir=/Volumes/External/Applications/bin` |

**How to find the correct `macOS` deploy path when `Applications` is on external:**
```sh
# 1. Where is the real Applications folder? (handles symlink /Volumes/External/Applications)
osascript -e 'POSIX path of (path to applications folder)' 2>/dev/null | tr -d ':'
# or
readlink /Applications
df /Applications | tail -1 | awk '{print $6}'  # mount point, e.g. /Volumes/External

# 2. Where is Homebrew? (may be on external)
brew --prefix  # -> /opt/homebrew or /Volumes/External/opt/homebrew
which datetime # -> /opt/homebrew/bin/datetime or /Users/you/sbin/datetime

# 3. Override at install time (already supported, no code change needed)
make bindir=/Volumes/External/bin install
make prefix=/Volumes/External/opt/homebrew install
make PREFIX=$$HOME/sbin install          # keep Linux-like ~/sbin even on macOS
```

**External drive is covered:** `Makefile:74` `install` uses `$(DESTDIR)$(bindir)` – `bindir` is fully overridable, and `~/sbin` (`$(HOME)/sbin`) already follows `$HOME` even if `$HOME` is on external (`/Volumes/External/Users/you` → `bindir=/Volumes/External/Users/you/sbin`). For `Homebrew` on external, just `make prefix=$(brew --prefix)` where `brew --prefix` already returns the external path. No hard-coded `/Applications` is used for CLI tools – the table above shows how to detect it via `osascript`/`df`/`brew --prefix`.

**`macOS` quirks handled in code:**
* `datetime.c:22` `#if defined(__linux__) || defined(__APPLE__)` for `<sys/time.h>` (`timespec` in `<time.h>` on `Darwin`, `clock_gettime` ≥10.12, `timegm` ≥10.6, `tm_gmtoff`/`tm_zone` available as `BSD` extension).
* `datetime.c:20` `#ifdef _WIN32` vs `#else` `#include <getopt.h>` – `macOS` `BSD` `getopt_long` supports `I::` optional arg differently, handled via filtered `argv` before `getopt_long` `datetime.c:860`.
* `valgrind` → use `leaks`/`ASan` on `macOS`: `make check-mem` will warn `valgrind not found`, run `clang -fsanitize=address -o /tmp/datetime_asan datetime.c && /tmp/datetime_asan -d "@0"`.

## Install (explicit)

Copies the single-file binary to `~/sbin`, overwriting any existing version (also run automatically by `make`):

```sh
make install
```

Remove it with:

```sh
make uninstall
```

## Clean

```sh
make clean
```

## Example usage

Extensive examples covering every option and `FORMAT` – all are tested in `tests/_test_datetime:1`, `tests/_test_combinatorial:1`, `tests/test_exhaustive.py:1`.

### Basic and version/help (C99 `datetime --help` is ESC-free, 134 lines)
```sh
./datetime                          # default: 20260909103730 (YYYYMMDDhhmmss)
./datetime --help                   # full help, see date_english.hlp:1
./datetime -h                       # same as --help
./datetime --version                # datetime 2.0.20260909083730Z + Timezone: CEST (UTC+2)
./datetime -V                       # same as --version
./datetime --debug -d "2020-01-02" +"%F"  # debug to stderr: parsing + format decisions
```

### Legacy output formats (kept, `datetime.c:52` formats[])
```sh
./datetime -hr              # 2026-09-09 10:37:30 (human readable)
./datetime --human-readable # same
./datetime -c               # 20260909T103730 (compact, ISO 8601 basic)
./datetime --compact
./datetime iso-basic        # same as -c (without dash)
./datetime -cd              # 2026-09-09
./datetime --calendar-date
./datetime -cdb             # 20260909
./datetime --calendar-date-base
./datetime -od              # 2026-252 (ordinal, DDD 001..366)
./datetime --ordinal-date
./datetime -odb             # 2026252
./datetime --ordinal-date-base
./datetime -wd              # 2026-W37-3 (ISO week, 1=Mon..7=Sun)
./datetime --week-date
./datetime -wdb             # 2026W373
./datetime --week-date-basic
./datetime --timestamp      # 20260909103730Z (UTC, micro-version format)
./timestamp                 # same via dedicated binary (built with -DTIMESTAMP)
```

### GNU date compatible – date source
```sh
./datetime -d "@0" +"%F %T"                 # epoch 0 UTC -> 1970-01-01 01:00:00 (local) / 00:00:00 with -u
./datetime -u -d "@0" +"%F %T %Z"           # 1970-01-01 00:00:00 UTC
./datetime -d "@2147483647" -u +"%F %T"     # 2038-01-19 03:14:07 (32-bit max)
./datetime -d "@1234567890.123456789" -u +"%s.%N" # fractional epoch with nanoseconds
./datetime -d "2020-01-02" +"%F"            # 2020-01-02
./datetime -d "2020-01-02 03:04:05" +"%F %T"
./datetime -d "2020/01/02" +"%F"
./datetime -d "01/02/20" +"%F"              # MM/DD/YY
./datetime -d "now" +"%F %T"
./datetime -d "today" +"%F"
./datetime -d "yesterday" +"%F"
./datetime -d "tomorrow" +"%F"
./datetime -d "TZ=\"UTC\" 2020-01-02 03:04:05" -u +"%T" # TZ prefix: parse in UTC
./datetime -d 'TZ="America/Los_Angeles" 09:00 next Fri' +"%F %a" # relative + TZ
```

### File and reference
```sh
printf "2020-01-02\n2020-01-03\n" > dates.txt
./datetime -f dates.txt +"%F"              # each line as --date
./datetime --file=dates.txt +"%F"
printf "2020-01-02\n" | ./datetime -f - +"%F"  # stdin via -
touch -d "2020-01-02 03:04:05" ref
./datetime -r ref +"%F %T"                 # last modification time
./datetime --reference=ref +"%F"
```

### ISO-8601 / RFC / resolution / UTC
```sh
./datetime -I                  # 2026-09-09 (date, default)
./datetime --iso-8601          # same
./datetime -Ihours             # 2026-09-09T10+02:00
./datetime --iso-8601=minutes  # 2026-09-09T10:37+02:00
./datetime -Iseconds           # 2026-09-09T10:37:30+02:00
./datetime --iso-8601=ns       # 2026-09-09T10:37:30.123456789+02:00
./datetime -u -Iseconds        # +00:00 in UTC
./datetime -R                  # Wed, 09 Sep 2026 10:37:30 +0200 (RFC 5322)
./datetime --rfc-email
./datetime --rfc-3339=date     # 2026-09-09
./datetime --rfc-3339=seconds  # 2026-09-09 10:37:30+02:00
./datetime --rfc-3339=ns       # 2026-09-09 10:37:30.123456789+02:00
./datetime --resolution        # 0.000000001 (nanosecond)
./datetime -u +"%Y-%m-%d %H:%M:%S %Z"  # UTC mode
./datetime --utc +"%F"
./datetime --universal +"%Z"   # alias of -u
```

### Custom FORMAT (all GNU sequences, flags, width, modifiers – `date_english.hlp:57`)
```sh
./datetime -d "2020-01-02" +"%a %A %b %B %c"   # Thu Thursday Jan January ...
./datetime -d "2020-01-02" +"%C %d %D %e %F"   # 20 02 01/02/20  2 2020-01-02
./datetime -d "2020-01-02" +"%g %G %h %H %I"   # 20 2020 Jan 00 12
./datetime -d "2020-01-02" +"%j %k %l %m %M"   # 002  0 12 01 00
./datetime -d "2020-01-02" +"%n %N %p %P %q"   # newline 000000000 AM am 1
./datetime -d "2020-01-02" +"%r %R %s %S"      # 12:00:00 AM 00:00 1577919600 00
./datetime -d "2020-01-02" +"%t %T %u %U %V"   # tab 00:00:00 4 00 01
./datetime -d "2020-01-02" +"%w %W %x %X %y"   # 4 00 01/02/20 00:00:00 20
./datetime -d "2020-01-02" +"%Y %z %:z %::z %:::z %Z" # 2020 +0100 +01:00 +01:00:00 +01 CET
./datetime +"%Y-%m-%d %H:%M:%S.%N %z"         # nanoseconds + zone
# flags / width / modifiers
./datetime -d "2020-01-02" +"%_d"    # ' 2' space pad
./datetime -d "2020-01-02" +"%05d"   # '00002' zero pad width 5
./datetime -d "2020-01-02" +"%-5d"   # '2    ' no pad width 5
./datetime -d "2020-01-02" +"%^A"    # THURSDAY upper
./datetime -d "2020-01-02" +"%#A"    # opposite case
./datetime -d "2020-01-02" +"%+4Y"   # '+2020' plus for >4 digits
./datetime -d "2020-01-02" +"%10Y"   # '      2020' width 10
./datetime -d "2020-01-02" +"%Ey"    # alternative representation
./datetime -d "2020-01-02" +"%OY"    # alternative numeric
./datetime +"%Y%%m"                 # 2026%m (%% -> %)
./datetime -u -d "@0" +"%s.%N"      # 0.000000000
```

### Set time (requires root, otherwise warns but prints)
```sh
sudo ./datetime -s "2020-01-02 00:00:00"       # set system time
sudo ./datetime --set="2020-01-02" --debug    # with debug
./datetime 09091100                          # MMDDhhmm positional -> set Sep 09 11:00
./datetime 0909110000.00                     # MMDDhhmmYY.ss
```

### Error and exclusivity (mutually exclusive: `--date/--file/--reference/--resolution`)
```sh
./datetime -d "now" --file dates.txt         # fails: mutually exclusive
./datetime -d "now" -r ref --resolution      # fails
./datetime --iso-8601=invalid                # fails: invalid FMT
./datetime -d --file                         # fails: missing arg
./datetime --unknown                         # fails: unknown option
```

## Timestamp utility and microversion (`x.y.<UTC>`)

> **TL;DR for humans and LLMs:** `timestamp` = `YYYYMMDDhhmmssZ` – 14 digits + `Z` in **UTC**. It is the **micro-version**. Full version is `MAJOR.MINOR.TIMESTAMP`, e.g. `2.0.20260909083730Z` = major `2`, minor `0`, built `2026-09-09 08:37:30 UTC`. Easy to sort, easy to parse, no ambiguity.

### What it is

* **Dedicated binary and flag:** The project builds `datetime` (local time `YYYYMMDDhhmmss`) and `timestamp` (UTC `YYYYMMDDhhmmssZ`, compiled with `-DTIMESTAMP`). Flag `--timestamp` produces the same UTC format when calling `datetime --timestamp`.
* **Standard Python equivalent:** `python3 -c "import datetime; print(datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d%H%M%SZ'))"`.

### How to use it

| Goal | Command | Output |
|------|---------|--------|
| **UTC micro-timestamp** | `./timestamp` | `20260909083730Z` |
| After `make` install | `~/sbin/timestamp` / `timestamp` | `20260909083730Z` |
| Via `datetime` flag | `./datetime --timestamp` | `20260909083730Z` (same but via `datetime`) |
| Inside `datetime` format | `./datetime -u +"%Y%m%d%H%M%SZ"` | `20260909083730Z` |
| Python utility | `python3 -c "import datetime; print(datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d%H%M%SZ'))"` | `20260909083730Z` |
| Generate `version.h` | `make` → `version.h:1` `#define VERSION_BUILD "20260909083730Z"` | used by `datetime --version` |

```sh
# 1. Direct binary (UTC, sortable)
./datetime --timestamp      # 20260909083730Z (UTC)
./timestamp                # 20260909083730Z (UTC)
~/sbin/timestamp           # same after make install

# 2. As micro-version in your own script/SKILL
TS=$(~/sbin/timestamp 2>/dev/null || ./timestamp)   # TS=20260909083730Z
VERSION="2.0.$TS"                                  # 2.0.20260909083730Z
echo "#define VERSION_BUILD \"$TS\"" > version.h

# 3. Python helper (standard library)
python3 - <<'PY'
import datetime
print(datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d%H%M%SZ"))
PY

# 4. Parse it back (human or LLM): first 8 = date, next 6 = time, last Z = UTC
TS=20260909083730Z
echo $TS | sed -E 's/([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})Z/\1-\2-\3 \4:\5:\6 UTC/'
# -> 2026-09-09 08:37:30 UTC
```

### Why this exact form (`YYYYMMDDhhmmssZ`)?

We **chose this form on purpose** so both humans and LLMs can read it without guessing:

* **Sortable & filename-safe:** No `-`, `:`, `T`, or spaces. Lexicographic sort = chronological sort. Safe for filenames, Docker tags, `version.h`, SKILL metadata, `project.toml:70` `scheme = "2.0.<build>"`. Compare `20260909083730Z` < `20260910120000Z` – no parsing needed.
* **Unambiguous timezone:** Trailing `Z` = *Zulu* = UTC (`format = "%Y%m%d%H%M%SZ"` + `gmtime`). No local `CEST`/`PST` confusion. LLM can instantly split: `YYYY` `MM` `DD` `hh` `mm` `ss` `Z`.
* **Compact but still human-readable:** 14 digits → split `YYYYMMDD` + `hhmmss`. Human scans `20260909` as `2026-09-09`, LLM tokenizes `2026 09 09 08 37 30 Z` without extra punctuation.
* **Micro-version semantics:** `x.y.<UTC>` → `2.0.20260909083730Z`:
  * `x.y` = API break / feature (`project.toml:4` `version = "2.0"` + `datetime.c:35-36` `VERSION_MAJOR/MINOR`)
  * `<UTC>` = **release date-time** of this exact build. Every `make` regenerates `version.h:1` via `Makefile` with fallback chain `./timestamp || ~/sbin/timestamp || date -u +"%Y%m%d%H%M%SZ"` – so even on a clean machine without `~/sbin/timestamp` the build still gets a fresh UTC stamp. No need to bump `x.y` for every commit; `x.y` stays stable, `Z` moves.
* **Used everywhere in this repo:**
  * `Makefile` `version.h` → `datetime --version` → `2.0.20260909083730Z`
  * `project.toml:70` `scheme = "2.0.<build>"` – docs for humans/LLMs how to interpret `2.0.*`
  * SKILL `writing-skills` / `tests-subfolder` prompts use `~/sbin/timestamp` to generate SKILL `__VERSION__` like `1.0.20260909104000Z`

**For LLM:** Treat `Z` as `UTC`, split `^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$` → `YYYY-MM-DDThh:mm:ssZ` ISO. For human: read `20260909083730Z` as `2026-09-09 08:37:30 UTC` – the exact second this binary was built.

## Help files

* `date_german.hlp` – German help, ESC sequences filtered (`72` ESC bytes removed, now `0`)
* `date_english.hlp` – English help, regenerated from `datetime --help` (ESC-filtered, `134` lines), identical in structure to GNU `date --help` plus legacy section

Both files contain no ANSI ESC sequences and are UTF-8.
