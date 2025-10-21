#!/usr/bin/env python3
"""
Parse & segment documents:
- Assumes PDFs already OCR'ed (OCRmyPDF pipeline).
- Uses layoutparser[ocr] for region detection; page text is authoritative.
- For diagrams: extract text blocks and candidate part numbers into parts_diagrams.ocr_text/part_numbers.
"""
import os, sys, time, re, json
from pathlib import Path
import argparse
import duckdb

OILROOT = Path(os.environ.get("OILHEAD_ROOT", Path.home() / "Repos" / "BeemerDB"))
DB_PATH = Path(os.environ.get("PART_DB", OILROOT / "db" / "OEM.duckdb"))

PART_RE = re.compile(r"\b\d{7,11}\b")  # crude BMW part pattern (tune later)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--duckdb", default=str(DB_PATH))
    ap.add_argument("--limit", type=int, default=1000)
    args = ap.parse_args()

    con = duckdb.connect(args.duckdb)
    con.execute("LOAD fts;")

    # TODO: wire real layoutparser segmentation and pdf text extraction here.
    # For now: copy sidecar text files (if present) into ocr_text fields.

    # Manual pages: if you have sidecars "file.pdf.ocr.txt" or "file.pdf.txt"
    rows = con.execute("""
        SELECT id, file_path FROM manuals ORDER BY id LIMIT ?
    """, [args.limit]).fetchall()

    updated_pages = 0
    for mid, fpath in rows:
        p = Path(fpath)
        sidecar = None
        for ext in (".ocr.txt", ".txt"):
            cand = p.with_suffix(p.suffix + ext)  # "file.pdf.ocr.txt"
            if cand.exists():
                sidecar = cand; break
        if not sidecar:
            continue
        text = sidecar.read_text(errors="ignore")
        # naive split per page marker (replace with pdfplumber later)
        pages = [seg.strip() for seg in text.split("\f") if seg.strip()]
        for i, page_text in enumerate(pages, start=1):
            # upsert page
            con.execute("""
                INSERT INTO manual_pages(manual_id, page_number, ocr_text)
                VALUES (?, ?, ?)
                ON CONFLICT (manual_id, page_number) DO UPDATE SET
                  ocr_text=excluded.ocr_text
            """, [mid, i, page_text])
            updated_pages += 1

    # Parts diagrams: capture numbers from sidecars if present
    drows = con.execute("SELECT id, file_path FROM parts_diagrams ORDER BY id LIMIT ?", [args.limit]).fetchall()
    diagrams_updated = 0
    for did, fpath in drows:
        p = Path(fpath)
        sidecar = None
        for ext in (".ocr.txt", ".txt"):
            cand = p.with_suffix(p.suffix + ext)
            if cand.exists():
                sidecar = cand; break
        if not sidecar:
            continue
        text = sidecar.read_text(errors="ignore")
        numbers = sorted(set(PART_RE.findall(text)))
        con.execute("""
            UPDATE parts_diagrams
               SET ocr_text = ?,
                   part_numbers = ?
             WHERE id = ?
        """, [text, duckdb.json(numbers), did])
        diagrams_updated += 1

    con.execute("""
        INSERT INTO ingestion_log(source_file, file_type, action, status, records_processed, started_at, completed_at, metadata)
        VALUES ('parse_documents.py','pdf','parse','success', ?, NOW(), NOW(), {'manual_pages': ?, 'diagrams': ?})
    """, [updated_pages+diagrams_updated, updated_pages, diagrams_updated])

    print(f"[parse] manual_pages={updated_pages} diagrams={diagrams_updated}")

if __name__ == "__main__":
    main()