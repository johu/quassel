# Migrating to the Dockerized PostgreSQL deployment

This guide covers moving an existing `quasselcore` installation into the
repository's Docker Compose deployment.

It assumes:

- the old core is stopped before migration begins
- you have a backup of the old Quassel config directory
- you want the new containerized deployment to use PostgreSQL

## 1. Find and back up the current config directory

Common locations include:

- `/var/lib/quassel`
- `~/.config/Quassel`
- a custom path previously passed with `--configdir`

Back up the full directory before making any changes. When SQLite is in use,
this directory contains the `quassel-storage.sqlite` database alongside TLS
material and other core configuration.

## 2. Prepare the Compose deployment

Copy the example environment file and set a database password:

```sh
cp .env.example .env
```

Create the data directories used by the Compose stack:

```sh
mkdir -p docker-data/postgres docker-data/quassel
```

Copy the backed-up Quassel config directory into `docker-data/quassel`:

```sh
cp -a /path/to/old/quassel-config/. docker-data/quassel/
```

## 3. Start PostgreSQL first

Bring up PostgreSQL and wait for the health check to report ready:

```sh
docker compose up -d postgres
```

## 4. Migrate SQLite data into PostgreSQL

If the old installation already used PostgreSQL, skip to the next section after
confirming that `.env` points at the correct database. Otherwise run:

```sh
docker compose run --rm quasselcore --select-backend PostgreSQL
```

This uses Quassel's existing backend switch and migration path. The container
keeps both the SQLite and PostgreSQL Qt SQL drivers available so the migration
can read the old SQLite database and write the new PostgreSQL schema. When
prompted for the new backend settings, use the same PostgreSQL host, port,
database, username, and password that you configured in `.env` for the Compose
deployment.

## 5. Start the containerized core

Create or verify the admin user if needed:

```sh
docker compose run --rm quasselcore --add-user
```

Then start the core normally:

```sh
docker compose up -d quasselcore
```

Reconnect a client and confirm the expected networks, identities, backlog, and
certificates are present.

## 6. Cleanup and rollback notes

- Leave the original backup untouched until you are confident the new setup is
  stable.
- Keep `docker-data/quassel/quassel-storage.sqlite` until you no longer need
  rollback.
- If you need to roll back, stop the Compose stack and restart the original
  host installation against the untouched backup.

## Existing PostgreSQL installations

If your old `quasselcore` already used PostgreSQL, the migration is mostly a
containerization step:

1. stop the old core
2. copy the existing Quassel config directory into `docker-data/quassel`
3. point `.env` at the existing PostgreSQL database
4. start `postgres` only if you also want Docker to host the database
5. start `quasselcore` in Compose
