# timestamp

> Print the current UTC timestamp `YYYYMMDDhhmmssZ` (14 digits + `Z`). Same program as `datetime` compiled with `-DDATETIME_TIMESTAMP_BUILD` – every `datetime` option works identically, default output is the UTC stamp.

> See also: `datetime`, `date`.

- Print current UTC timestamp (default `YYYYMMDDhhmmssZ`):

`timestamp`

- Show help (same options as `datetime`):

`timestamp --help`
`timestamp -h`

- Show version and timezone:

`timestamp --version`
`timestamp -V`

- Timestamp via `datetime` (identical):

`datetime --timestamp`

- Use as micro-version `x.y.<UTC>`:

`TS=$(timestamp); echo "2.0.$TS"`

- Parse a date string and format as timestamp:

`timestamp -d "2020-01-02 03:04:05" +"%Y%m%d%H%M%SZ"`
`timestamp -u -d "@2147483647" +"%F %T %Z"`

- Show other formats (all `datetime` options work):

`timestamp -u +"%Y-%m-%d %H:%M:%S %Z"`
`timestamp -Iseconds`
`timestamp -R`
`timestamp --iso-8601=ns`

- Debug parsing:

`timestamp --debug -d "2020-01-02"`

- Legacy formats (same as `datetime`):

`timestamp -hr`   # `YYYY-MM-DD hh:mm:ss`
`timestamp -c`   # `YYYYMMDDThhmmss`
