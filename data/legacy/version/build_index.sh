# /Users/nickwade/Hilde/scripts/build_index.sh
#!/usr/bin/env bash
set -euo pipefail

PDF_DIR="${1:?ocr dir (e.g., /Users/nickwade/Hilde/parts_ocr)}"
DB_IN="${2:?db path OR directory (e.g., /Users/nickwade/Hilde/index or .../index.sqlite)}"

# If DB arg is a directory, write index.sqlite inside it
if [ -d "$DB_IN" ]; then
  DB="${DB_IN%/}/index.sqlite"
else
  DB="$DB_IN"
fi

# Fresh DB
rm -f "$DB"
sqlite3 "$DB" 'PRAGMA journal_mode=WAL;'
sqlite3 "$DB" 'CREATE VIRTUAL TABLE docs USING fts5(path, group_no, title, diagram, text, tokenize="porter");'

# Walk all PDFs
while IFS= read -r pdf; do
  rel="${pdf#$PDF_DIR/}"

  # group number from top-level dir prefix like "61 - Electrical System/..."
  group_no="$(echo "$rel" | cut -d'/' -f1 | awk '{print $1}')"

  title="$(basename "$pdf" .pdf)"
  # pull codes like (23_0744) if present
  diagram="$(echo "$title" | sed -n 's/.*(\([0-9][0-9]_[0-9]\{4\}\)).*/\1/p')"

  tmp="$(mktemp)"
  pdftotext -layout "$pdf" "$tmp"

  # Escape single quotes for SQL
  esc_path="${rel//\'/\'\'}"
  esc_group="${group_no//\'/\'\'}"
  esc_title="${title//\'/\'\'}"
  esc_diagram="${diagram//\'/\'\'}"
  esc_text="$(sed "s/'/''/g" "$tmp")"

  sqlite3 "$DB" <<SQL
INSERT INTO docs (path, group_no, title, diagram, text)
VALUES ('$esc_path', '$esc_group', '$esc_title', '$esc_diagram', '$esc_text');
SQL

  rm -f "$tmp"
done < <(find "$PDF_DIR" -type f -name '*.pdf' | sort)

# Helpful stats
sqlite3 "$DB" 'SELECT count(*) AS total_docs FROM docs;'