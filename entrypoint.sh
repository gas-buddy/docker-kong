#!/bin/sh
set -e

# If your arguments start with -, assume they are arguments for Kong
# and prepend kong-app to them
if [ "${1#-}" != "${1}" ]; then
  set -- kong-app "$@"
fi

# If the first arg is kong-app, run kong, else run whatever you said
if [ "$1" = 'kong-app' ]; then
  # If we're running kong, make sure we have a db
  until $(nc -z kong-database 5432); do
    printf 'Waiting for Postgres instance to respond.\n'
    sleep 2
  done

  shift
  [ "$#" -gt 0 -a "$1" != '--' ] && set -- '--' "$@"
  if [ "$#" -gt 0 ]; then
    exec tini -- su-exec kong /kong/bin/kong start "$@"
  else
    exec tini -- su-exec kong /kong/bin/kong start
  fi
fi

# Run what you told us to run
exec "$@"