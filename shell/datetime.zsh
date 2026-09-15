#compdef datetime timestamp
# Zsh completion for `datetime` and for its `timestamp` build variant
# (same program; `timestamp` defaults to the UTC YYYYMMDDhhmmssZ stamp).
#
# System-wide install (picked up automatically by zsh):
#   make install
# which copies this file to $(prefix)/share/zsh/site-functions/
# as both `_datetime` and `_timestamp`.
#
# User-local install without system zsh completions, add to ~/.zshrc:
#   fpath=(~/.local/share/zsh/site-functions $fpath)
#   autoload -Uz compinit && compinit
# or source directly:
#   source ~/.local/share/zsh/site-functions/_datetime
#   source shell/datetime.zsh  # from repo

_datetime () {
    local cur prev
    cur=${words[CURRENT]}

    # Handle value completion for --iso-8601=* and --rfc-3339=* (like bash)
    case $cur in
        --iso-8601=*)
            local -a vals
            vals=('date' 'hours' 'minutes' 'seconds' 'ns')
            compadd -a vals
            return 0
            ;;
        --rfc-3339=*)
            local -a vals
            vals=('date' 'seconds' 'ns')
            compadd -a vals
            return 0
            ;;
        -I?*)
            # -I with optional attached argument: -Iseconds, -Ins, etc.
            local -a ispecs
            ispecs=('-I' '-Idate' '-Ihours' '-Iminutes' '-Iseconds' '-Ins')
            compadd -a ispecs
            return 0
            ;;
    esac

    # Handle previous word needing specific completion
    if (( CURRENT > 1 )); then
        prev=${words[CURRENT-1]}
        case $prev in
            -f|--file|--reference|-r)
                _files
                return 0
                ;;
            --iso-8601|-I)
                local -a vals
                vals=(date hours minutes seconds ns)
                compadd -a vals
                return 0
                ;;
            --rfc-3339)
                local -a vals
                vals=(date seconds ns)
                compadd -a vals
                return 0
                ;;
            -d|--date|-s|--set)
                # Arbitrary date string; suppress file completion
                return 0
                ;;
        esac
        # Handle --file=*, --reference=*, --date=*, --set=* with attached =
        case $prev in
            --file=*|--reference=*)
                _files
                return 0
                ;;
            --date=*|--set=*)
                return 0
                ;;
        esac
    fi

    # Main option completion when current word starts with -
    if [[ $cur == -* ]]; then
        local -a opts
        opts=(
            '-d' '--date=' '--debug'
            '-f' '--file=' '-I' '--iso-8601' '--resolution'
            '-R' '--rfc-email' '--rfc-3339=' '-r' '--reference=' '-s' '--set='
            '-u' '--utc' '--universal' '--help' '--version'
            '-hr' '--human-readable' '-c' '--compact'
            '-cd' '--calendar-date' '-cdb' '--calendar-date-base'
            '-od' '--ordinal-date' '-odb' '--ordinal-date-base'
            '-wd' '--week-date' '-wdb' '--week-date-basic'
            '--timestamp'
        )
        # Use compadd with filtering on $cur
        compadd -a opts
        return 0
    fi

    case $cur in
        +*)
            # User is typing a strftime +FORMAT; nothing to offer
            return 0
            ;;
        i*)
            # Bare legacy format names accepted as operands
            local -a leg
            leg=('iso-basic')
            compadd -a leg
            return 0
            ;;
    esac

    # Anything else: fall back to filename completion (e.g. for -r operands)
    _files
}

# Register for both commands (timestamp is same binary with different default)
if (( $+functions[compdef] )); then
    compdef _datetime datetime timestamp 2>/dev/null || compdef _datetime datetime
fi
