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
# (template: --stop-timeout=60): RCON save <= 30 s, DoExit wait <= 20 s.
[[ "${RCON_PORT}" =~ ^[0-9]+$ ]] || RCON_PORT=27020
rcon_cmd() {
	timeout "$1" rcon -a "127.0.0.1:${RCON_PORT}" -p "${SRV_ADMIN_PWD}" "$2" 2>&1
}
term_handler() {
	echo "---Stop requested---"
	if [ -n "$(pidof ArkAscendedServer.exe)" ] && command -v rcon >/dev/null 2>&1; then
		echo "---Saving world via RCON...---"
		if OUT="$(rcon_cmd 30 SaveWorld)"; then
			echo "---SaveWorld: ${OUT}---"
			echo "---Sending DoExit---"
			rcon_cmd 5 DoExit >/dev/null || true
			for _ in $(seq 1 20); do
				[ -z "$(pidof ArkAscendedServer.exe)" ] && break
				sleep 1
			done
		else
			echo "---WARNING: RCON SaveWorld failed (${OUT}); stopping without a save---"
		fi
	fi
	if [ -n "$(pidof ArkAscendedServer.exe)" ]; then
		echo "---Server still running, sending SIGTERM---"
		kill -SIGTERM $(pidof ArkAscendedServer.exe)
		tail --pid=$(pidof ArkAscendedServer.exe | awk '{print $1}') -f 2>/dev/null
	fi
	echo "---Server stopped---"
	exit 143;
}

trap 'kill ${!}; term_handler' SIGTERM
su ${USER} -c "/opt/scripts/start-server.sh" &
killpid="$!"
while true
do
  wait $killpid
  exit 0;
done
