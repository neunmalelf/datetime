# datetime

> Small C99 `datetime` utility – prints or sets the system date and time. GNU `date` compatible, plus legacy formats. `--timestamp` prints UTC `YYYYMMDDhhmmssZ`.

> See also: `date`.

- Print current local time (default `YYYYMMDDhhmmss`):

`datetime`

- Print human-readable local time:

`datetime -hr`

- Show help:

`datetime --help`

- Show version and timezone:

`datetime --version`

- Set system time by positional operand (MMDDhhmm, requires root):

`sudo datetime 09091100`

- Parse a date string (epoch, ISO, relative):

`datetime -d "@2147483647" -u`
`datetime -d "2020-01-02 03:04:05" +"%F %T"`
`datetime -d "next Fri" +"%F %A"`
`datetime -d 'TZ="America/Los_Angeles" 09:00 next Fri'`

- Debug parsing (annotate to stderr):

`datetime --debug -d "2020-01-02"`

- Show time via file list:

`datetime -f dates.txt +"%F"`
`printf "2020-01-02\n" | datetime -f - +"%F"`

- ISO-8601 output:

`datetime -I`
`datetime -Iseconds`
`datetime --iso-8601=ns`

- Show time of file modification:

`datetime -r Makefile +"%F %T"`

- Show available timestamp resolution:

`datetime --resolution`

- RFC 3339:

`datetime --rfc-3339=seconds`

- RFC 5322 (email):

`datetime -R`

- Set system time (requires root; otherwise warns):

`sudo datetime -s "2020-01-02 00:00:00"`

- Timestamp (UTC YYYYMMDDhhmmssZ):

`timestamp`
`datetime --timestamp`
`TS=$(timestamp); echo "2.0.$TS"`

- UTC / custom format:

`datetime -u +"%Y-%m-%d %H:%M:%S %Z"`

- Legacy formats:

`datetime -hr, --human-readable`   # `YYYY-MM-DD hh:mm:ss`
`datetime -c, --compact`   # `YYYYMMDDThhmmss`
`datetime -cd, --calendar-date`   # `YYYY-MM-DD`
`datetime -cdb, --calendar-date-base`   # `YYYYMMDD`
`datetime -od, --ordinal-date`   # `YYYY-DDD`
`datetime -odb, --ordinal-date-base`   # `YYYYDDD`
`datetime -wd, --week-date`   # `YYYY-Www-D`
`datetime -wdb, --week-date-basic`   # `YYYYWwwD`
`datetime --timestamp`   # `YYYYMMDDhhmmssZ`
