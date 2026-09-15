# shellcheck shell=bash
#
# Bash completion for `timestamp` and for its `datetime` build variant
# (same program; `timestamp` defaults to the UTC YYYYMMDDhhmmssZ stamp,
#  `datetime` defaults to local YYYYMMDDhhmmss).
#
# System-wide install (picked up automatically by bash-completion):
#   make install
# which copies this file to $(datarootdir)/bash-completion/completions/
# as `timestamp` (and `datetime.bash` as `datetime`).
#
# User-local install without bash-completion, source it from ~/.bashrc:
#   [ -f ~/.local/share/bash-completion/completions/timestamp ] && \
#       . ~/.local/share/bash-completion/completions/timestamp

# _timestamp_complete CMD CUR PREV — shared with datetime
_timestamp_complete ()
{
    local cur=$2
    local prev=$3

    case $cur in
        --iso-8601=*)
            COMPREPLY=($(compgen -W 'date hours minutes seconds ns' \
                -- "${cur#*=}"))
            return 0
            ;;
        --rfc-3339=*)
            COMPREPLY=($(compgen -W 'date seconds ns' -- "${cur#*=}"))
            return 0
            ;;
        -I??*)
            # -I takes an optional attached argument: -Iseconds
            COMPREPLY=($(compgen -W '-I -Idate -Ihours -Iminutes -Iseconds -Ins' \
                -- "$cur"))
            return 0
            ;;
    esac

    case $prev in
        -f | --file | -r | --reference)
            _filedir
            return 0
            ;;
        --iso-8601 | -I)
            COMPREPLY=($(compgen -W 'date hours minutes seconds ns' -- "$cur"))
            return 0
            ;;
        --rfc-3339)
            COMPREPLY=($(compgen -W 'date seconds ns' -- "$cur"))
            return 0
            ;;
        -d | --date | -s | --set)
            # Arbitrary date string (anything `date -d` accepts); the
            # shell's default (filename) completion would be misleading.
            COMPREPLY=()
            return 0
            ;;
    esac

    case $cur in
        -*)
            local opts="
                -d --date= --debug -f --file= -I --iso-8601 --resolution
                -R --rfc-email --rfc-3339= -r --reference= -s --set=
                -u --utc --universal --help --version
                -hr --human-readable -c --compact
                -cd --calendar-date -cdb --calendar-date-base
                -od --ordinal-date -odb --ordinal-date-base
                -wd --week-date -wdb --week-date-basic
                --timestamp
                "
            COMPREPLY=($(compgen -W "$opts" -- "$cur"))
            [[ ${COMPREPLY[*]} == *= ]] && compopt -o nospace 2>/dev/null
            return 0
            ;;
        +*)
            # User is typing a strftime +FORMAT; nothing to offer.
            COMPREPLY=()
            return 0
            ;;
        i*)
            # Bare legacy format names accepted as operands.
            COMPREPLY=($(compgen -W 'iso-basic' -- "$cur"))
            return 0
            ;;
    esac

    # Anything else (no option pending): fall back to filename
    # completion, e.g. for -r style operands.  MMDDhhmm set-time
    # operands offer nothing useful to complete.
    _filedir
    return 0
}

_datetime ()
{
    local cur prev words cword
    _init_completion 2>/dev/null || return 1
    _timestamp_complete "$1" "$cur" "$prev"
}

_timestamp ()
{
    local cur prev words cword
    _init_completion 2>/dev/null || return 1
    _timestamp_complete "$1" "$cur" "$prev"
}

complete -F _timestamp -o nosort -o nospace timestamp 2>/dev/null || \
    complete -F _datetime -o nosort -o nospace timestamp
complete -F _datetime -o nosort -o nospace datetime
