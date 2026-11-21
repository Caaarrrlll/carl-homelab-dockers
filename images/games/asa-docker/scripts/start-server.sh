#!/bin/bash
# start-server.sh: runs as the steam user (started by start.sh).
#
# Checks host requirements (vm.max_map_count, NTSYNC), updates SteamCMD and
# the ASA server, prepares the Wine prefix, builds the launch arguments,
# starts the server under Wine and follows its per-server log.

# --- Host requirement: vm.max_map_count ------------------------------------------

echo "---Checking the maximum map count per process...---"
CUR_MAX_MAP_COUNT=$(cat /proc/sys/vm/max_map_count)
if [[ $CUR_MAX_MAP_COUNT -ge 256000 ]]; then
    echo "---Maximum map count per process OK...---"
    echo "---Current map count per process: $CUR_MAX_MAP_COUNT---"
else
    echo
    echo "+---ATTENTION---ATTENTION---ATTENTION---ATTENTION---ATTENTION---"
    echo "| Maximum map count per process too low, currently: $CUR_MAX_MAP_COUNT"
    echo "| Please set the value to at least '256000' (recommended"
    echo "| '1048576') on the host and"
    echo "| restart the container afterwards."
    echo "|"
    echo "| You can change the value by executing this command on the host"
    echo "| as root:"
    echo
    echo "echo 1048576 > /proc/sys/vm/max_map_count"
    echo
    echo "| You can make that persistent by using a User Script that runs"
    echo "| on startup or putting this line in your go file."
    echo "+---ATTENTION---ATTENTION---ATTENTION---ATTENTION---ATTENTION---"
    echo
    echo "---Putting container into sleep mode!---"
    sleep infinity
fi

# --- NTSYNC ------------------------------------------------------------------------

echo "---Checking NTSYNC support...---"
NTSYNC_WORKING=0
if [ "${NTSYNC}" == "1" ]; then
    if [ -c /dev/ntsync ]; then
        export WINENTSYNC=1
        NTSYNC_WORKING=1
        echo "---NTSYNC enabled: /dev/ntsync is available, Wine will use it---"
    else
        echo
        echo "+---ATTENTION---ATTENTION---ATTENTION---ATTENTION---ATTENTION---"
        echo "| NTSYNC is enabled but /dev/ntsync was not found in the container."
        echo "| Make sure the following runs on the host (e.g. from the go file):"
        echo
        echo "echo \"modprobe ntsync\" >> /boot/config/go"
        echo
        echo "| and that the container is started with '--device=/dev/ntsync'"
        echo "| (Unraid template: Extra Parameters)."
        echo "|"
        echo "| Falling back to ESync/FSync."
        echo "+---ATTENTION---ATTENTION---ATTENTION---ATTENTION---ATTENTION---"
        echo
    fi
else
    echo "---NTSYNC disabled, Wine will use ESync/FSync---"
fi

# --- Steam login ---------------------------------------------------------------------

LOGIN_CREDENTIALS="anonymous"
if [[ -n "${STEAM_USERNAME}" && "${STEAM_USERNAME}" != "" ]] \
    && [[ -n "${STEAM_PASSWRD}" && "${STEAM_PASSWRD}" != "" ]]; then
    LOGIN_CREDENTIALS="${STEAM_USERNAME} ${STEAM_PASSWRD}"
fi

# --- SteamCMD ------------------------------------------------------------------------

if [ ! -f ${STEAMCMD_DIR}/steamcmd.sh ]; then
    echo "SteamCMD not found!"
    if ! wget -q \
        -O "${STEAMCMD_DIR}/steamcmd_linux.tar.gz" \
        https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
    then
        echo "---Failed to download SteamCMD, putting container into sleep mode!---"
        sleep infinity
    fi
    tar --directory "${STEAMCMD_DIR}" -xvzf "${STEAMCMD_DIR}/steamcmd_linux.tar.gz"
    rm "${STEAMCMD_DIR}/steamcmd_linux.tar.gz"
fi

echo "---Update SteamCMD---"
${STEAMCMD_DIR}/steamcmd.sh \
    +login ${LOGIN_CREDENTIALS} \
    +quit

# --- Server update ---------------------------------------------------------------------

VALIDATE_CMD=""
echo "---Update Server---"
if [ "${VALIDATE}" == "true" ]; then
    echo "---Validating installation---"
    VALIDATE_CMD="validate"
fi
${STEAMCMD_DIR}/steamcmd.sh \
    +@sSteamCmdForcePlatformType windows \
    +force_install_dir ${SERVER_DIR} \
    +login ${LOGIN_CREDENTIALS} \
    +app_update ${GAME_ID} ${VALIDATE_CMD} \
    +quit

# --- Wine prefix -----------------------------------------------------------------------

export WINEARCH=win64
export WINEPREFIX=/serverdata/serverfiles/WINE64
export WINEDEBUG=-all

echo "---Checking if WINE workdirectory is present---"
if [ ! -d ${SERVER_DIR}/WINE64 ]; then
    echo "---WINE workdirectory not found, creating please wait...---"
    mkdir ${SERVER_DIR}/WINE64
else
    echo "---WINE workdirectory found---"
fi

echo "---Checking if WINE is properly installed---"
if [ ! -d ${SERVER_DIR}/WINE64/drive_c/windows ]; then
    echo "---Setting up WINE---"
    cd ${SERVER_DIR}
    winecfg > /dev/null 2>&1
    sleep 15
else
    echo "---WINE properly set up---"
fi
echo "---Server ready---"

# --- Launch arguments -------------------------------------------------------------------
# Launch arguments are built as a bash array, so each one reaches Wine as a
# single argument: no word splitting and no glob expansion.
# The first argument is ARK's "URL" (map + ?options). It is kept as ONE argument
# even when SERVER_NAME contains spaces; Wine then wraps it in quotes on the
# Windows command line, so no literal quotes are needed around the name.
# Note: '?' is ARK's option separator, so it can't be used inside the server
# name or passwords.
# RCON (internal only; used by start.sh to save on stop) and the autosave
# interval are set here, so they don't depend on the shared
# GameUserSettings.ini (URL options override the ini).

if ! [[ "${AUTOSAVE_MINUTES}" =~ ^[0-9]+$ ]] || [ "${AUTOSAVE_MINUTES}" -lt 1 ]; then
    echo "---WARNING: AUTOSAVE_MINUTES='${AUTOSAVE_MINUTES}' is not a positive number, using 15---"
    AUTOSAVE_MINUTES=15
fi
if ! [[ "${RCON_PORT}" =~ ^[0-9]+$ ]]; then
    echo "---WARNING: RCON_PORT='${RCON_PORT}' is not a number, using 27020---"
    RCON_PORT=27020
fi

# ARK's "URL": map, then ?option=value pairs (one string, one argument).
ARK_URL="${MAP}?listen"
ARK_URL+="?SessionName=${SERVER_NAME}"
ARK_URL+="?ServerPassword=${SRV_PWD}"
ARK_URL+="?ServerAdminPassword=${SRV_ADMIN_PWD}"
ARK_URL+="?RCONEnabled=True"
ARK_URL+="?RCONPort=${RCON_PORT}"
ARK_URL+="?AutoSavePeriodMinutes=${AUTOSAVE_MINUTES}"
ARK_ARGS=("${ARK_URL}")

# GAME_PARAMS_EXTRA holds space-separated ARK flags; split it on whitespace
# only (read -a does not glob-expand).
read -r -a GAME_PARAMS_EXTRA_ARGS <<< "${GAME_PARAMS_EXTRA}"
ARK_ARGS+=("${GAME_PARAMS_EXTRA_ARGS[@]}")

if [ "${SRV_CLUSTER_INFO}" != "" ]; then
    ARK_ARGS+=(
        "-clusterid=${SRV_CLUSTER_INFO}"
        "-clusterDirOverride=/serverdata/serverfiles/clusterfiles"
    )
fi
if [ "${SRV_MOD_IDS}" != "" ]; then
    ARK_ARGS+=("-mods=${SRV_MOD_IDS}")
fi

ARK_ARGS+=("-GBUsageToForceRestart=${GB_FORCE_RESTART}")

# --- Per-server log file --------------------------------------------------------------
# All cluster servers share Saved/Logs, so each one writes
# <LOG_PREFIX>-ShooterGame.log instead of the shared ShooterGame.log.
# LOG_PREFIX blank (default) = use the map name.

LOG_DIR="${SERVER_DIR}/ShooterGame/Saved/Logs"
LOG_PREFIX="$(
    printf '%s' "${LOG_PREFIX}" \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
)"
if [ -z "${LOG_PREFIX}" ]; then
    LOG_PREFIX="${MAP}"
fi
# Spaces/slashes inside the prefix would split the launch line or point into
# another folder, so swap anything unusual for '_'.
LOG_PREFIX="${LOG_PREFIX//[^A-Za-z0-9_.-]/_}"
LOG_FILE="${LOG_PREFIX}-ShooterGame.log"
ARK_ARGS+=("-LOG=${LOG_FILE}")
echo "---Server log file: ${LOG_DIR}/${LOG_FILE}---"

# --- Debug output (prints passwords; DEBUG defaults to 0) ------------------------------

if [ "${DEBUG}" == "1" ]; then
    echo -e "DEBUG: Starting server with the following environment variables:"
    # env | sort
    # custom params
    echo -e "DEBUG: Normalized variables:"
    echo "MAP: ${MAP}"
    echo "GAME_ID: ${GAME_ID}"
    echo "SERVER_NAME: ${SERVER_NAME}"
    echo "SRV_PWD: ${SRV_PWD}"
    echo "SRV_ADMIN_PWD: ${SRV_ADMIN_PWD}"
    echo "VALIDATE_CMD: ${VALIDATE_CMD}"
    echo "LOGIN_CREDENTIALS: ${LOGIN_CREDENTIALS}"
    echo "SERVER_DIR: ${SERVER_DIR}"
    echo "STEAMCMD_DIR: ${STEAMCMD_DIR}"
    echo "Cluster Info: ${SRV_CLUSTER_INFO}"
    echo "MOD IDs: ${SRV_MOD_IDS}"
    echo "ARK_ARGS (one per line):"
    printf '  [%s]\n' "${ARK_ARGS[@]}"
    echo "NTSYNC flag: ${NTSYNC} (working: ${NTSYNC_WORKING}, WINENTSYNC: ${WINENTSYNC:-0})"
    echo "LOG_FILE: ${LOG_DIR}/${LOG_FILE}"
fi

# --- Start the server and follow its log -------------------------------------------------

echo "---Start Server---"
if [ ! -f ${SERVER_DIR}/ShooterGame/Binaries/Win64/ArkAscendedServer.exe ]; then
    echo "---Something went wrong, can't find the executable, putting container into sleep mode!---"
    sleep infinity
else
    cd ${SERVER_DIR}/ShooterGame/Binaries/Win64
    ulimit -s 8192
    wine ArkAscendedServer.exe "${ARK_ARGS[@]}" &

    # Wait up to 20 s for the per-server log to appear.
    echo "Waiting for logs..."
    ATTEMPT=0
    sleep 2
    while [ ! -f "${LOG_DIR}/${LOG_FILE}" ]; do
        ((ATTEMPT++))
        if [ $ATTEMPT -eq 10 ]; then
            if [ -f "${LOG_DIR}/ShooterGame.log" ]; then
                # Safety net: never put a running server to sleep over a log name.
                echo "---WARNING: ${LOG_FILE} not found after 20 seconds," \
                    "falling back to ShooterGame.log (may contain another server's output)---"
                LOG_FILE="ShooterGame.log"
                break
            fi
            echo "No log files found after 20 seconds, putting container into sleep mode!"
            sleep infinity
        else
            sleep 2
            echo "Waiting for logs..."
        fi
    done

    # /opt/scripts/start-watchdog.sh &
    # -F follows the file by name, so the tail survives the server rotating an
    # old log of the same name to *-backup-<date>.log at start-up.
    tail -n 9999 -F "${LOG_DIR}/${LOG_FILE}"
fi
