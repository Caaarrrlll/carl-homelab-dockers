#!/bin/bash
# start-watchdog.sh: waits for the ARK server process to exit, then ends the
# log `tail` so the container session can finish.

killpid="$(pidof ArkAscendedServer.exe)"

while true
do
    tail --pid=$killpid -f /dev/null
    kill "$(pidof tail)"
    exit 0
done
