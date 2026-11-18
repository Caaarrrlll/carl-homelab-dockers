#!/bin/bash
# unraid-readonly.sh: forced command for a temporary, read-only SSH key.
#
# Lets an agent (Claude Code on the maintainer's PC) read container state and
# logs on Unraid while an image is being built, without a shell. Installed as
# the `command=` of ONE key line in root's authorized_keys, e.g.:
#
#   restrict,command="/bin/bash /boot/config/claude-readonly/unraid-readonly.sh" ssh-ed25519 AAAA... claude-readonly@pc
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

# Fixed values. Do not read these from the environment.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
readonly ALLOWED_CONTAINERS="fluxer-aio Caddy Redis"
readonly APPDATA_ROOT=/mnt/user/appdata/fluxer-aio
readonly HEALTH_CONTAINER=fluxer-aio
readonly HEALTH_PORT=8080/tcp   # container port; the host port is looked up
readonly MAX_LINES=2000
readonly DEFAULT_LINES=200
readonly TAG=claude-readonly

audit() { logger -t "$TAG" -- "$*" 2>/dev/null || true; }

refuse() {
    echo "refused: $1" >&2
    audit "REFUSED ($1): ${SSH_ORIGINAL_COMMAND:-<interactive>}"
    exit 1
}

usage() {
    sed -n '/^# Allowed requests:/,/^$/p' "$0" | sed 's/^# \{0,1\}//'
    echo "Allowed containers: $ALLOWED_CONTAINERS"
}

allowed_container() {
    local c
    for c in $ALLOWED_CONTAINERS; do
        [ "$1" = "$c" ] && return 0
    done
    return 1
}

req="${SSH_ORIGINAL_COMMAND:-}"
if [ -z "$req" ]; then
    audit "interactive login attempt"
    usage
    exit 0
fi

# Only plain words: letters, digits and . _ / - : and spaces. This rejects
# quotes, $, ;, |, &, `, globs, redirects and newlines before anything else.
case "$req" in
    *[!A-Za-z0-9._/:\ -]*) refuse "unexpected characters" ;;
esac

read -r -a args <<< "$req"
cmd="${args[0]:-}"
n=${#args[@]}

audit "request: $req"

case "$cmd" in
    help)
        [ "$n" -eq 1 ] || refuse "help takes no arguments"
        usage
        ;;
    ps)
        [ "$n" -eq 1 ] || refuse "ps takes no arguments"
        docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
        ;;
    logs)
        [ "$n" -ge 2 ] && [ "$n" -le 3 ] || refuse "usage: logs <container> [lines]"
        allowed_container "${args[1]}" || refuse "container not allowed: ${args[1]}"
        lines="${args[2]:-$DEFAULT_LINES}"
        case "$lines" in
            ''|*[!0-9]*) refuse "lines must be a number" ;;
        esac
        [ "${#lines}" -le 4 ] && [ "$lines" -ge 1 ] && [ "$lines" -le "$MAX_LINES" ] \
            || refuse "lines must be 1-$MAX_LINES"
        docker logs --timestamps --tail "$lines" "${args[1]}" 2>&1
        ;;
    inspect)
        [ "$n" -eq 2 ] || refuse "usage: inspect <container>"
        allowed_container "${args[1]}" || refuse "container not allowed: ${args[1]}"
        # Explicit fields only; .Config.Env is deliberately never printed.
        docker inspect --format '
name:      {{.Name}}
image:     {{.Config.Image}}
status:    {{.State.Status}} (started {{.State.StartedAt}}, exit {{.State.ExitCode}}, restarts {{.RestartCount}}, oom {{.State.OOMKilled}})
health:    {{with index .State "Health"}}{{.Status}} (failing streak {{.FailingStreak}}){{else}}no healthcheck{{end}}
network:   {{.HostConfig.NetworkMode}}{{range $k, $v := .NetworkSettings.Networks}} [{{$k}} {{$v.IPAddress}}]{{end}}
ports:     {{range $p, $b := .NetworkSettings.Ports}}{{$p}}{{if $b}}->{{range $b}}{{.HostIp}}:{{.HostPort}} {{end}}{{end}}; {{end}}
mounts:    {{range .Mounts}}
  {{.Source}} -> {{.Destination}} ({{if .RW}}rw{{else}}ro{{end}}){{end}}
memory:    {{.HostConfig.Memory}} bytes limit (0 = none)' "${args[1]}"
        ;;
    stats)
        [ "$n" -eq 1 ] || refuse "stats takes no arguments"
        running=()
        for c in $ALLOWED_CONTAINERS; do
            if [ "$(docker inspect --format '{{.State.Running}}' "$c" 2>/dev/null)" = "true" ]; then
                running+=("$c")
            fi
        done
        [ "${#running[@]}" -gt 0 ] || { echo "none of the allowed containers is running"; exit 0; }
        docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}' "${running[@]}"
        ;;
    ls)
        [ "$n" -le 2 ] || refuse "usage: ls [subpath]"
        sub="${args[1]:-}"
        case "/$sub/" in
            */../*|*/./*) refuse "path may not contain . or .. segments" ;;
        esac
        target="$APPDATA_ROOT${sub:+/$sub}"
        real="$(realpath -m -- "$target")" || refuse "bad path"
        case "$real/" in
            "$APPDATA_ROOT"/*) ;;
            *) refuse "path outside $APPDATA_ROOT" ;;
        esac
        [ -d "$real" ] || refuse "not a directory: ${sub:-.}"
        ls -la -- "$real"
        ;;
    health)
        [ "$n" -eq 1 ] || refuse "health takes no arguments"
        hp="$(docker port "$HEALTH_CONTAINER" "$HEALTH_PORT" 2>/dev/null | sed -n '1s/.*://p')"
        case "$hp" in
            ''|*[!0-9]*) echo "$HEALTH_CONTAINER: port $HEALTH_PORT is not published (container missing or stopped?)"; exit 1 ;;
        esac
        curl -sS -m 5 -o - -w '\nHTTP %{http_code}\n' "http://127.0.0.1:$hp/_health"
        ;;
    *)
        refuse "unknown command: $cmd"
        ;;
esac
