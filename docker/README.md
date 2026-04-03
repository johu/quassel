# Dockerized quasselcore

This repository now ships a container-focused deployment path for
`quasselcore`. The image is intended to work on standard Linux hosts and can
also be published as a multi-architecture image for targets such as Raspberry
Pi 4 systems.

The reference deployment uses:

- a dedicated `quasselcore` image built from this repository
- PostgreSQL 16 for persistent backlog and settings storage
- a host-mounted Quassel config directory for certificates and remaining
  core-side state
- an Alpine-based runtime image, while the builder stage stays on Ubuntu to
  reuse the validated Qt6/CMake package set

## Quick start: local build

1. Copy the example environment file and set a real database password.

   ```sh
   cp .env.example .env
   ```

2. Create the persistent data directories.

   ```sh
   mkdir -p docker-data/postgres docker-data/quassel
   ```

3. Build the image and start PostgreSQL.

   ```sh
   docker compose up -d postgres
   docker compose build quasselcore
   ```

   On minimal Docker installations, make sure the Docker Buildx plugin is
   available before running `docker compose build`.

4. Create the initial core user.

   ```sh
   docker compose run --rm quasselcore --add-user
   ```

5. Start the core.

   ```sh
   docker compose up -d quasselcore
   ```

By default the core listens on port `4242`, which is mapped from the container
to the host through `QUASSEL_PORT`.

## Quick start: published image

If you want to deploy a published image instead of building locally, use the
release-oriented Compose file:

```sh
cp .env.example .env
mkdir -p docker-data/postgres docker-data/quassel
docker compose -f docker-compose.release.yml pull
docker compose -f docker-compose.release.yml up -d
```

Set `QUASSEL_IMAGE` in `.env` if you want a specific tag or if you are using a
fork that publishes under a different GitHub organization or user.

## Operational notes

- `./docker-data/quassel` stores the Quassel config directory, including generated TLS
  material and any remaining file-based state.
- `./docker-data/postgres` stores PostgreSQL data.
- The entrypoint automatically adds `--configdir=/var/lib/quassel` and
  `--config-from-environment` when database environment variables are present.
- The container defaults `AUTH_AUTHENTICATOR=Database` unless you override it
  explicitly.
- The runtime image is Alpine-based, but it carries the glibc/Qt runtime
  closure copied from the Ubuntu builder stage so the validated Qt6 build keeps
  working.
- The image keeps both the SQLite and PostgreSQL Qt SQL drivers installed so
  the same container can perform a SQLite-to-PostgreSQL migration.

## Common admin commands

Create another user:

```sh
docker compose run --rm quasselcore --add-user
```

Change an existing password:

```sh
docker compose run --rm quasselcore --change-userpass=username
```

Switch the configured backend and migrate data:

```sh
docker compose run --rm quasselcore --select-backend PostgreSQL
```

That command intentionally does **not** auto-apply `--config-from-environment`,
because Quassel needs to read the currently configured backend first and then
prompt for the new PostgreSQL settings during migration.

## Using the published image

The local `docker-compose.yml` file builds from the working tree. The
`docker-compose.release.yml` file is the release/deployment path and pulls a
published image instead.

If CI publishing is enabled for your repository, the workflow publishes to
GitHub Container Registry as:

```text
ghcr.io/<owner>/quasselcore:<tag>
```

The current workflow only pushes images when all of the following are true:

- GitHub Actions is enabled for the repository
- the workflow run is **not** a pull request
- the ref is the repository's `master` branch or a tag
- the workflow can publish packages with the repository `GITHUB_TOKEN`

In practice, that means regular PRs and most branch builds only verify that the
image builds; they do not publish anything. To make published images usable for
others, maintainers should also ensure the resulting GHCR package visibility is
set appropriately for their distribution model.

For release-style deployments, prefer `docker-compose.release.yml` and set
`QUASSEL_IMAGE` in `.env` to the branch, tag, or release image you want to run.

## Migration from an existing installation

See [docker/MIGRATION.md](MIGRATION.md) for a documented move from a standard
host installation to the Dockerized PostgreSQL deployment.
