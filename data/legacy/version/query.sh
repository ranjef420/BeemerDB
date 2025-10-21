#!/usr/bin/env bash
set -euo pipefail
DB="${1:?/path/to/index.sqlite}"
Q="${2:?query terms}"
ESC_Q="$(printf "%s" "$Q" | sed "s/'/''/g")"
sqlite3 -csv "$DB" "
SELECT group_no, title, diagram, path
FROM docs
WHERE docs MATCH '$ESC_Q'
LIMIT 25;"
