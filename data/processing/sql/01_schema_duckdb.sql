-- ============================================================================
-- MANUALS & DOCUMENTATION
-- ============================================================================

CREATE TABLE IF NOT EXISTS manuals (
  id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  filename TEXT NOT NULL,
  manual_type TEXT NOT NULL,     -- repair, electrical, maintenance, riders, specs
  file_path TEXT NOT NULL,
  file_size_bytes INTEGER,
  page_count INTEGER,
  sha256_hash TEXT UNIQUE,
  ingested_at TIMESTAMP DEFAULT now(),
  metadata JSON
);

CREATE TABLE IF NOT EXISTS manual_pages (
  id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  manual_id INTEGER NOT NULL REFERENCES manuals(id) ON DELETE CASCADE,
  page_number INTEGER NOT NULL,
  section_title TEXT,
  ocr_text TEXT,
  embedding FLOAT[384],          -- DuckDB-only; won’t be mirrored to SQLite
  image_path TEXT,
  confidence_score DOUBLE,
  metadata JSON,
  UNIQUE(manual_id, page_number)
);

CREATE INDEX IF NOT EXISTS idx_manual_pages_manual ON manual_pages(manual_id);
CREATE INDEX IF NOT EXISTS idx_manual_pages_section ON manual_pages(section_title);

-- DuckDB FTS (create a dedicated FTS schema to keep things tidy)
INSTALL fts; LOAD fts;
CREATE SCHEMA IF NOT EXISTS fts;
CREATE OR REPLACE VIRTUAL TABLE fts.manual_pages_fts USING fts(id, section_title, ocr_text);

-- ============================================================================
-- PARTS CATALOG (BMW GROUP STRUCTURE)
-- ============================================================================

CREATE TABLE IF NOT EXISTS parts_groups (
  group_number INTEGER PRIMARY KEY,
  group_name TEXT NOT NULL,
  description TEXT,
  diagram_count INTEGER DEFAULT 0,
  metadata JSON
);

INSERT OR IGNORE INTO parts_groups (group_number, group_name) VALUES
  (11, 'Engine'),
  (12, 'Engine Electrics'),
  (13, 'Fuel Preparation'),
  (16, 'Fuel Supply'),
  (17, 'Cooling'),
  (18, 'Exhaust System'),
  (21, 'Clutch'),
  (23, 'Transmission'),
  (31, 'Front Suspension'),
  (32, 'Steering'),
  (33, 'Rear Axle & Suspension'),
  (34, 'Brakes'),
  (35, 'Pedals'),
  (36, 'Wheels'),
  (46, 'Frame Fairing & Cases'),
  (51, 'Vehicle Trim'),
  (52, 'Seat'),
  (61, 'Electrical System'),
  (62, 'Instrument Dash'),
  (63, 'Lighting'),
  (65, 'GPS Alarms & Radio');

CREATE TABLE IF NOT EXISTS parts_diagrams (
  id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  group_number INTEGER NOT NULL REFERENCES parts_groups(group_number),
  filename TEXT NOT NULL,
  title TEXT,
  file_path TEXT NOT NULL,
  file_size_bytes INTEGER,
  page_count INTEGER,
  ocr_text TEXT,
  embedding FLOAT[384],          -- DuckDB-only
  part_numbers JSON,
  sha256_hash TEXT UNIQUE,
  ingested_at TIMESTAMP DEFAULT now(),
  metadata JSON
);

CREATE INDEX IF NOT EXISTS idx_diagrams_group ON parts_diagrams(group_number);
CREATE INDEX IF NOT EXISTS idx_diagrams_title ON parts_diagrams(title);

CREATE OR REPLACE VIRTUAL TABLE fts.parts_diagrams_fts
USING fts(id, title, ocr_text);

-- ============================================================================
-- PARTS CATALOG (From parts_manifest.yaml)
-- ============================================================================

CREATE TABLE IF NOT EXISTS parts_catalog (
  id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  part_number TEXT UNIQUE NOT NULL,
  description TEXT NOT NULL,
  group_number INTEGER REFERENCES parts_groups(group_number),
  diagram_id INTEGER REFERENCES parts_diagrams(id),
  superseded_by TEXT,
  price_usd DECIMAL(10,2),
  availability TEXT,
  notes TEXT,
  metadata JSON,
  embedding FLOAT[384]           -- DuckDB-only
);

CREATE INDEX IF NOT EXISTS idx_parts_number ON parts_catalog(part_number);
CREATE INDEX IF NOT EXISTS idx_parts_group ON parts_catalog(group_number);
CREATE INDEX IF NOT EXISTS idx_parts_superseded ON parts_catalog(superseded_by);

CREATE OR REPLACE VIRTUAL TABLE fts.parts_catalog_fts
USING fts(id, part_number, description, notes);

-- ============================================================================
-- VEHICLE SPECIFICATIONS (From Specs.txt)
-- ============================================================================

CREATE TABLE IF NOT EXISTS vehicle_specs (
  id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  spec_category TEXT NOT NULL,
  spec_name TEXT NOT NULL,
  spec_value TEXT NOT NULL,
  unit TEXT,
  notes TEXT,
  source TEXT,
  metadata JSON,
  UNIQUE(spec_category, spec_name)
);

CREATE INDEX IF NOT EXISTS idx_specs_category ON vehicle_specs(spec_category);

-- ============================================================================
-- EXTRACTED ENTITIES (Part Numbers, Torque Specs, Procedures)
-- ============================================================================

CREATE TABLE IF NOT EXISTS torque_specifications (
  id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  component TEXT NOT NULL,
  location TEXT,
  torque_value DOUBLE NOT NULL,
  unit TEXT DEFAULT 'Nm',
  thread_size TEXT,
  part_number TEXT REFERENCES parts_catalog(part_number),
  source_page_id INTEGER REFERENCES manual_pages(id),
  notes TEXT,
  metadata JSON
);

CREATE TABLE IF NOT EXISTS maintenance_procedures (
  id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  procedure_name TEXT NOT NULL,
  category TEXT,
  group_number INTEGER REFERENCES parts_groups(group_number),
  description TEXT,
  steps JSON,
  required_parts JSON,
  required_tools JSON,
  estimated_time_minutes INTEGER,
  difficulty_rating INTEGER,
  source_manual_id INTEGER REFERENCES manuals(id),
  source_page_numbers JSON,
  embedding FLOAT[384],          -- DuckDB-only
  metadata JSON
);

CREATE INDEX IF NOT EXISTS idx_procedures_category ON maintenance_procedures(category);
CREATE INDEX IF NOT EXISTS idx_procedures_group ON maintenance_procedures(group_number);

CREATE OR REPLACE VIRTUAL TABLE fts.maintenance_procedures_fts
USING fts(id, procedure_name, description);

-- ============================================================================
-- DIAGNOSTIC CODES & SYMPTOMS
-- ============================================================================

CREATE TABLE IF NOT EXISTS symptoms (
  id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  symptom_description TEXT NOT NULL,
  severity TEXT,
  affected_systems JSON,
  common_causes JSON,
  diagnostic_steps JSON,
  related_procedures JSON,
  related_parts JSON,
  embedding FLOAT[384],          -- DuckDB-only
  metadata JSON
);

CREATE OR REPLACE VIRTUAL TABLE fts.symptoms_fts
USING fts(id, symptom_description);

-- ============================================================================
-- INGESTION TRACKING & METADATA
-- ============================================================================

CREATE TABLE IF NOT EXISTS ingestion_log (
  id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  source_file TEXT NOT NULL,
  file_type TEXT,                 -- pdf, yaml, txt
  action TEXT,                    -- ocr, parse, embed, index
  status TEXT,                    -- success, failed, partial
  records_processed INTEGER,
  error_message TEXT,
  processing_time_seconds DOUBLE,
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  metadata JSON
);

CREATE TABLE IF NOT EXISTS file_hashes (
  id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  file_path TEXT UNIQUE NOT NULL,
  sha256_hash TEXT NOT NULL,
  file_size_bytes INTEGER,
  last_modified TIMESTAMP,
  last_processed TIMESTAMP,
  processing_status TEXT,         -- pending, processing, completed, failed
  UNIQUE(file_path, sha256_hash)
);

CREATE INDEX IF NOT EXISTS idx_file_hashes_path ON file_hashes(file_path);
CREATE INDEX IF NOT EXISTS idx_file_hashes_status ON file_hashes(processing_status);