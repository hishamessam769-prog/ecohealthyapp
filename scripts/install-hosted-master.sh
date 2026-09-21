#!/bin/sh
set -eu

: "${STAGING_DATABASE_URL:?STAGING_DATABASE_URL is required}"
: "${HOSTED_E2E_ALLOW_EMPTY_DATABASE_INSTALL:?Set HOSTED_E2E_ALLOW_EMPTY_DATABASE_INSTALL=true only for a new disposable Staging database}"

if [ "$HOSTED_E2E_ALLOW_EMPTY_DATABASE_INSTALL" != "true" ]; then
  echo "Refusing to install: HOSTED_E2E_ALLOW_EMPTY_DATABASE_INSTALL must equal true." >&2
  exit 1
fi
if ! command -v supabase >/dev/null 2>&1; then
  echo "Supabase CLI is required. Install it using the official Supabase CLI instructions." >&2
  exit 1
fi

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
staging_dir=$(mktemp -d /private/tmp/eco-hosted-master.XXXXXX)
trap 'rm -rf "$staging_dir"' EXIT INT TERM

mkdir -p "$staging_dir/supabase/migrations"
cp "$project_dir/outputs/01_install_complete_database.sql" "$staging_dir/supabase/migrations/20260917000100_master.sql"
cd "$staging_dir"
supabase init
supabase db push --db-url "$STAGING_DATABASE_URL" --include-all

echo "Exact Master SQL installed on the hosted staging database. Run the hosted validator next."
