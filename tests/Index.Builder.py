# BMW R1150RT Parts Index Builder - DuckDB Version
# Combines MANIFEST.parts.yaml + OCR text → DuckDB FTS database

# Prefer Homebrew DuckDB, fallback to PATH
DUCKDB_BIN="${DUCKDB_BIN:-/opt/homebrew/bin/duckdb}"
if ! command -v "$DUCKDB_BIN" >/dev/null 2>&1; then
  DUCKDB_BIN="$(command -v duckdb || true)"
fi
[ -n "$DUCKDB_BIN" ] || { echo "ERROR: duckdb not found. Install: brew install duckdb" >&2; exit 1; }

ROOT="/Users/nickwade/Repos/Broomhilda"
MANIFEST="$ROOT/parts/MANIFEST.parts.yaml"
OCR_DIR="$ROOT/parts_ocr"
DB="$ROOT/parts/index.duckdb"

# Verify inputs exist
[ -f "$MANIFEST" ] || { echo "ERROR: MANIFEST not found at $MANIFEST" >&2; exit 1; }
[ -d "$OCR_DIR" ] || { echo "ERROR: OCR directory not found at $OCR_DIR" >&2; exit 1; }

mkdir -p "$(dirname "$DB")"

echo "• Building DuckDB index at $DB"

# Create/recreate database with YAML extension
"$DUCKDB_BIN" "$DB" <<'SQL'
-- Install and load YAML extension
INSTALL yaml FROM community;
LOAD yaml;
INSTALL fts;
LOAD fts;

-- Drop existing tables if they exist
DROP TABLE IF EXISTS docs;
DROP TABLE IF EXISTS extras;
DROP VIEW IF EXISTS docs_view;

-- Create base table from YAML manifest
-- DuckDB can read YAML directly with the extension
CREATE TABLE docs AS
SELECT 
  row_number() OVER () AS id,
  CAST(group AS INTEGER) AS group_no,
  title,
  diagram,
  path,
  '' AS body  -- Will be populated with OCR text
FROM read_yaml('/Users/nickwade/Repos/Broomhilda/parts/MANIFEST.parts.yaml', 
               columns={group: 'VARCHAR', title: 'VARCHAR', diagram: 'VARCHAR', path: 'VARCHAR'});

-- Schema extensions: lightweight extras keyed by path (unique)
CREATE TABLE extras (
  path TEXT PRIMARY KEY,
  part_numbers TEXT,  -- CSV or JSON string
  realoem TEXT,       -- URL or code
  notes TEXT,
  tags TEXT           -- CSV or JSON string
);

-- Unified view for downstream tools
CREATE VIEW docs_view AS
SELECT d.id, d.group_no, d.title, d.diagram, d.path, d.body,
       e.part_numbers, e.realoem, e.notes, e.tags
FROM docs d
LEFT JOIN extras e ON e.path = d.path;

SQL

# Now populate OCR body text using Python
# (Keep Python for this part since OCR file reading is complex)
VENV="$ROOT/.venv"
PY="$VENV/bin/python3"

if [ ! -x "$PY" ]; then
  echo "• Creating Python venv at $VENV"
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --upgrade pip >/dev/null
fi

echo "• Populating OCR text bodies"

"$PY" - <<'PY'
import os
import duckdb

ROOT = "/Users/nickwade/Repos/Broomhilda"
OCR_DIR = os.path.join(ROOT, "parts_ocr")
DB = os.path.join(ROOT, "parts", "index.duckdb")

def read_body(rel_path):
    """Read OCR text file corresponding to PDF path"""
    # rel_path is like "34 - Brakes/Front Wheel Brake – Integral ABS.pdf"
    txt = os.path.join(OCR_DIR, os.path.splitext(rel_path)[0] + ".txt")
    try:
        with open(txt, "r", encoding="utf-8", errors="ignore") as t:
            return t.read().replace("\0", " ")
    except FileNotFoundError:
        return ""

# Connect to DuckDB
conn = duckdb.connect(DB)

# Get all paths from docs table
paths = conn.execute("SELECT id, path FROM docs ORDER BY id").fetchall()

# Update each row with OCR body text
for doc_id, path in paths:
    body_text = read_body(path)
    conn.execute("UPDATE docs SET body = ? WHERE id = ?", [body_text, doc_id])

# Create FTS index on body text
conn.execute("""
    PRAGMA create_fts_index('docs', 'id', 'body', overwrite=1);
""")

conn.close()
print(f"✓ Updated {len(paths)} documents with OCR text")
PY

echo "✔ Index built at $DB"
echo ""
echo "Query with: ./scripts/query.sh -- 'your search terms'"