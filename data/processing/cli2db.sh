#!/usr/bin/env bash
set -euo pipefail

# Full-text search CLI over parts/index.duckdb with extras filters.
#
# USAGE:
#   query.sh [OPTIONS] -- QUERY TERMS
#
# Options:
#   -d, --db PATH         Path to OEM.duckdb (default: /Users/nickwade/Repos/Broomhilda/parts/OEM.duckdb)
#   -g, --group N         Restrict to BMW group number (e.g., 34)
#   -l, --limit N         Max rows to return (default 25)
#       --exact           Treat the whole query as an exact phrase for FTS
#       --json            Emit JSON output
#       --fields          Include extras fields in JSON output
#       --title STR       Filter title LIKE %STR%
#       --path STR        Filter path  LIKE %STR%
#       --tags STR        Filter extras.tags LIKE %STR%
#       --part STR        Filter extras.part_numbers LIKE %STR%
#       --notes STR       Filter extras.notes LIKE %STR%
#       --realoem STR     Filter extras.realoem LIKE %STR%
#       --order MODE      Sorting: relevance | title | group (default: group)
#   -h, --help            Show this help
#
# Examples:
#   query.sh -- "integral abs front"
#   query.sh -g 34 -- "wheel speed sensor"
#   query.sh --exact -- "Front Wheel Brake – Integral ABS"
#   query.sh --json -l 5 --tags abs -- "modulator"
#   query.sh --title "crowngear" --json -- "rear axle"

# Prefer Homebrew DuckDB, fallback to PATH
DUCKDB_BIN="${DUCKDB_BIN:-/opt/homebrew/bin/duckdb}"
if ! command -v "$DUCKDB_BIN" >/dev/null 2>&1; then
  DUCKDB_BIN="$(command -v duckdb || true)"
fi
[ -n "$DUCKDB_BIN" ] || { echo "ERROR: duckdb not found." >&2; exit 1; }

ROOT="${ROOT:-/Users/nickwade/Repos/BeemerDB}"
DB="${DB:-$ROOT/parts/OEM.duckdb}"
GROUP=""
LIMIT=25
EXACT=0
JSON=0
FIELDS=0
TITLE=""
PATHLIKE=""
TAGS=""
PARTS=""
NOTES=""
REALOEM=""
ORDER="group"

usage() { sed -n '1,60p' "$0" | sed -n 's/^# \{0,1\}//p' | sed '1,35!d'; exit 0; }

# Parse args
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    -d|--db) DB="$2"; shift 2;;
    -g|--group) GROUP="$2"; shift 2;;
    -l|--limit) LIMIT="$2"; shift 2;;
    --exact) EXACT=1; shift;;
    --json) JSON=1; shift;;
    --fields) FIELDS=1; shift;;
    --title) TITLE="$2"; shift 2;;
    --path) PATHLIKE="$2"; shift 2;;
    --tags) TAGS="$2"; shift 2;;
    --part) PARTS="$2"; shift 2;;
    --notes) NOTES="$2"; shift 2;;
    --realoem) REALOEM="$2"; shift 2;;
    --order) ORDER="$2"; shift 2;;
    -h|--help) usage;;
    --) shift; while [ $# -gt 0 ]; do args+=("$1"); shift; done; break;;
    *) args+=("$1"); shift;;
  esac
done

[ -f "$DB" ] || { echo "error: DB not found: $DB" >&2; exit 1; }
[ "${#args[@]}" -gt 0 ] || { echo "error: missing query terms (use -- to separate options from terms)" >&2; usage; }

# Assemble search query
Q="${args[*]}"

# Build SQL query
SQL="SELECT "

if [ "$FIELDS" -eq 1 ]; then
  SQL+="id, group_no, title, diagram, path, part_numbers, realoem, notes, tags"
else
  SQL+="id, group_no, title, diagram, path"
fi

if [ "$FIELDS" -eq 1 ]; then
  SQL+=" FROM docs_view"
else
  SQL+=" FROM docs"
fi

SQL+=" WHERE 1=1"

# FTS search on body
if [ "$EXACT" -eq 1 ]; then
  SQL+=" AND fts_main_docs.match_bm25(id, '\"$Q\"') IS NOT NULL"
else
  SQL+=" AND fts_main_docs.match_bm25(id, '$Q') IS NOT NULL"
fi

# Additional filters
[ -n "$GROUP" ] && SQL+=" AND group_no = $GROUP"
[ -n "$TITLE" ] && SQL+=" AND title ILIKE '%$TITLE%'"
[ -n "$PATHLIKE" ] && SQL+=" AND path ILIKE '%$PATHLIKE%'"

if [ "$FIELDS" -eq 1 ]; then
  [ -n "$TAGS" ] && SQL+=" AND tags ILIKE '%$TAGS%'"
  [ -n "$PARTS" ] && SQL+=" AND part_numbers ILIKE '%$PARTS%'"
  [ -n "$NOTES" ] && SQL+=" AND notes ILIKE '%$NOTES%'"
  [ -n "$REALOEM" ] && SQL+=" AND realoem ILIKE '%$REALOEM%'"
fi

# Ordering
case "$ORDER" in
  relevance) SQL+=" ORDER BY fts_main_docs.match_bm25(id, '$Q') DESC";;
  title) SQL+=" ORDER BY title";;
  group) SQL+=" ORDER BY group_no, title";;
  *) SQL+=" ORDER BY group_no, title";;
esac

SQL+=" LIMIT $LIMIT;"

# Execute query
if [ "$JSON" -eq 1 ]; then
  "$DUCKDB_BIN" "$DB" -json -c "$SQL"
else
  "$DUCKDB_BIN" "$DB" -box -c "$SQL"
fi