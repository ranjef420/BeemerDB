# BeemerDB — AI Driven BMW R1150RT Expert and Database

[![Python](https://img.shields.io/badge/python-3.10%2B-blue)](https://www.python.org/)
[![License](https://img.shields.io/badge/license-MIT-green)](./LICENSE)
[![CI](https://github.com/ranjef420/TorrqueAI/actions/workflows/ci.yml/badge.svg)](https://github.com/ranjef420/TorrqueAI/actions)

Overview
- Parts Assist is a centralized codebase for a Parts Database and an assistant that combines retrieval-augmented generation (RAG) with multi-model orchestration (Claude + ChatGPT).
- Primary capabilities:
  - Canonical parts storage and search (semantic + exact)
  - Maintenance procedure generation and scheduling
  - Troubleshooting and root-cause diagnosis from symptoms / logs
  - Adapter layer to call multiple LLM providers and orchestrate responses
  - Evaluation harness for regression testing and A/B model comparisons

Quick start (local)
1. Copy environment template
   cp '.env.example .env'
   # Edit .env and add your keys/db urls (see "Configuration" below)

2. Create and activate a virtual environment
   python -m venv .venv
   source .venv/bin/activate

3. Install dependencies
   pip install -r requirements.txt

4. Run the API server (development)
   python src/api/server.py
   
Configuration (important env vars)
- OPENAI_API_KEY — API key for OpenAI / ChatGPT
- CLAUDE_API_KEY — API key for Anthropic Claude (if used)

Usage examples
- Parts lookup (HTTP)
  curl -X POST http://localhost:8080/v1/assist \
    -H "Content-Type: application/json" \
    -d '{"intent":"parts_lookup","user_query":"Show me details for part ABC-1234"}'

- Diagnose (symptoms -> likely causes)
  curl -X POST http://localhost:8080/v1/assist \
    -H "Content-Type: application/json" \
    -d '{"intent":"troubleshoot_diagnose","symptoms":"grinding noise on startup","context":"..."}'

Prompt templates & model orchestration
- All prompt templates live in src/utils/prompt_templates.py and are versioned under models/prompt_versions/.
- The orchestrator implements simple routing rules (e.g., factual lookups → ChatGPT, multi-step troubleshooting → Claude) and supports ensemble/consensus flows.

Evaluation harness
- experiments/eval_dataset.jsonl contains labeled test cases for parts lookup, maintenance, troubleshooting, clarifying questions, and safety checks.
- Run the lightweight evaluator:
  python experiments/run_evaluation.py --endpoint http://localhost:8080/v1/assist
- The harness compares outputs against expected substrings and reports pass/partial/fail per case. Extend the dataset with product-specific cases and telemetry traces for stronger validation.

Development
- Run tests:
  pytest -q
- Linting:
  flake8 src tests
- Add new prompts:
  - Add template to src/utils/prompt_templates.py
  - Add metadata entry in models/prompt_versions/vX_metadata.json
  - Add unit tests to tests/ to detect regressions

Security & privacy
- Never commit API keys or secrets. Use .env or your secret manager.
- All LLM inputs/outputs should be logged to an append-only audit log with PII redaction.
- The system policy in prompt templates enforces: no request for secrets, redaction of PII, and safety-first maintenance instructions.
- For potentially dangerous requests (e.g., bypassing safety interlocks) the assistant must refuse and provide safe alternatives — add tests to verify this behavior.

Operational notes
- Monitor LLM usage (tokens, latency, error rates) and model disagreements.
- Keep prompt templates under version control and create a new prompt version when changing behavior.
- Use hybrid search (vector + text) for improved recall and precision.

Contributing
- See CONTRIBUTING.md for branching, PR, and code style guidelines.
- Branching model: main (protected), develop, feature/*.
- Use Conventional Commits (feat, fix, docs, chore) and include tests for any functional change.

├── README.md
├── .gitignore
├── .gitattributes                # (LFS rules if you decide to track any binaries)
├── Justfile                      # init/scan/import/status targets
│
├── schema.sql                    # single source of truth (DB DDL)
├── config/                       # repo-tracked knobs (no secrets)
│   ├── paths.yaml                # { manuals_root, parts_root, db_path, ... }
│   └── options.yaml              # model names, chunk sizes, feature flags
│
├── src/                          # importable python package (unit-testable)
│   └── oilheadpro/
│       ├── __init__.py
│       ├── db.py                 # connect(), apply_schema(), helpers
│       ├── ingest/
│       │   ├── register_manuals.py
│       │   └── import_manifest.py
│       └── legacy/
│           └── import_legacy_manifest.py
│
├── scripts/                      # thin CLI shims that call src/*
│   ├── register_manuals
│   ├── import_parts_manifest
│   └── import_legacy_manifest
│
├── db/
│   ├── oilhead.duckdb            # ephemeral; gitignored
│   ├── manuals/                  # heavy assets; gitignored
│   │   └── .keep
│   ├── parts_manifest.yaml       # canonical manifest (authoritative)
│   └── legacy/                   # quarantined seed/reference
│       ├── manifest.yaml
│       ├── index.sqlite
│       └── README.md
│
├── docs/
│   ├── WORKFLOW.md               # structure-first guidance (no OCR yet)
│   ├── DECISIONS.md              # schema choices (group_number TEXT, etc.)
│   ├── DEV.md                    # local setup, env, paths, just targets
│   └── inventory/
│       ├── manuals_ls.txt
│       └── parts_tree.txt
│
├── tests/
│   ├── test_schema_smoke.py      # SHOW TABLES; basic asserts
│   └── test_legacy_import.py
│
└── .github/
    └── workflows/
        └── ci.yml                # lint + unit tests (no heavy jobs yet)
        
BeemerDB/
│
├── schema/
│   ├── WORKFLOW.md               # structure-first guidance (no OCR yet)
│   ├── DECISIONS.md              # schema choices (group_number TEXT, etc.)
│   ├── DEV.md                    # local setup, env, paths, just targets
│   └── ToDO.mdi
│
├── src/                          # importable python package (unit-testable)
│   └──workers/
│       ├──__init__.py
│       ├── db.py                 # connect(), apply_schema(), helpers
│       ├── ingest/
│       ├── register_manuals.py
│       └── import_manifest.py
├── db/                      # thin CLI shims that call src/*
│   ├── OEM.duckdb            # ephemeral; gitignored
│   ├── OEM.sqlite
│
├── data/
│   ├── parts_manifest.yaml       # canonical manifest (authoritative)
│   └── legacy/                   # quarantined seed/reference
│       ├── manifest.yaml
│       ├── index.sqlite
│       └── import_legacy_manifest.py
    │   ├── import_parts_manifest
    │   └── import_legacy_manifest
    │         ├── manuals_ls.txt
│        └── parts_tree.txt
│       └── README.md
│ 

├── config/                       # repo-tracked knobs (no secrets)
│   ├── paths.yaml                # { manuals_root, parts_root, db_path, ... }
│   └── options.yaml              # model names, chunk sizes, feature flags

inventory/
│   ├── schema.sql                    # Comprehensive Status Log for project
│   └── Testing/
        ├── test_schema_smoke.py      # SHOW TABLES; basic asserts
        └── test_legacy_import.py
│ 
│             
├──  README.md
├── .gitignore
├── .gitattributes                # (LFS rules if you decide to track any binaries)
├──  Justfile                      # init/scan/import/status targets
└── .github/
      └── workflows/
      └── ci.yml                # lint + unit tests (no heavy jobs yet)

