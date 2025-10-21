#!/usr/bin/env python3
"""
Register manuals and parts diagrams into DuckDB.
Policy: manuals/diagrams are canonical; forum ingest is separate and secondary.
"""
import os, sys, time, hashlib, json
from pathlib import Path
import argparse
import duckdb

OILROOT = Path(os.environ.get("OILHEAD_ROOT", Path.home() / "Repos" / "BeemerDB"))
DB_PATH = Path(os.environ.get("PART_DB", OILROOT / "db" / "OEM.duckdb"))
MANUALS_DIR = OILROOT / "db" / "legacy" / "sources" / "manuals"
PARTS_DIR   = OILROOT / "db" / "legacy" / "sources" / "parts"

def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--duckdb", default=str(DB_PATH))
    ap.add_argument("--manuals", default=str(MANUALS_DIR))
    ap.add_argument("--parts", default=str(PARTS_DIR))
    args = ap.parse_args()

    con = duckdb.connect(args.duckdb)
    con.execute("LOAD json; LOAD fts;")

    # Ensure schema exists (no-op if already created)
    # You normally call the SQL file via just:init-db, but it's ok to be defensive:
    # con.execute("PRAGMA table_info('manuals');")  # will raise if DB not initialized

    start = time.time()
    processed = 0

    def upsert_manual(p: Path):
        nonlocal processed
        stat = p.stat()
        digest = sha256(p)
        # Skip unchanged
        row = con.execute(
            "SELECT sha256_hash FROM file_hashes WHERE file_path = ?",
            [str(p)]
        ).fetchone()
        if row and row[0] == digest:
            return
        # Assign manual id by hash for stability
        mid = int(digest[:16], 16) % (1<<63)
        con.execute("""
            INSERT INTO manuals AS m(id, filename, manual_type, file_path, file_size_bytes, page_count, sha256_hash, metadata)
            VALUES (?, ?, ?, ?, ?, NULL, ?, ?)
            ON CONFLICT (id) DO UPDATE SET
              file_size_bytes=excluded.file_size_bytes,
              sha256_hash=excluded.sha256_hash
        """, [mid, p.name, "repair", str(p), stat.st_size, digest, duckdb.json({'source':'catalog.py'})])
        con.execute("""
            INSERT INTO file_hashes(file_path, sha256_hash, file_size_bytes, last_modified, last_processed, processing_status)
            VALUES (?, ?, ?, NOW(), NOW(), 'cataloged')
            ON CONFLICT (file_path) DO UPDATE SET
              sha256_hash=excluded.sha256_hash,
              file_size_bytes=excluded.file_size_bytes,
              last_modified=excluded.last_modified,
              last_processed=excluded.last_processed,
              processing_status='cataloged'
        """, [str(p), digest, stat.st_size])
        processed += 1

    def upsert_diagram(p: Path):
        nonlocal processed
        stat = p.stat()
        digest = sha256(p)
        row = con.execute(
            "SELECT sha256_hash FROM file_hashes WHERE file_path = ?",
            [str(p)]
        ).fetchone()
        if row and row[0] == digest:
            return
        did = int(digest[:16], 16) % (1<<63)
        # Infer group_number from filename prefix like '34_1234_brake.pdf' -> 34
        try:
            group_number = int(p.stem.split('_',1)[0])
        except Exception:
            group_number = None
        con.execute("""
            INSERT INTO parts_diagrams AS d(id, group_number, filename, title, file_path, file_size_bytes, page_count, sha256_hash, metadata)
            VALUES (?, ?, ?, ?, ?, ?, NULL, ?, ?)
            ON CONFLICT (id) DO UPDATE SET
              file_size_bytes=excluded.file_size_bytes,
              sha256_hash=excluded.sha256_hash
        """, [did, group_number, p.name, p.stem, str(p), stat.st_size, digest, duckdb.json({'source':'catalog.py'})])
        con.execute("""
            INSERT INTO file_hashes(file_path, sha256_hash, file_size_bytes, last_modified, last_processed, processing_status)
            VALUES (?, ?, ?, NOW(), NOW(), 'cataloged')
            ON CONFLICT (file_path) DO UPDATE SET
              sha256_hash=excluded.sha256_hash,
              file_size_bytes=excluded.file_size_bytes,
              last_modified=excluded.last_modified,
              last_processed=excluded.last_processed,
              processing_status='cataloged'
        """, [str(p), digest, stat.st_size])
        processed += 1

    manuals_dir = Path(args.manuals)
    parts_dir = Path(args.parts)

    for p in manuals_dir.rglob("*.pdf"):
        upsert_manual(p)
    for p in parts_dir.rglob("*.pdf"):
        upsert_diagram(p)

    con.execute("""
        INSERT INTO ingestion_log(source_file, file_type, action, status, records_processed, started_at, completed_at, metadata)
        VALUES ('catalog.py','pdf','register','success', ?, NOW(), NOW(), {'manuals_dir': ?, 'parts_dir': ?})
    """, [processed, str(manuals_dir), str(parts_dir)])

    print(f"[catalog] processed={processed} in {time.time()-start:.2f}s")

if __name__ == "__main__":
    main()