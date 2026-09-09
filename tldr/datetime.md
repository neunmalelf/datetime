# datetime

> Small C99 `datetime` / `timestamp` utility – prints or sets the system date and time. GNU `date` compatible, plus legacy formats. `timestamp` is a dedicated build (`-DTIMESTAMP`, UTC `YYYYMMDDhhmmssZ`).

> See also: `timestamp`, `date`.

- Print current local time (default `YYYYMMDDhhmmss`):

`datetime`

- Print human-readable local time:

`datetime -hr`

- Print UTC time with custom format:

`datetime -u +"%Y-%m-%d %H:%M:%S %Z"`

- Show help (134 lines, ESC-free):

`datetime --help`

- Show version and timezone:

`datetime --version`

- Parse a date string (epoch, ISO, relative):

`datetime -d "@2147483647" -u`
`datetime -d "2020-01-02 03:04:05" +"%F %T"`
`datetime -d "next Fri" +"%F %A"`

- Use TZ prefix for foreign timezone:

`datetime -d 'TZ="America/Los_Angeles" 09:00 next Fri'`

- ISO-8601 output:

`datetime -I`
`datetime -Iseconds`
`datetime --iso-8601=ns`

- RFC 5322 (email) and RFC 3339:

`datetime -R`
`datetime --rfc-3339=seconds`

- Show time via file list or file modification time:

`datetime -f dates.txt +"%F"`
`printf "2020-01-02\n" | datetime -f - +"%F"`
`datetime -r Makefile +"%F %T"`

- Show available timestamp resolution:

`datetime --resolution`

- Set system time (requires root; otherwise warns):

`sudo datetime -s "2020-01-02 00:00:00"`
`sudo datetime 09091100`

- Timestamp microversion (UTC `YYYYMMDDhhmmssZ`) for `2.0.<build>`:

`timestamp`
`datetime --timestamp`
`TS=$(timestamp); echo "2.0.$TS"`

- Debug parsing (annotate to stderr):

`datetime --debug -d "2020-01-02"`

- Legacy formats:

`datetime -cd` # calendar `YYYY-MM-DD`
`datetime -wd` # week `YYYY-Www-D`
`datetime -od` # ordinal `YYYY-DDD`
