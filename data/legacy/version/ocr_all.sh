#!/usr/bin/env bash
set -euo pipefail

# OCR the entire parts tree with:
# - hash-based cache (skip unchanged PDFs)
# - ImageMagick preprocessing (deskew/normalize, optional binarize)
# - per-page TSV extraction for confidence stats
# - progress bar + end-of-run QC summary
#
# USAGE:
#   BINARIZE=1 LANGS="eng" ./ocr_all.sh
#
# Env knobs:
#   ROOT      (default /Users/nickwade/Repos/Broomhilda)
#   PDF_DIR   (default $ROOT/parts)
#   OCR_DIR   (default $ROOT/parts_ocr)
#   DPI       (default 300)
#   LANGS     (default eng)
#   PAGES     (e.g. "1-3,7" – optional)
#   QC_MIN    (default 65 – warn if avg conf < QC_MIN)
#
# Requires: pdftoppm, tesseract, (magick|convert), shasum, awk, sed

ROOT="${ROOT:-/Users/nickwade/Repos/Broomhilda}"
PDF_DIR="${PDF_DIR:-$ROOT/parts}"
OCR_DIR="${OCR_DIR:-$ROOT/parts_ocr}"
HASH_DIR="$OCR_DIR/.hashes"
DPI="${DPI:-300}"
LANGS="${LANGS:-eng}"
PAGES="${PAGES:-}"
BINARIZE="${BINARIZE:-0}"
QC_MIN="${QC_MIN:-65}"

# Pick ImageMagick entrypoint
if command -v magick >/dev/null 2>&1; then
  IM="magick"
elif command -v convert >/dev/null 2>&1; then
  IM="convert"
else
  echo "Missing ImageMagick: brew install imagemagick" >&2
  exit 1
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; }
need pdftoppm
need tesseract
need shasum
need awk
need sed

mkdir -p "$OCR_DIR" "$HASH_DIR"

# Preprocess: deskew + normalize (+ optional binarize)
_preprocess() {
  local in="$1" out="$2"
  if [ "$BINARIZE" = "1" ]; then
    "$IM" "$in" -deskew 40% -normalize -threshold 60% "$out"
  else
    "$IM" "$in" -deskew 40% -normalize "$out"
  fi
}

_hash() { shasum -a 256 "$1" | awk '{print $1}'; }

# Render subset of pages if PAGES=… is set (macOS/BSD-safe)
_keep_selected_pages() {
  # $1=tmpdir with page-*.png already rendered, $2=selection "1-3,7"
  local tmpdir="$1" sel="$2"
  # Produce canonical list: 1,2,3,7…
  local keep
  keep="$(python3 - <<'PY'
import sys
sel = sys.argv[1]
pages=set()
for part in sel.split(','):
    part=part.strip()
    if not part: continue
    if '-' in part:
        a,b = part.split('-',1)
        for i in range(int(a), int(b)+1):
            pages.add(i)
    else:
        pages.add(int(part))
print(",".join(map(str,sorted(pages))))
PY
  "$sel")"
  # Delete pages not in "keep"
  for f in "$tmpdir"/page-*.png; do
    [ -e "$f" ] || continue
    local bn num
    bn="$(basename "$f")"
    num="${bn#page-}"; num="${num%.*}"; num="${num#0}"; [ -z "$num" ] && num=0
    case ",$keep," in *,"$num",*) : ;; *) rm -f "$f" ;; esac
  done
}

# OCR one PDF → .txt + QC summary lines → return avg conf
_ocr_pdf() {
  local pdf="$1"
  local rel="${pdf#$PDF_DIR/}"
  local base="${rel%.*}"
  local ocr_txt="$OCR_DIR/$base.txt"
  local ocr_dir; ocr_dir="$(dirname "$ocr_txt")"
  local hashfile="$HASH_DIR/${base//\//__}.sha256"

  mkdir -p "$ocr_dir" "$(dirname "$hashfile")"

  local newhash oldhash
  newhash="$(_hash "$pdf")"
  oldhash="$( [ -f "$hashfile" ] && cat "$hashfile" || echo "" )"

  if [ "$newhash" = "$oldhash" ] && [ -s "$ocr_txt" ]; then
    echo "SKIP (cached): $rel"
    echo "QC,$rel,CACHED" >> "$QC_TMP"
    return 0
  fi

  echo "OCR: $rel"
  local tmpdir; tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  # Render to PNGs
  pdftoppm -png -r "$DPI" "$pdf" "$tmpdir/page" >/dev/null 2>&1
  [ -n "$PAGES" ] && _keep_selected_pages "$tmpdir" "$PAGES"

  : > "$ocr_txt"
  local sum=0 cnt=0

  for f in "$tmpdir"/page-*.png; do
    [ -e "$f" ] || continue
    _preprocess "$f" "$tmpdir/pp.png"

    # Get TSV for confidence + extract plain text from TSV
    # (single tesseract call per page)
    tesseract "$tmpdir/pp.png" "$tmpdir/pp" -l "$LANGS" --psm 3 tsv >/dev/null 2>&1

    # Mean confidence for this page (ignore -1)
    local pconf
    pconf="$(awk -F'\t' 'NR>1 && $10 != "-1" {n++; s+=$10} END{if(n>0) printf("%.1f", s/n); else print "0.0"}' "$tmpdir/pp.tsv")"
    # Text column → txt
    awk -F'\t' 'NR>1 {print $11}' "$tmpdir/pp.tsv" >> "$ocr_txt"
    printf "\n" >> "$ocr_txt"

    # accumulate
    sum="$(awk "BEGIN {printf(\"%.3f\", $sum + $pconf)}")"
    cnt=$((cnt+1))
  done

  local avg="0.0"
  if [ "$cnt" -gt 0 ]; then
    avg="$(awk "BEGIN {printf(\"%.1f\", $sum / $cnt)}")"
  fi

  echo "$newhash" > "$hashfile"
  echo "QC,$rel,$avg" >> "$QC_TMP"
}

# Progress bar (macOS-safe)
progress_bar() {
  # $1=done, $2=total, $3=prefix
  local done="$1" total="$2" prefix="$3"
  local width=40
  local filled=$(( (done * width) / total ))
  local empty=$(( width - filled ))
  printf "\r%s [%s%s] %d/%d" \
    "$prefix" "$(printf "%0.s#" $(jot - 1 "$filled" 1 2>/dev/null || seq "$filled" 2>/dev/null))" \
    "$(printf "%0.s." $(jot - 1 "$empty" 1 2>/dev/null || seq "$empty" 2>/dev/null))" \
    "$done" "$total"
}

# Collect list and run
mapfile_read() {
  # BSD readarray alternative
  i=0
  while IFS= read -r line; do
    _PDFS[$i]="$line"
    i=$((i+1))
  done
}

declare -a _PDFS
mapfile_read < <(find "$PDF_DIR" -type f -name '*.pdf' | sort)

TOTAL=${#_PDFS[@]}
[ "$TOTAL" -eq 0 ] && { echo "No PDFs found under $PDF_DIR"; exit 0; }

QC_TMP="$(mktemp)"
trap 'rm -f "$QC_TMP"' EXIT

echo "Found $TOTAL PDFs. Starting OCR (cache respected)…"
done=0
for pdf in "${_PDFS[@]}"; do
  _ocr_pdf "$pdf"
  done=$((done+1))
  progress_bar "$done" "$TOTAL" "Processing"
done
printf "\n"

# QC summary
echo
echo "=== OCR Quality Summary (avg confidence per doc) ==="
low=0
while IFS=, read -r tag rel avg; do
  [ "$tag" = "QC" ] || continue
  if [ "$avg" = "CACHED" ]; then
    printf "  [CACHED] %s\n" "$rel"
  else
    printf "  [%s] %s (avg=%.1f)\n" "$( [ "$(awk "BEGIN{print ($avg < $QC_MIN)}")" = 1 ] && echo "WARN" || echo "OK" )" "$rel" "$avg"
    if awk "BEGIN{exit !($avg < $QC_MIN)}"; then low=$((low+1)); fi
  fi
done < "$QC_TMP"

if [ "$low" -gt 0 ]; then
  echo
  echo "⚠ $low file(s) below QC_MIN=$QC_MIN. Consider re-scanning or adjusting preprocessing."
fi

echo "✔ OCR complete → $OCR_DIR"