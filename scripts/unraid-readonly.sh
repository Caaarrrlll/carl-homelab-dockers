#!/bin/bash
# unraid-readonly.sh: forced command for a temporary, read-only SSH key.
#
# Lets an agent (Claude Code on the maintainer's PC) read container state and
# logs on Unraid while an image is being built, without a shell. Installed as
# the `command=` of ONE key line in root's authorized_keys (all on one line):
#
#   restrict,command="/bin/bash /boot/config/claude-readonly/unraid-readonly.sh"
#       ssh-ed25519 AAAA... claude-readonly@pc
#
# sshd then runs this script for every connection with that key and puts what
# the client asked for in SSH_ORIGINAL_COMMAND. The request is split into
# words and matched against a fixed allowlist; it is never passed to a shell
# or eval. Anything else is refused and logged to syslog.
#
# Revoke: delete the key line (and this file). See RATE_LIMIT_TRACKER.md.
#
# Allowed requests:
#   help
#   ps                         all containers: name, image, status, ports
#   logs <container> [lines]   last N log lines (default 200, max 2000)
#   inspect <container>        state, health, restarts, network, ports,
#                              mounts. NO environment variables.
#   stats                      one-shot CPU/memory of the allowed containers
#   ls [subpath]               directory listing under APPDATA_ROOT
#   health                     GET /_health on the host port mapped to
#                              fluxer-aio's container port 8080

set -u -o pipefail

# --- Fixed values (never read from the environment) -----------------------------

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
readonly ALLOWED_CONTAINERS="fluxer-aio Caddy Redis"
readonly APPDATA_ROOT=/mnt/user/appdata/fluxer-aio
readonly HEALTH_CONTAINER=fluxer-aio
readonly HEALTH_PORT=8080/tcp   # container port; the host port is looked up
readonly MAX_LINES=2000
readonly DEFAULT_LINES=200
readonly TAG=claude-readonly

# --- Helpers -----------------------------------------------------------------------

# Log to syslog; a missing logger never blocks a request.
audit() {
    if ! logger -t "$TAG" -- "$*" 2>/dev/null; then
        :
    fi
}

refuse() {
    echo "refused: $1" >&2
    audit "REFUSED ($1): ${SSH_ORIGINAL_COMMAND:-<interactive>}"
    exit 1
}

# Print the "Allowed requests" block from this file's header.
usage() {
    sed -n '/^# Allowed requests:/,/^$/p' "$0" \
        | sed 's/^# \{0,1\}//'
    echo "Allowed containers: $ALLOWED_CONTAINERS"
}

allowed_container() {
    local c
    for c in $ALLOWED_CONTAINERS; do
        if [ "$1" = "$c" ]; then
            return 0
        fi
    done
    return 1
}

# Go template for `inspect`: explicit fields only, .Config.Env is never
# printed. Built from short pieces; the result is one line per field.
inspect_format() {
    local status_line
    local health_line
    local network_line
    local ports_line
    local parts

    status_line='status:    {{.State.Status}} (started {{.State.StartedAt}},'
    status_line+=' exit {{.State.ExitCode}}, restarts {{.RestartCount}},'
    status_line+=' oom {{.State.OOMKilled}})'

    health_line='health:    {{with index .State "Health"}}{{.Status}}'
    health_line+=' (failing streak {{.FailingStreak}}){{else}}no healthcheck{{end}}'

    network_line='network:   {{.HostConfig.NetworkMode}}'
    network_line+='{{range $k, $v := .NetworkSettings.Networks}} [{{$k}} {{$v.IPAddress}}]{{end}}'

    ports_line='ports:     {{range $p, $b := .NetworkSettings.Ports}}{{$p}}{{if $b}}->'
    ports_line+='{{range $b}}{{.HostIp}}:{{.HostPort}} {{end}}{{end}}; {{end}}'

    parts=(
        'name:      {{.Name}}'
        'image:     {{.Config.Image}}'
        "$status_line"
        "$health_line"
        "$network_line"
        "$ports_line"
        'mounts:    {{range .Mounts}}'
        '  {{.Source}} -> {{.Destination}} ({{if .RW}}rw{{else}}ro{{end}}){{end}}'
        'memory:    {{.HostConfig.Memory}} bytes limit (0 = none)'
    )
    printf '\n%s' "${parts[@]}"
}

# --- Read and screen the request -------------------------------------------------

req="${SSH_ORIGINAL_COMMAND:-}"
if [ -z "$req" ]; then
    audit "interactive login attempt"
    usage
    exit 0
fi

# Only plain words: letters, digits and . _ / - : and spaces. This rejects
# quotes, $, ;, |, &, `, globs, redirects and newlines before anything else.
case "$req" in
    *[!A-Za-z0-9._/:\ -]*)
        refuse "unexpected characters"
        ;;
esac

read -r -a args <<< "$req"
cmd="${args[0]:-}"
n=${#args[@]}

audit "request: $req"

# --- Run an allowed request ------------------------------------------------------

case "$cmd" in
    help)
        if [ "$n" -ne 1 ]; then
            refuse "help takes no arguments"
        fi
        usage
        ;;

    ps)
        if [ "$n" -ne 1 ]; then
            refuse "ps takes no arguments"
        fi
        docker ps -a \
            --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
        ;;

    logs)
        if [ "$n" -lt 2 ] || [ "$n" -gt 3 ]; then
            refuse "usage: logs <container> [lines]"
        fi
        if ! allowed_container "${args[1]}"; then
            refuse "container not allowed: ${args[1]}"
        fi

        lines="${args[2]:-$DEFAULT_LINES}"
        case "$lines" in
            '' | *[!0-9]*)
                refuse "lines must be a number"
                ;;
        esac
        if [ "${#lines}" -gt 4 ] || [ "$lines" -lt 1 ] || [ "$lines" -gt "$MAX_LINES" ]; then
            refuse "lines must be 1-$MAX_LINES"
        fi

        docker logs --timestamps --tail "$lines" "${args[1]}" 2>&1
        ;;

    inspect)
        if [ "$n" -ne 2 ]; then
            refuse "usage: inspect <container>"
        fi
        if ! allowed_container "${args[1]}"; then
            refuse "container not allowed: ${args[1]}"
        fi
        docker inspect --format "$(inspect_format)" "${args[1]}"
        ;;

    stats)
        if [ "$n" -ne 1 ]; then
            refuse "stats takes no arguments"
        fi

        running=()
        for c in $ALLOWED_CONTAINERS; do
            state="$(docker inspect --format '{{.State.Running}}' "$c" 2>/dev/null)"
            if [ "$state" = "true" ]; then
                running+=("$c")
            fi
        done
        if [ "${#running[@]}" -eq 0 ]; then
            echo "none of the allowed containers is running"
            exit 0
        fi

        docker stats --no-stream \
            --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}' \
            "${running[@]}"
        ;;

    ls)
        if [ "$n" -gt 2 ]; then
            refuse "usage: ls [subpath]"
        fi

        sub="${args[1]:-}"
        case "/$sub/" in
            */../* | */./*)
                refuse "path may not contain . or .. segments"
                ;;
        esac

        target="$APPDATA_ROOT${sub:+/$sub}"
        if ! real="$(realpath -m -- "$target")"; then
            refuse "bad path"
        fi
        case "$real/" in
            "$APPDATA_ROOT"/*)
                ;;
            *)
                refuse "path outside $APPDATA_ROOT"
                ;;
        esac
        if [ ! -d "$real" ]; then
            refuse "not a directory: ${sub:-.}"
        fi

        ls -la -- "$real"
        ;;

    health)
        if [ "$n" -ne 1 ]; then
            refuse "health takes no arguments"
        fi

        hp="$(docker port "$HEALTH_CONTAINER" "$HEALTH_PORT" 2>/dev/null | sed -n '1s/.*://p')"
        case "$hp" in
            '' | *[!0-9]*)
                echo "$HEALTH_CONTAINER: port $HEALTH_PORT is not published" \
                    "(container missing or stopped?)"
                exit 1
                ;;
        esac

        curl -sS -m 5 -o - -w '\nHTTP %{http_code}\n' "http://127.0.0.1:$hp/_health"
        ;;

    *)
        refuse "unknown command: $cmd"
        ;;
esac
