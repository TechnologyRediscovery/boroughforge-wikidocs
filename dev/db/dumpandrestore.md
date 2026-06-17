---
title: Dumping and restoring postgres database
description: 
published: true
date: 2025-12-12T19:56:31.372Z
tags: 
editor: markdown
dateCreated: 2025-12-12T19:56:25.288Z
---

# Postgres dump and restore

## Dumping
CNF is build on PostgreSQL database which exposes pg_dump and pg_restore tools along with variants.

Here is the dump script ECD has used for exporting the local db. This will dump all the bytea type column data along with the regular textual data.


```
#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./dump_cogdb.sh [output_dir] [dbname]
# Defaults:
#   output_dir = .
#   dbname     = cogdb
#
# Configure connection via env vars (recommended):
#   PGHOST, PGPORT, PGUSER, PGPASSWORD (or ~/.pgpass)
#
# Example:
#   PGHOST=localhost PGUSER=postgres ./dump_cogdb.sh /backups cogdb

OUT_DIR="${1:-.}"
DB_NAME="${2:-cogdb}"

mkdir -p "$OUT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
OUT_FILE="${OUT_DIR%/}/${DB_NAME}_${TS}.tar"

echo "Dumping database '${DB_NAME}' to: ${OUT_FILE}"
echo "Host: ${PGHOST:-'(default)'}  Port: ${PGPORT:-'(default)'}  User: ${PGUSER:-'(default)'}"

pg_dump \
  --format=tar \
  --encoding=UTF8 \
  --no-owner \
  --no-large-objects \
  --no-privileges \
  --no-tablespaces \
  --section=pre-data \
  --section=data \
  --section=post-data \
  -f "$OUT_FILE" \
  "$DB_NAME"

echo "Done."
echo "To inspect:  pg_restore -l '$OUT_FILE' | less"
```

## Restoring
Make a new database for the restore
```
sudo su postgres
psql
```
Then you'll be in an interactive shell with postgres superuser
```
CREATE DATABASE cogdbversionx;
ALTER DATABASE cogdbversionx OWNER TO your_owner_role;
GRANT ALL PRIVILEGES ON DATABASE cogdbversionx TO contractor_user;
```

Then we can run the actual restore command:
```
pg_restore \
  -h TARGET_HOST -p 5432 -U contractor_user \
  --no-owner --no-privileges \
  --exit-on-error \
  -d cogdbversionx \
  -v \
  /path/to/cogdb_dump.tar
```
