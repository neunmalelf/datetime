# Fish completion for `timestamp` and for its `datetime` build variant
# (same program; `timestamp` defaults to the UTC YYYYMMDDhhmmssZ stamp).
#
# System-wide install (picked up automatically by fish):
#   make install
# which copies this file to $(prefix)/share/fish/vendor_completions.d/
# as `timestamp.fish` (and `datetime.fish` as `datetime.fish`).
#
# User-local install without fish completions dir, copy manually:
#   mkdir -p ~/.config/fish/completions
#   cp shell/timestamp.fish ~/.config/fish/completions/timestamp.fish
#   cp shell/datetime.fish ~/.config/fish/completions/datetime.fish

for cmd in timestamp datetime
    # Date source / GNU compatible
    complete -c $cmd -s d -l date -d 'display time described by STRING, not now' -r -f
    complete -c $cmd -l debug -d 'annotate parsed date, warn to stderr' -f
    complete -c $cmd -s f -l file -d 'like --date; once for each line of DATEFILE' -r -F
    complete -c $cmd -s I -l iso-8601 -d 'output date/time in ISO 8601 format' -r -f -a 'date hours minutes seconds ns'
    complete -c $cmd -l resolution -d 'output available resolution of timestamps' -f
    complete -c $cmd -s R -l rfc-email -d 'output date/time in RFC 5322 format' -f
    complete -c $cmd -l rfc-3339 -d 'output date/time in RFC 3339 format' -r -f -a 'date seconds ns'
    complete -c $cmd -s r -l reference -d 'display last modification time of FILE' -r -F
    complete -c $cmd -s s -l set -d 'set time described by STRING' -r -f
    complete -c $cmd -s u -l utc -l universal -d 'print or set Coordinated Universal Time (UTC)' -f
    complete -c $cmd -l help -d 'display this help and exit' -f
    complete -c $cmd -l version -d 'output version information and exit' -f
    # Legacy formats (kept for compatibility)
    complete -c $cmd -l human-readable -d 'human readable YYYY-MM-DD hh:mm:ss' -f
    complete -c $cmd -l compact -d 'compact YYYYMMDDThhmmss' -f
    complete -c $cmd -l calendar-date -d 'calendar date YYYY-MM-DD' -f
    complete -c $cmd -l calendar-date-base -d 'calendar date base YYYYMMDD' -f
    complete -c $cmd -l ordinal-date -d 'ordinal date YYYY-DDD' -f
    complete -c $cmd -l ordinal-date-base -d 'ordinal date base YYYYDDD' -f
    complete -c $cmd -l week-date -d 'week date YYYY-Www-D' -f
    complete -c $cmd -l week-date-basic -d 'week date basic YYYYWwwD' -f
    complete -c $cmd -l timestamp -d 'UTC YYYYMMDDhhmmssZ (micro-version format)' -f
    # Combined short legacy flags (e.g. -hr, -cd, -cdb, -od, -odb, -wd, -wdb, -c)
    # Fish completes options via -s/-l; combined forms are offered as arguments
    complete -c $cmd -a '-hr' -d 'human readable YYYY-MM-DD hh:mm:ss' -f
    complete -c $cmd -a '-c' -d 'compact YYYYMMDDThhmmss' -f
    complete -c $cmd -a '-cd' -d 'calendar date YYYY-MM-DD' -f
    complete -c $cmd -a '-cdb' -d 'calendar date base YYYYMMDD' -f
    complete -c $cmd -a '-od' -d 'ordinal date YYYY-DDD' -f
    complete -c $cmd -a '-odb' -d 'ordinal date base YYYYDDD' -f
    complete -c $cmd -a '-wd' -d 'week date YYYY-Www-D' -f
    complete -c $cmd -a '-wdb' -d 'week date basic YYYYWwwD' -f
    # -I with attached values (e.g. -Iseconds, -Ins) - offered as full tokens
    complete -c $cmd -a '-I' -d 'ISO 8601 format (default date)' -f
    complete -c $cmd -a '-Idate' -d 'ISO 8601 date' -f
    complete -c $cmd -a '-Ihours' -d 'ISO 8601 hours' -f
    complete -c $cmd -a '-Iminutes' -d 'ISO 8601 minutes' -f
    complete -c $cmd -a '-Iseconds' -d 'ISO 8601 seconds' -f
    complete -c $cmd -a '-Ins' -d 'ISO 8601 nanoseconds' -f
    # Bare legacy operands accepted without dash
    complete -c $cmd -a 'iso-basic' -d 'compact ISO 8601 basic' -f
end
