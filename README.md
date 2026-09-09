# datetime

A small C99 program that prints the current datetime, computed in the host machine's timezone or UTC, with full GNU `date` compatible options. Extends the original legacy formats with GNU `date` semantics (`-d`, `-f`, `-I`, `-R`, `--rfc-3339`, `-r`, `-s`, `-u`, `--debug`, `--resolution`, and custom `+FORMAT`).

Legacy formats are kept for backward compatibility; new options follow the interface documented in `date_english.hlp` (English, ESC-filtered) and `date_german.hlp`.

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

Requirements:

- A C99 compiler (`gcc` recommended)
- `make`
- `valgrind` (only for the memory-leak check)

On Fedora, install them with:

```sh
sudo dnf install gcc make valgrind
```

On Debian/Ubuntu:

```sh
sudo apt install gcc make valgrind
```

Build and deploy the binary (auto-installs to `~/sbin`):

```sh
make          # builds datetime + timestamp and copies to ~/sbin/
```

The `all` target now depends on `install`, so `make` alone always deploys. Previously `all` only built locally and required a separate `make install` – that was why `~/sbin/datetime --help` stayed stale (old 13232-byte binary) while `./datetime` was new (44144-byte). Fixed by `Makefile:15` (`all: $(TARGETS) install`) and a robust `BUILD` fallback (`./timestamp` → `~/sbin/timestamp` → `date -u`).

The version is `1.3.<build>`, where `<build>` is a `YYYYMMDDhhmmssZ`
timestamp generated automatically before every compilation via `version.h:18` (`FORCE` + shell fallback), so it is always fresh even on a clean system without a pre-existing `~/sbin/timestamp`. See it with `./datetime --version` and `~/sbin/datetime --version` (now identical after `make`).

Run the checks (syntax + memory leaks + test suites):

```sh
make check
./tests/_test_datetime
python3 -m pytest tests/test_granular.py -v
```

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

## Help files

* `date_german.hlp` – German help, ESC sequences filtered (`72` ESC bytes removed, now `0`)
* `date_english.hlp` – English help, regenerated from `datetime --help` (ESC-filtered, `134` lines), identical in structure to GNU `date --help` plus legacy section

Both files contain no ANSI ESC sequences and are UTF-8.
