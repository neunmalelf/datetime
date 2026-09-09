"""time - time helpers (current, timestamp, shortversion, epoch).

Ported 1:1 from dd.sh (TIME FUNCTIONS section); timestamp_* functions are the
renamed, precision-explicit variants.
"""

from __future__ import annotations

import datetime
import time as _time

import ddpico

__version__ = "1.1.20260909051812Z"

def time_get_current_formatted() -> str:
    """current time in HH-MM-SS format
    usage: time_get_current_formatted
    returns: HH-MM-SS

    example: time_get_current_formatted()

    """
    return datetime.datetime.now().strftime("%H-%M-%S")


def timestamp_get_for_microversion() -> str:
    """current date/time in compact seconds format (UTC / GMT)
    usage: timestamp_get_for_microversion
    returns: string YYYYMMDDHHMMSSZ
    """
    return datetime.datetime.now(datetime.UTC).strftime("%Y%m%d%H%M%SZ")


def timestamp_get_with_seconds() -> int:
    """current date/time in compact seconds format
    usage: timestamp_get_with_seconds
    returns: integer YYYYMMDDHHMMSS (compact, seconds)

    example: timestamp_get_with_seconds()

    """
    return int(datetime.datetime.now().strftime("%Y%m%d%H%M%S"))


def timestamp_get_with_seconds_formatted() -> str:
    """current date/time in dashed seconds format
    usage: timestamp_get_with_seconds_formatted
    returns: YYYY-MM-DD-HH-MM-SS

    example: timestamp_get_with_seconds_formatted()

    """
    return datetime.datetime.now().strftime("%Y-%m-%d-%H-%M-%S")


def timestamp_get_with_seconds_and_brackets() -> str:
    """current date/time in dashed seconds format, wrapped in brackets
    usage: timestamp_get_with_seconds_and_brackets
    returns: [YYYY-MM-DDThh-mm-ss]

    example: timestamp_get_with_seconds_and_brackets()

    """
    return f"[{datetime.datetime.now().strftime('%Y-%m-%dT%H-%M-%S')}]"


def timestamp_get_with_milliseconds() -> int:
    """current date/time, compact, with milliseconds
    usage: timestamp_get_with_milliseconds
    returns: integer yyyymmddhhmmssnnn (compact + 3-digit milliseconds)

    example: timestamp_get_with_milliseconds()

    """
    millis = (_time.time_ns() // 1_000_000) % 1_000
    return int(f"{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}{millis:03d}")


def timestamp_get_with_microseconds() -> int:
    """current date/time, compact, with microseconds
    usage: timestamp_get_with_microseconds
    returns: integer yyyymmddhhmmssnnnnnn (compact + 6-digit microseconds)

    example: timestamp_get_with_microseconds()

    """
    micros = (_time.time_ns() // 1_000) % 1_000_000
    return int(f"{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}{micros:06d}")


def timestamp_get_with_nanoseconds() -> int:
    """current date/time, compact, with nanoseconds
    usage: timestamp_get_with_nanoseconds
    returns: integer yyyymmddhhmmssnnnnnnnnn (compact + 9-digit nanoseconds)

    example: timestamp_get_with_nanoseconds()

    """
    nanos = _time.time_ns() % 1_000_000_000
    return int(f"{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}{nanos:09d}")


def time_get_timestamp_as_int() -> int:
    """current unix epoch timestamp (seconds)
    usage: time_get_timestamp_as_int
    returns: epoch seconds

    example: time_get_timestamp_as_int()

    """
    return int(_time.time())


def timestamp_get_shortversion() -> str:
    """compact timestamp YYYYMMDDThhmmss
    usage: timestamp_get_shortversion
    returns: timestamp

    example: timestamp_get_shortversion()

    """
    return datetime.datetime.now().strftime("%Y%m%dT%H%M%S")


def timestamp_get_shortversion_fmt() -> str:
    """colorized compact timestamp
    usage: timestamp_get_shortversion_fmt
    returns: colorized timestamp

    example: timestamp_get_shortversion_fmt()

    """
    return ddpico.general_colorize(ddpico.AnsiColor.FG_PURPLE.value, timestamp_get_shortversion())


def time_get_epoch() -> int:
    """current Unix epoch timestamp (seconds)
    usage: time_get_epoch
    returns: epoch seconds

    example: time_get_epoch()

    """
    return time_get_timestamp_as_int()
