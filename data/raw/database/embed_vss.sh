#!/usr/bin/env python3
"""
Generate embeddings for searchable text and register DuckDB VSS indexes.
Priority: manuals & procedures > parts_catalog > diagrams > symptoms.
"""
import os, sys, time
from pathlib import Path
import argparse
import duckdb
from sentence_transformers import SentenceTransformer

OILROOT = Path(os.environ.get("OILHEAD_ROOT", Path.home() / "Repos" / "BeemerDB"))
DB_PATH = Path(os.environ.get("PART_DB", OILROOT / "db" / "OEM.duckdb"))
MODEL_NAME = os.environ.get("EMBEDDING_MODEL", "all-MiniLM-L6-v2")
DEVICE = os.environ.get("EMBEDDING_DEVICE", "cpu")

def ensure_vss(con: duckdb.DuckDBPyConnection):
    con.execute("LOAD vss;")
    # Create vector indexes if not exists (DuckDB vss)
    con.execute("""
        CREATE INDEX IF NOT EXISTS vss_manual_pages
        ON manual_pages USING HNSW (embedding) WITH (metric='cosine');
    """)
    con.execute("""
        CREATE INDEX IF NOT EXISTS vss_procedures
        ON maintenance_procedures USING HNSW (embedding) WITH (metric='cosine');
    """)
    con.execute("""
        CREATE INDEX IF NOT EXISTS vss_parts_catalog
        ON parts_catalog USING HNSW (embedding) WITH (metric='cosine');
    """)
    con.execute("""
        CREATE INDEX IF NOT EXISTS vss_parts_diagrams
        ON parts_diagrams USING HNSW (embedding) WITH (metric='cosine');
    """)
    con.execute("""
        CREATE INDEX IF NOT EXISTS vss_symptoms
        ON symptoms USING HNSW (embedding) WITH (metric='cosine');
    """)

def batched(iterable, n=256):
    buf = []
    for x in iterable:
        buf.append(x)
        if len(buf) >= n:
            yield buf; buf = []
    if buf:
        yield buf

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--duckdb", default=str(DB_PATH))
    ap.add_argument("--batch", type=int, default=256)
    args = ap.parse_args()

    model = SentenceTransformer(MODEL_NAME, device=DEVICE)
    con = duckdb.connect(args.duckdb)
    con.execute("LOAD json;")

    def embed_table(table, idcol, textcol):
        # fetch rows needing embeddings (null or length mismatch)
        rows = con.execute(f"""
            SELECT {idcol}, {textcol}
            FROM {table}
            WHERE {textcol} IS NOT NULL
              AND (embedding IS NULL OR array_length(embedding) <> {model.get_sentence_embedding_dimension()})
        """).fetchall()
        total = 0
        for batch in batched(rows, args.batch):
            ids = [r[0] for r in batch]
            texts = [r[1] or "" for r in batch]
            vecs = model.encode(texts, normalize_embeddings=True)
            # DuckDB supports parameter array binding
            con.execute(f"""
                UPDATE {table} SET embedding = ?
                WHERE {idcol} = ?
            """, [(vecs[i].tolist(), ids[i]) for i in range(len(ids))])
            total += len(ids)
        return total

    counts = {}
    counts['manual_pages'] = embed_table("manual_pages","id","ocr_text")
    counts['maintenance_procedures'] = embed_table("maintenance_procedures","id","description")
    counts['parts_catalog'] = embed_table("parts_catalog","id","description")
    counts['parts_diagrams'] = embed_table("parts_diagrams","id","ocr_text")
    counts['symptoms'] = embed_table("symptoms","id","symptom_description")

    ensure_vss(con)

    con.execute("""
      INSERT INTO ingestion_log(source_file, file_type, action, status, records_processed, started_at, completed_at, metadata)
      VALUES ('embed_vss.py','n/a','embed','success', ?, NOW(), NOW(), ?)
    """, [sum(counts.values()), duckdb.json(counts)])

    print("[embed_vss]", counts)

if __name__ == "__main__":
    main()