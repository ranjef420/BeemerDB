# /Users/nickwade/Hilde/scripts/emit_manifest.sh
#!/usr/bin/env bash
set -euo pipefail

DB="${1:-/Users/nickwade/Hilde/index/index.sqlite}"
OUT="${2:-/Users/nickwade/Hilde/scripts/MANIFEST.parts.yaml}"

# Where PDFs will live in the repo (the entry 'path' stays relative to this root)
SOURCE_ROOT="Tier1-OEM/parts/pdf"

# YAML-escape helper (double-quoted scalars)
yaml_escape() {
  # Escapes backslashes and double quotes; preserves UTF-8 like en dashes
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# Header
cat > "$OUT" <<YAML
# MANIFEST.parts.yaml (generated from index.sqlite)
schema: 1
model: "R1150RT (R22) — Type 0499 (Authority)"
source_root: "$SOURCE_ROOT"
conventions:
  id_format: "R22-0499-{group}-{slug}"
  group_dirs: ["11","12","13","16","17","18","21","23","31","32","33","34","35","36","46","51","52","61","62","63","65"]
entries:
YAML

# Pull rows as TAB-separated values to avoid CSV quoting
# Fields: group_no \t title \t diagram \t path
sqlite3 -separator $'\t' "$DB" \
  "SELECT group_no, title, IFNULL(diagram,''), path
   FROM docs
   ORDER BY CAST(group_no AS INT), title;" \
| awk -v OUT="$OUT" '
  function tolower_ascii(s,  r,i,c){
    r=""; for(i=1;i<=length(s);i++){c=substr(s,i,1); if(c>="A" && c<="Z"){c=tolower(c)}; r=r c} return r
  }
  function slugify(s,  t){
    t=s
    gsub(/[\r\n]/, "", t)
    t=tolower_ascii(t)
    gsub(/&/, " and ", t)
    gsub(/[^a-z0-9]+/, "-", t)
    gsub(/^-+|-+$/, "", t)
    return t
  }
  function yesc(s){
    gsub(/\r/,"",s)
    gsub(/\\/,"\\\\",s)
    gsub(/"/,"\\\"",s)
    return s
  }
  BEGIN{ FS="\t"; }
  {
    group=$1; title=$2; diagram=$3; path=$4;

    # Build id
    slug = slugify(title)
    id = "R22-0499-" group "-" slug
    if (diagram != "" && diagram != " ") {
      gsub(/[^A-Za-z0-9_]/,"",diagram)
      id = id "-" diagram
    }

    # YAML-safe
    title = yesc(title)
    path  = yesc(path)

    print "  - id: " id >> OUT
    print "    group: " group >> OUT
    print "    title: \"" title "\"" >> OUT
    if (diagram != "" && diagram != " ") {
      print "    diagram: \"" diagram "\"" >> OUT
    } else {
      print "    diagram: null" >> OUT
    }
    print "    path: \"" path "\"" >> OUT
    print "    aliases: []" >> OUT
    print "    tags: []" >> OUT
  }'

echo "Wrote $OUT"