#!/usr/bin/env bash

set -euo pipefail

: "${DB_HOST:?Need to set DB_HOST}"
: "${DB_PORT:=5432}"
: "${DB_NAME:?Need to set DB_NAME}"
: "${DB_USER:?Need to set DB_USER}"

# SQL: list public tables without row level security enabled
SQL=$'SELECT n.nspname AS table_schema, c.relname AS table_name\nFROM pg_class c\nJOIN pg_namespace n ON n.oid = c.relnamespace\nWHERE n.nspname = \'public\'\n  AND c.relkind = \'r\'  -- ordinary table\n  AND c.relrowsecurity = false;'

echo "Running RLS check on ${DB_HOST}:${DB_PORT}/${DB_NAME}..."

RESULT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "$SQL")

if [[ -n "${RESULT//[[:space:]]/}" ]]; then
  echo "ERROR: The following public tables do not have RLS enabled:"
  echo "$RESULT"
  echo "Failing the check. Ensure migrations enable RLS and add appropriate policies."
  exit 1
fi

echo "OK: All public tables have RLS enabled."
exit 0
