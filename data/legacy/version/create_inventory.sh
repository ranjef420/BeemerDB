#!/usr/bin/env bash
set -euo pipefail

# create_inventory.sh
# Scans filesystem and generates initial MANIFEST.parts.yaml from discovered PDFs
#
# USAGE:
#   ./create_inventory.sh
#   PARTS_DIR="/path/to/parts" OUT="/tmp/test.yaml" ./create_inventory.sh
#
# This script is for INITIAL manifest creation from filesystem.
# For REGENERATING manifest from database, use build_manifest.sh instead.

# -------- config --------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ROOT:-$(dirname "$SCRIPT_DIR")}"

PARTS_DIR="${PARTS_DIR:-$ROOT/parts}"
OUT="${OUT:-$PARTS_DIR/MANIFEST.parts.yaml}"
SOURCE_ROOT="${SOURCE_ROOT:-parts}"

# -------- validation --------
[ -d "$PARTS_DIR" ] || { echo "ERROR: Parts directory not found: $PARTS_DIR" >&2; exit 1; }

# Check for PDFs
pdf_count=$(find "$PARTS_DIR" -type f -name "*.pdf" | wc -l | tr -d ' ')
[ "$pdf_count" -gt 0 ] || { echo "ERROR: No PDFs found in $PARTS_DIR" >&2; exit 1; }

echo "Scanning: $PARTS_DIR"
echo "Found: $pdf_count PDFs"
echo "Output: $OUT"
echo ""

# -------- helper functions --------
slugify() {
  # Convert title to slug: lowercase, & → and, non-alphanumeric → hyphen
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -e 's/&/ and /g' -e 's/[^a-z0-9]\+/-/g' -e 's/^-\+//' -e 's/-\+$//'
}

extract_group() {
  # Extract group number from path like "11-Engine" or "11 - Engine"
  # Returns just the numeric part
  echo "$1" | sed -E 's/^([0-9]+).*/\1/'
}

extract_title() {
  # Extract title from filename: "Camshaft.pdf" → "Camshaft"
  # Also handles underscores: "Cylinder_Head.pdf" → "Cylinder Head"
  basename "$1" .pdf | sed 's/_/ /g'
}

yaml_escape() {
  # Escape special YAML characters in strings
  echo "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# -------- write yaml header --------
mkdir -p "$(dirname "$OUT")"

cat > "$OUT" <<YAML
# MANIFEST.parts.yaml (generated from filesystem scan)
# Created: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
schema: 1
model: "R1150RT (R22) — Type 0499 (Authority)"
source_root: "$SOURCE_ROOT"
conventions:
  id_format: "R22-0499-{group}-{slug}"
  group_dirs: ["11","12","13","16","17","18","21","23","31","32","33","34","35","36","46","51","52","61","62","63","65"]
entries:
YAML

# -------- scan and generate entries --------
find "$PARTS_DIR" -type f -name "*.pdf" | sort | while IFS= read -r pdf; do
  # Get relative path from PARTS_DIR
  rel_path="${pdf#$PARTS_DIR/}"
  
  # Extract directory (group) and filename
  dir_name="$(dirname "$rel_path")"
  file_name="$(basename "$rel_path")"
  
  # Extract group number from directory name
  group=$(extract_group "$dir_name")
  
  # Extract title from filename (PDF name without extension, underscores → spaces)
  title=$(extract_title "$file_name")
  
  # Generate slug from title
  slug=$(slugify "$title")
  
  # Generate ID
  id="R22-0499-${group}-${slug}"
  
  # Escape for YAML
  title_esc=$(yaml_escape "$title")
  path_esc=$(yaml_escape "$rel_path")
  
  # Write entry
  cat >> "$OUT" <<ENTRY
  - id: $id
    group: $group
    title: "$title_esc"
    diagram: null
    path: "$path_esc"
    aliases: []
    tags: []
ENTRY

done

echo "✔ Created manifest: $OUT"
echo "  Entries: $pdf_count"
