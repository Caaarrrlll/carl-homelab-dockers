# fluxer-aio on a shared PostgreSQL server

How to run fluxer-aio's database on a Postgres server that other apps use
too, how to move or rename that server's container without losing data, and
how to take nightly Fluxer backups. Written for Unraid; the SQL and shell
commands work anywhere.

This guide only adds what the fluxer-aio README doesn't cover. Read its
[Requirements](../images/apps/fluxer-aio/README.md#requirements) and
[Backups](../images/apps/fluxer-aio/README.md#backups) sections first.

Placeholders used below:

| Placeholder | Meaning |
|---|---|
| `<unraid-ip>` | LAN address of the Unraid host |
| `<lan-range>` | Your LAN in CIDR form (network address/prefix length) |
| `<pg-container>` | Name of the Postgres container |
| `<pg-image>` | The image (with tag) that container runs |
| `<old-folder>`, `<new-folder>` | Postgres data folders under `/mnt/cache/appdata` |
| `<backup-share>` | A private share for backups |

## 1. Which Postgres image

If Immich already runs on the server, reuse **Immich's** Postgres image
(`ghcr.io/immich-app/postgres:<major>-vectorchord<x>-pgvector<y>`) for the
shared server. Immich needs the vector extensions in it; plain `postgres:18`
breaks Immich. Fluxer needs no extensions and runs fine on it.

Trade-off: Immich decides the Postgres major version and the tag. Follow
Immich's upgrade notes when you change the tag. fluxer-aio's backup client is
PostgreSQL 18, so before the server moves to a newer major version, update
fluxer-aio first (see the README's "Postgres version" note).

## 2. One role and one database per app

Give every app its own login role that owns only its own database. Never
give an app the superuser. For Fluxer (`psql` as the superuser):

```sql
CREATE ROLE fluxer LOGIN PASSWORD '<strong password>';
CREATE DATABASE fluxer OWNER fluxer;
REVOKE ALL ON DATABASE fluxer FROM PUBLIC;
```

The `REVOKE` stops the other apps' roles from connecting to Fluxer's
database (by default every role may connect to every database). Do the same
for each new app. Immich can stay on the superuser it was set up with; moving
it off is optional.

## 3. Host networking for the database

Set the Postgres container's **Network Type** to **Host**. Postgres then
listens on the host's port 5432, and every app connects to
`<unraid-ip>:5432` (in fluxer-aio: `DATABASE_URL`). Apps then don't depend on
the container's name or a Docker network, so renaming or recreating the
database container doesn't touch Fluxer's settings.

**Never forward port 5432 on your router.** Postgres must only be reachable
from the LAN and from containers on the host (see section 7 to enforce that).

## 4. Moving or renaming the database container

Use this to rename the container, move its data folder, or rebuild its
template. The old data folder is never changed, so it stays the rollback
point until you delete it.

Run everything in the Unraid terminal as root. Set these first:

```bash
BK=/mnt/user/<backup-share>/postgres-move-$(date +%F)
OLD=/mnt/cache/appdata/<old-folder>
NEW=/mnt/cache/appdata/<new-folder>
mkdir -p "$BK"
```

### Step 1: Fluxer backup

While fluxer-aio is still running, take a checked backup of its database:

```bash
docker exec fluxer-aio fluxer-aio-backup create before-pg-move
docker exec fluxer-aio fluxer-aio-backup list
```

The new backup must show `verified`. It is a `pg_dump -Fc` archive that was
already checked with `pg_restore --list` and a full read-back. Without
fluxer-aio's tool, the manual equivalent is:

```bash
docker exec <pg-container> pg_dump -U postgres -Fc fluxer > "$BK/fluxer.dump"
docker exec -i <pg-container> pg_restore --list < "$BK/fluxer.dump" | head
```

### Step 2: Stop the apps

Stop every container that uses the database (fluxer-aio, Immich, …). Leave
Postgres running. From here on nothing writes to the database, so the
counts compared in step 3 must match exactly.

### Step 3: Dump everything and prove it restores

Dump all databases and roles:

```bash
docker exec <pg-container> pg_dumpall -U postgres > "$BK/all.sql"
```

Restore that dump into a throwaway container on the **same image** (use the
same extra arguments as the live container, if it has any):

```bash
docker run -d \
    --name pg-restore-test \
    -e POSTGRES_PASSWORD=throwaway \
    <pg-image>
sleep 20
docker exec -i pg-restore-test psql -U postgres -q < "$BK/all.sql"
```

One error, `role "postgres" already exists`, is expected. Any other error
means the dump is not good enough; stop here and find out why.

Then compare the two servers: the same databases, and per database the same
tables with the same row counts:

```bash
# Print "<schema.table> <rows>" for every table of database $2 in container $1
count_rows() {
    docker exec "$1" psql -U postgres -d "$2" -At -c "
        SELECT format('SELECT %L || '' '' || count(*) FROM %I.%I;',
                      schemaname || '.' || relname, schemaname, relname)
        FROM pg_stat_user_tables
        ORDER BY schemaname, relname" \
        | docker exec -i "$1" psql -U postgres -d "$2" -At
}

LIST_DBS="SELECT datname FROM pg_database WHERE NOT datistemplate ORDER BY 1"
docker exec <pg-container> psql -U postgres -At -c "$LIST_DBS" > "$BK/dbs-live.txt"
docker exec pg-restore-test psql -U postgres -At -c "$LIST_DBS" > "$BK/dbs-test.txt"
diff "$BK/dbs-live.txt" "$BK/dbs-test.txt" && echo "databases: same"

for db in $(cat "$BK/dbs-live.txt"); do
    count_rows <pg-container> "$db" > "$BK/rows-live-$db.txt"
    count_rows pg-restore-test "$db" > "$BK/rows-test-$db.txt"
    if diff -q "$BK/rows-live-$db.txt" "$BK/rows-test-$db.txt" > /dev/null; then
        echo "$db: $(wc -l < "$BK/rows-live-$db.txt") tables, row counts match"
    else
        echo "$db: DIFFERENT, compare the two rows-*-$db.txt files"
    fi
done
```

Every line must say `match`. Then remove the test container:

```bash
docker rm -f pg-restore-test
```

### Step 4: Stop Postgres cleanly

Give Postgres time to finish its shutdown checkpoint (Docker's default is
10 s, after which it kills the process):

```bash
docker stop -t 120 <pg-container>
docker logs --tail 5 <pg-container>
docker inspect -f '{{.State.ExitCode}}' <pg-container>
```

The log must end with `database system is shut down` and the exit code must
be `0`. If not, start it again, let it recover, and repeat this step.

### Step 5: Copy the data into a new folder

Copy into a **new** folder; the old one stays untouched as the rollback
point:

```bash
rsync -aH --numeric-ids "$OLD/" "$NEW/"
rsync -aHn --numeric-ids --checksum --itemize-changes "$OLD/" "$NEW/"
```

The second command compares every file's contents and must print nothing.
Don't compare folder sizes instead: they differ between file systems even
when the copy is perfect.

**Never copy between `/mnt/user/X` and `/mnt/cache/X` for the same `X`.**
On Unraid both are views of the same files, so the "copy" overwrites the
files with themselves and can destroy them. Use the same view (here
`/mnt/cache`) for both sides, and a different folder name for `<new-folder>`.

### Step 6: Point the container at the new folder

1. Unraid → **Docker** → edit the Postgres container (or create the new one
   with the new name).
2. Change only the **host** side of the data path to `$NEW`. Keep the
   container side as it was.
3. Add `--restart unless-stopped` to **Extra Parameters**, so Docker
   restarts Postgres if it crashes.
4. Apply, then check the start-up log:

   ```bash
   docker logs <pg-container> 2>&1 | head -20
   ```

   It must say `Skipping initialization` and `database system is ready to
   accept connections`. If it shows `initdb` output instead (`The files
   belonging to this database system…`), it started a new, empty database:
   it is looking at an empty folder: stop it and fix the path. Your data is
   still in `$OLD` and `$NEW`.

### Step 7: Start the apps and check they log in

Start the apps, then check that each one has connected with its own role:

```bash
docker exec <pg-container> psql -U postgres -c "
    SELECT usename, datname, count(*)
    FROM pg_stat_activity
    WHERE usename IS NOT NULL
    GROUP BY usename, datname
    ORDER BY usename"
```

Expect a `fluxer | fluxer` row, plus a row for each other app. Also check
that fluxer-aio becomes `healthy` (README, "Logs and health").

**Rollback:** stop the apps and Postgres, point the data path back to
`$OLD`, start Postgres, then the apps. Delete `$OLD` only after a few days of
normal use.

## 5. Autostart order

The apps fail on start-up if Redis or Postgres isn't ready yet. In Unraid →
**Docker**, drag the containers into this order, with autostart on:

1. Redis
2. Postgres, with a **wait** of about 15 seconds (the field next to its
   autostart switch, in Advanced View)
3. The apps (fluxer-aio, Immich, …)

## 6. Nightly Fluxer backups

fluxer-aio backs itself up before every Fluxer update. For a nightly backup
as well:

1. Map `/data/backups` to a private backup share (template field
   **Backups**; see the README's "Keeping backups elsewhere" before changing
   it on an existing install).
2. Install the **User Scripts** plugin and add a script with this content:

   ```bash
   #!/bin/bash
   # Nightly Fluxer database backup with an Unraid notification on failure

   alert() {
       /usr/local/emhttp/webGui/scripts/notify \
           -e "Fluxer backup" \
           -s "Fluxer backup FAILED" \
           -d "$1" \
           -i alert
       echo "FAILED: $1"
       exit 1
   }

   # Only back up a running container
   if [ "$(docker inspect -f '{{.State.Running}}' fluxer-aio 2>/dev/null)" != "true" ]; then
       alert "fluxer-aio is not running; no backup taken"
   fi

   # Create and verify a backup
   if ! docker exec fluxer-aio fluxer-aio-backup create nightly; then
       alert "fluxer-aio-backup create failed; check: docker exec fluxer-aio fluxer-aio-backup list"
   fi

   # Apply the retention rules
   docker exec fluxer-aio fluxer-aio-backup prune
   ```

3. Schedule it **before** the mover runs (Unraid's default mover time is
   03:40), e.g. custom schedule `0 3 * * *`.

**Retention and update backups.** `prune` keeps the newest **3 verified**
backups, whatever their label. With a nightly backup, the backup taken
before a Fluxer update is therefore deleted after three nights. If you want
to keep it longer, copy it somewhere else, or let your backup job keep older
copies of the share.

## 7. Optional: limit who can connect

By default the Postgres image accepts password logins from any address.
To accept them only from Docker containers on the host and from your LAN:

1. Copy `pg_hba.conf` from the data folder as a backup.
2. In `pg_hba.conf`, keep the `local` and `127.0.0.1` / `::1` lines, and
   replace the `host all all all …` line with:

   ```
   host  all  all  172.16.0.0/12  scram-sha-256
   host  all  all  <lan-range>    scram-sha-256
   ```

   Use the same auth method as your existing lines. `172.16.0.0/12` covers
   Docker's bridge networks.
3. Reload and check the file parsed without errors:

   ```bash
   docker exec <pg-container> psql -U postgres -c "SELECT pg_reload_conf();"
   docker exec <pg-container> psql -U postgres -c "
       SELECT line_number, error FROM pg_hba_file_rules WHERE error IS NOT NULL"
   ```

   The second query must return **0 rows**. Then check every app still
   connects (section 4, step 7). If one doesn't, put the backup copy back and
   reload again.

Port 5432 must still never be forwarded on the router.
