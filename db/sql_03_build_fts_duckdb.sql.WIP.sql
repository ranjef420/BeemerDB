-- Rebuild DuckDB FTS indexes from base content
DELETE FROM fts.manual_pages_fts;
INSERT INTO fts.manual_pages_fts
SELECT id, coalesce(section_title,''), coalesce(ocr_text,'') FROM manual_pages;

DELETE FROM fts.parts_diagrams_fts;
INSERT INTO fts.parts_diagrams_fts
SELECT id, coalesce(title,''), coalesce(ocr_text,'') FROM parts_diagrams;

DELETE FROM fts.parts_catalog_fts;
INSERT INTO fts.parts_catalog_fts
SELECT id, coalesce(part_number,''), coalesce(description,''), coalesce(notes,'') FROM parts_catalog;

DELETE FROM fts.maintenance_procedures_fts;
INSERT INTO fts.maintenance_procedures_fts
SELECT id, coalesce(procedure_name,''), coalesce(description,'') FROM maintenance_procedures;

DELETE FROM fts.symptoms_fts;
INSERT INTO fts.symptoms_fts
SELECT id, coalesce(symptom_description,'') FROM symptoms;