#!/bin/sh
set -e

until $(nc -z kong-database 5432); do
    printf 'Waiting for Postgres instance to respond.\n'
    sleep 2
done

exec tini -- su-exec kong /kong/bin/kong start --v
