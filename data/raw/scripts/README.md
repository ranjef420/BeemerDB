# BMW R1150RT Parts Toolchain

Repository: [Broomhilda](https://github.com/ranjef420/Broomhilda)  
Local Root: `/Users/nickwade/Repos/Broomhilda`

---

## Correct Deployment Order

| Step | Tool                    | Role                    | Why it must run before next                        |
|------|--------------------------|--------------------------|----------------------------------------------------|
| 1    | **PDF directory setup**  | Source material          | Everything else depends on the PDFs                |
| 2    | **pdf_sanitizer.sh**     | Clean filenames          | Prevents broken links and mismatches               |
| 3    | **emit_manifest.sh**     | Create master catalog    | Provides IDs and structure for the database        |
| 4    | **ocr_all.sh**           | Extract searchable text  | Supplies the searchable content                    |
| 5    | **build_index.sh**       | Assemble SQLite database | Combines manifest and OCR text                     |
| 6    | **REFERENCE_INDEX.yaml** | Add metadata             | Enriches the finished database                     |
| 7    | **query.sh**             | CLI search               | Consumes the complete dataset                      |

---

### Step 1 — Prepare the Source PDFs
**Component:** `/parts/pdf/`  
**Purpose:** Raw material — the OEM BMW parts manuals and diagrams that everything else uses.  
This folder is the foundation. Each PDF corresponds to a parts diagram (e.g., “34 - Brakes/Front Wheel Brake – Integral ABS.pdf”).  
All other scripts depend on consistent file paths and content inside `/parts/pdf/`.

---

### Step 2 — Sanitize Filenames
**Component:** `scripts/pdf_sanitizer.sh`  
**Input:** `/parts/pdf/`  
**Output:** Cleaned filenames  
Normalizes filenames (removes trailing spaces, fixes punctuation, strips illegal characters).  
Prevents broken links between PDF, OCR, and YAML manifest.

---

### Step 3 — Emit the Manifest
**Component:** `scripts/emit_manifest.sh`  
**Input:** `/parts/pdf/`  
**Output:** `/parts/MANIFEST.parts.yaml`  
Scans the sanitized PDF directory and builds a structured catalog with ID, group, title, and path.  
This is the canonical map for later indexing steps.

---

### Step 4 — Run OCR
**Component:** `scripts/ocr_all.sh`  
**Input:** `/parts/pdf/`  
**Output:** `/parts_ocr/` (mirrors structure)  
Extracts readable text from each diagram using Tesseract OCR.  
Uses hash caching to avoid reprocessing unchanged files.

---

### Step 5 — Build the Database
**Component:** `scripts/build_index.sh`  
**Inputs:**
- `/parts/MANIFEST.parts.yaml`
- `/parts_ocr/`
**Output:** `/parts/index.sqlite`  
Combines manifest and OCR data into a full-text search (FTS5) SQLite database.

---

### Step 6 — Add Custom Metadata
**Component:** `REFERENCE_INDEX.yaml`  
**Input:** `index.sqlite`  
**Purpose:** Enriches database with metadata such as RealOEM URLs, torque specs, and part notes.

---

### Step 7 — Query the Database
**Component:** `scripts/query.sh`  
**Input:** `index.sqlite`  
**Output:** Search results (plain text or JSON).  
Provides command-line access to the complete parts index.

---

## Workflow Summary

- **Clean** → `./scripts/pdf_sanitizer.sh`
- **Manifest** → `./scripts/emit_manifest.sh`
- **OCR** → `./scripts/ocr_all.sh`
- **Index** → `./scripts/build_index.sh`
- **Query** → `./scripts/query.sh`

**Full rebuild:** Run these in sequence to rebuild the database from scratch after adding or modifying PDFs.

---

## Quick Commands

| Purpose              | Script Command                         | Notes |
|----------------------|----------------------------------------|-------|
| Clean filenames      | `./scripts/pdf_sanitizer.sh`           | Removes spaces and invalid chars |
| Emit manifest        | `./scripts/emit_manifest.sh`           | Updates parts catalog |
| OCR all PDFs         | `BINARIZE=1 LANGS="eng" ./scripts/ocr_all.sh` | Extract searchable text |
| Build SQLite index   | `./scripts/build_index.sh`             | Creates full-text database |
| Query database       | `./scripts/query.sh`                   | Search interface |
| Full rebuild         | Run all above in sequence              | Cleans → Manifest → OCR → Index |

---

## Example Queries

```bash
# Quick searches
./scripts/query.sh -- "brake line"
./scripts/query.sh --json --fields -- "abs sensor"

# Filter by group
./scripts/query.sh -g 34 -- "front wheel"

# Exact match
./scripts/query.sh --exact -- "Front Wheel Brake – Integral ABS"
```

---

## Verification

Before running, ensure paths are valid:

- `$HILDE_ROOT/parts` exists  
- `$HILDE_SCRIPTS` points to the `scripts/` directory  

If either is missing, adjust environment variables accordingly.