#!/bin/sh

set -eu

if [ "$#" -eq 0 ]; then
    set -- quasselcore
elif [ "${1#-}" != "$1" ]; then
    set -- quasselcore "$@"
fi

if [ "$1" != "quasselcore" ]; then
    exec "$@"
fi

configdir_set=0
env_config_set=0
skip_database_wait=0
skip_auto_env_config=0

for arg in "$@"; do
    case "$arg" in
        -c|--configdir|--configdir=*)
            configdir_set=1
            ;;
        --config-from-environment)
            env_config_set=1
            ;;
        -h|--help|--version)
            skip_database_wait=1
            ;;
        --select-backend|--select-backend=*)
            skip_auto_env_config=1
            ;;
    esac
done

mkdir -p "${QUASSEL_CONFIGDIR}"

if [ -n "${DB_BACKEND:-}" ] && [ -z "${AUTH_AUTHENTICATOR:-}" ]; then
    export AUTH_AUTHENTICATOR=Database
fi

if [ "${WAIT_FOR_POSTGRES:-1}" = "1" ] \
    && [ "${DB_BACKEND:-}" = "PostgreSQL" ] \
    && [ -n "${DB_PGSQL_HOSTNAME:-}" ] \
    && [ "$skip_database_wait" -eq 0 ]; then
    retries=${POSTGRES_WAIT_RETRIES:-30}

    echo "Waiting for PostgreSQL at ${DB_PGSQL_HOSTNAME}:${DB_PGSQL_PORT:-5432}..."

    while [ "$retries" -gt 0 ]; do
        if [ -n "${DB_PGSQL_USERNAME:-}" ]; then
            if pg_isready -h "${DB_PGSQL_HOSTNAME}" \
                -p "${DB_PGSQL_PORT:-5432}" \
                -U "${DB_PGSQL_USERNAME}" \
                -d "${DB_PGSQL_DATABASE:-postgres}" >/dev/null 2>&1; then
                break
            fi
        elif pg_isready -h "${DB_PGSQL_HOSTNAME}" \
            -p "${DB_PGSQL_PORT:-5432}" \
            -d "${DB_PGSQL_DATABASE:-postgres}" >/dev/null 2>&1; then
            break
        fi

        retries=$((retries - 1))
        sleep 2
    done

    if [ "$retries" -eq 0 ]; then
        echo "PostgreSQL did not become ready in time." >&2
        exit 1
    fi
fi

if [ "$configdir_set" -eq 0 ]; then
    set -- "$@" "--configdir=${QUASSEL_CONFIGDIR}"
fi

if [ -n "${DB_BACKEND:-}" ] && [ "$env_config_set" -eq 0 ] && [ "$skip_auto_env_config" -eq 0 ]; then
    set -- "$@" "--config-from-environment"
fi

exec "$@"
