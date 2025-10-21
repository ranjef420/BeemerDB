set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# change if you prefer a venv path
PY := "python3"
PIP := "pip3"

# --- bootstrap OS-level & Python deps
bootstrap:
	@echo "==> Homebrew bundle"
	brew bundle --file=Brewfile
	@echo "==> Python deps"
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements.txt

# --- verify DuckDB & extensions
duckdb: 
	duckdb -c "SELECT 'duckdb ok' AS msg; PRAGMA version;"

duckdb-ext:
	duckdb -c "LOAD fts; LOAD vss; LOAD sqlite; LOAD httpfs; LOAD json; LOAD excel; LOAD icu; SELECT 'extensions ready' msg;"

# --- OCR smoke test
ocr-smoke sample.pdf:
	ocrmypdf --version
	ocrmypdf --sidecar /tmp/sidecar.txt {{sample.pdf}} /tmp/out_ocr.pdf
	@test -s /tmp/sidecar.txt && echo "OCR sidecar OK"

# --- Camelot smoke (needs a table page)
camelot-smoke file?=" /tmp/out_ocr.pdf ":
	$(PY) - <<'PY'
import camelot, os
f = os.environ.get("FILE","/tmp/out_ocr.pdf")
t = camelot.read_pdf(f, pages="1")
print("tables:", len(t))
if t: print(t[0].df.head())
PY

# --- format (treefmt driving black/ruff/shfmt)
format:
	treefmt

# --- ensure sentence-transformers loads
emb-smoke:
	$(PY) - <<'PY'
from sentence_transformers import SentenceTransformer
m = SentenceTransformer("all-MiniLM-L6-v2")
print("dim:", m.get_sentence_embedding_dimension())
PY