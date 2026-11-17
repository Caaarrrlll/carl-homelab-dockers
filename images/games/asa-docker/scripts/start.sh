#!/bin/bash
echo "---Ensuring UID: ${UID} matches user---"
usermod -u ${UID} ${USER}
echo "---Ensuring GID: ${GID} matches user---"
groupmod -g ${GID} ${USER} > /dev/null 2>&1 ||:
usermod -g ${GID} ${USER}
echo "---Setting umask to ${UMASK}---"
umask ${UMASK}

echo "---Checking for optional scripts---"
cp -f /opt/custom/user.sh /opt/scripts/start-user.sh > /dev/null 2>&1 ||:
cp -f /opt/scripts/user.sh /opt/scripts/start-user.sh > /dev/null 2>&1 ||:

if [ -f /opt/scripts/start-user.sh ]; then
  echo "---Found optional script, executing---"
  chmod -f +x /opt/scripts/start-user.sh ||:
  /opt/scripts/start-user.sh || echo "---Optional Script has thrown an Error---"
else
  echo "---No optional script found, continuing---"
fi

echo "---Taking ownership of data...---"
chown -R root:${GID} /opt/scripts
chmod -R 750 /opt/scripts
# Only touch files whose owner/group is wrong. All cluster containers share
# /serverdata/serverfiles, so a blanket chown -R would rewrite every file on
# every start of every server.
find "${DATA_DIR}" \( ! -user "${UID}" -o ! -group "${GID}" \) -exec chown "${UID}:${GID}" {} +

echo "---Starting...---"
# Graceful stop: SaveWorld + DoExit over RCON (internal port, never mapped),
# falling back to SIGTERM. Must finish inside Docker's stop timeout
# (template: --stop-timeout=60): save <= 30 s + DoExit 5 s + exit wait <= 15 s
# + SIGTERM wait <= 5 s = 55 s worst case.
[[ "${RCON_PORT}" =~ ^[0-9]+$ ]] || RCON_PORT=27020
rcon_cmd() {
	timeout "$1" rcon -a "127.0.0.1:${RCON_PORT}" -p "${SRV_ADMIN_PWD}" "$2" 2>&1
}
# Find the server by its full command line: under Wine the process name is not
# reliably "ArkAscendedServer.exe", so pidof can miss it.
ark_pids() {
	pgrep -f 'ArkAscendedServer\.exe' || true
}
term_handler() {
	echo "---Stop requested---"
	if [ -n "$(ark_pids)" ] && command -v rcon >/dev/null 2>&1; then
		echo "---Saving world via RCON...---"
		if OUT="$(rcon_cmd 30 SaveWorld)"; then
			echo "---SaveWorld: ${OUT}---"
			echo "---Sending DoExit---"
			rcon_cmd 5 DoExit >/dev/null || true
			for _ in $(seq 1 15); do
				[ -z "$(ark_pids)" ] && break
				sleep 1
			done
		else
			echo "---WARNING: RCON SaveWorld failed (${OUT}); stopping without a save---"
		fi
	elif [ -z "$(ark_pids)" ]; then
		echo "---WARNING: server process not found, nothing to save---"
	fi
	if [ -n "$(ark_pids)" ]; then
		echo "---Server still running, sending SIGTERM---"
		kill -SIGTERM $(ark_pids) 2>/dev/null
		for _ in $(seq 1 5); do
			[ -z "$(ark_pids)" ] && break
			sleep 1
		done
	fi
	# Only now end the su session (start-server.sh and its log tail). Doing this
	# first, as before, could take the server down before it was saved.
	kill "${killpid}" 2>/dev/null
	echo "---Server stopped---"
	exit 143;
}

trap 'term_handler' SIGTERM
su ${USER} -c "/opt/scripts/start-server.sh" &
killpid="$!"
while true
do
  wait $killpid
  exit 0;
done
