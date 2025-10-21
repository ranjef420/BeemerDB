 OILHEADPRO FINAL TOOLCHAIN - SYNTHESIZED ARCHITECTURE

## PROJECT GOAL
AI-powered personal master mechanic, troubleshooting expert, and diagnostic system using DuckDB knowledge base populated from manuals, diagrams, forums, and parts databases to provide expert motorcycle maintenance guidance through conversational CLI interface.

## CORE PHILOSOPHY
- Local-first embedded architecture (zero Docker)
- DuckDB as unified analytical and vector search engine
- SQLite mirrors for Git-friendly portability
- Native M1 macOS optimization
- Open-source tooling exclusively
- Conversational AI interface, not database management

---

## TIER 0: DATABASE CORE

duckdb
  Primary analytical engine with columnar storage, native FTS, vector similarity
  search (VSS), JSON/CSV/Parquet support, and extensible architecture. Handles
  all queries, analytics, semantic search, and data transformations. M1 native.
  
sqlite3
  Lightweight portable mirror for Git version control and distribution. DuckDB
  syncs bidirectionally via sqlite extension. Enables sharing knowledge base as
  single-file artifacts. Already installed on macOS.

---

## TIER 1: DUCKDB EXTENSIONS (Auto-install on first use)

INSTALL fts;
  Native full-text search with tokenization, BM25 ranking, and MATCH syntax.
  Primary keyword search engine for parts descriptions, maintenance notes, and
  manual content. Replaces need for external search engines.

INSTALL vss;
  Vector Similarity Search extension with HNSW index for semantic lookup.
  Eliminates need for separate ChromaDB/Qdrant. Stores embeddings directly in
  DuckDB alongside structured data. Query: "front brake pulsation" finds
  semantically similar issues even with different wording.

INSTALL sqlite FROM community;
  Bidirectional SQLite integration via ATTACH. Import legacy Broomhilda data,
  export portable mirrors, and maintain Git-friendly .sqlite artifacts. Zero
  export friction between DuckDB and SQLite.

INSTALL httpfs;
  Read files over HTTP/HTTPS or S3 as if local. Query remote parts databases,
  access cloud backups, integrate web APIs without downloading first. Enables
  serverless-friendly remote data access.

INSTALL json;
  Native JSON type with parsing, querying, and manipulation functions. Store
  metadata, configuration, semi-structured forum posts, and API responses.
  Export to JSON format for integrations.

INSTALL excel;
  Read and write Excel files directly in SQL. Import supplier parts lists,
  export maintenance reports for sharing. Handles .xlsx and .xls formats
  natively without conversion.

INSTALL spatial;
  Geospatial data processing with GEOMETRY type and 50+ format support via
  GDAL. Optional for tracking service locations, dealership proximity, trip
  routes, and geographic parts availability.

INSTALL icu;
  Unicode and internationalization support. Handle international part names,
  manufacturer text in multiple languages, proper Unicode collation for
  sorting and comparison across character sets.

INSTALL cache_httpfs FROM community;
  Transparent read-through caching for remote files. Query remote parts
  databases without re-downloading. Offline resilience and faster iteration
  during development. Critical for remote data workflows.

INSTALL shellfs FROM community; (optional)
  Read/write via pipes and shell commands. Useful for quick prototyping and
  integrating with existing bash scripts. Enables DuckDB queries from shell
  pipelines directly.

INSTALL fuzzycomplete FROM community; (optional)
  Improves DuckDB interactive autocompletion. Better CLI UX when working
  directly with DuckDB shell. Fuzzy matching for table/column names.

---

## TIER 2: DOCUMENT INGESTION PIPELINE

### PDF & Document Parsing

unstructured
  pip install unstructured
  Robust multi-format parsing (PDF/HTML/DOCX/images) into structured elements
  for LLM/RAG pipelines. Single unified API vs. juggling multiple PDF libraries.
  Cleaner code, better element detection (title, paragraph, table, list). Handles
  complex BMW manuals with mixed content types.

layoutparser
  pip install layoutparser
  pip install "detectron2@git+https://github.com/facebookresearch/detectron2.git"
  Document layout detection (blocks, tables, figures) to segment manuals/diagrams
  before OCR. Critical for understanding diagram structure - which part connects
  to which part, callout relationships, wiring diagram flows. Uses computer vision
  to identify document regions.

camelot-py
  pip install camelot-py[cv]
  Reliable table extraction from PDFs (torque specs, part lists, service
  intervals) straight to dataframes/CSV. Better accuracy than pdfplumber for
  complex tables. Handles bordered and borderless tables.

pdfplumber
  pip install pdfplumber
  Backup table extraction and text extraction. Good for simpler documents.
  Useful when Camelot struggles with specific table formats.

### OCR & Image Processing

ocrmypdf
  brew install ocrmypdf
  Turnkey pipeline adds searchable OCR layers to PDFs. Production-ready vs.
  custom pytesseract scripting. Better accuracy, automatic image preprocessing,
  parallel processing. Complements existing Tesseract installation.

tesseract
  brew install tesseract  (already installed)
  Core OCR engine for extracting text/TSV from diagram images. Used by OCRmyPDF
  but also directly via pytesseract for custom workflows.

pytesseract
  pip install pytesseract
  Python wrapper for Tesseract. Enables programmatic OCR control with custom
  preprocessing pipelines and output formats.

imagemagick
  brew install imagemagick  (already installed)
  Pre-processes images (deskew, normalize, threshold, rotate) for better OCR
  accuracy. Essential for cleaning scanned manual pages before text extraction.

unpaper
  brew install unpaper
  Cleans and straightens scanned pages before OCR. Removes artifacts, corrects
  skew, normalizes contrast. Significantly improves OCR accuracy on poor-quality
  scans.

poppler (pdftoppm)
  brew install poppler
  Converts PDF pages to images before OCR. High-quality rendering for Tesseract
  input. Better than Ghostscript for most workflows.

pillow
  pip install pillow
  Python image manipulation library. Preprocessing, resizing, format conversion,
  basic image operations in ingestion pipeline.

### Web Scraping & Forum Extraction

    pip install trafilatura
  Battle-tested web/forum text extraction with boilerplate removal. Purpose-built
  for extracting clean text from technical forums (ADVRider, Boxerworks, BMW MOA).
  Removes ads, navigation, signatures. Better than BeautifulSoup for forum content.

beautifulsoup4
  pip install beautifulsoup4
  HTML parsing for complex sites or custom scraping needs. Backup when Trafilatura
  doesn't handle specific site structure. General-purpose HTML parser.

scrapy
  pip install scrapy
  Advanced web scraping framework for large-scale forum archival. Handles
  authentication, rate limiting, multi-page crawls. Use for comprehensive
  forum data collection projects.

requests
  pip install requests
  HTTP library for API integration and simple web requests. Fetch parts data
  from supplier APIs, download resources, test endpoints.

playwright
  pip install playwright
  Browser automation for JavaScript-heavy sites that require rendering. Some
  forums load content dynamically. Headless browser execution.

---

## TIER 3: VECTOR SEARCH & EMBEDDINGS

sentence-transformers
  pip install sentence-transformers
  Generate embeddings for semantic search. Model: all-MiniLM-L6-v2 (fast, good
  quality) or all-mpnet-base-v2 (better quality, slower). Converts text to
  384/768-dimensional vectors for similarity matching. Runs locally on M1.

sqlite-vss (optional)
  pip install sqlite-vss
  Add vector similarity search to SQLite portable mirrors if you want parity
  between DuckDB and distributed SQLite files. Enables semantic search in
  Git-tracked artifacts.

---

## TIER 4: RAG FRAMEWORK & LLM INTEGRATION

### RAG Orchestration

langchain + langchain-community
  pip install langchain langchain-community
  Batteries-included RAG framework. Pre-built chains, huge community, rapid
  prototyping. Start here for faster initial development. Integrates with
  DuckDB, embeddings, and LLMs out of box.

haystack-ai (alternative)
  pip install haystack-ai
  Modular production-focused RAG framework. More explicit control, composable
  pipelines. Migrate to Haystack if LangChain limitations encountered or need
  custom retrieval logic. Better for complex multi-step reasoning.

### LLM Runtime

ollama
  brew install ollama
  Local LLM runtime for privacy and offline operation. M1 optimized. Models:
  llama3.1:8b (good balance), mistral:7b (fast), qwen2.5:14b (better reasoning).
  Free, runs entirely local, no API costs.

openai
  pip install openai
  OpenAI API client for GPT-4o/GPT-4-turbo. Fastest, most capable models for
  complex diagnostic reasoning. Pay-per-use. Good for production quality.

anthropic
  pip install anthropic
  Anthropic Claude API client. Claude 3.5 Sonnet excellent for technical
  reasoning and long-context tasks (200k tokens). Better than GPT-4 for
  detailed mechanical analysis.

---

## TIER 5: SQL PORTABILITY & DATA TOOLS

sqlglot
  pip install sqlglot
  Python SQL parser and transpiler supporting 30+ dialects. Translate SQL
  between DuckDB and SQLite. Optimize queries, parse for analysis, ensure
  portable query specs across database engines.

pandas
  pip install pandas
  Dataframe library for data manipulation and transformation. Bridge between
  CSV/Excel and database. Useful for complex data preprocessing before ingestion.

numpy
  pip install numpy
  Numerical computing for embeddings and vector operations. Required by
  sentence-transformers and many ML libraries.

---

## TIER 6: CLI INTERACTION & DATABASE CLIENTS

usql
  brew tap xo/xo && brew install usql
  Universal SQL client supporting 20+ database types (DuckDB, SQLite, PostgreSQL,
  MySQL, Oracle, MSSQL) with consistent CLI interface. Single tool for any
  database without learning different CLIs.

pspg
  brew install pspg
  PostgreSQL TUI table pager with column freezing, filtering, advanced navigation.
  Beautiful table rendering for query results. Works with any tool outputting
  PostgreSQL format. Much better than default paging.

litecli
  brew install litecli
  SQLite CLI with auto-completion and syntax highlighting. Enhanced SQLite
  experience when working with portable mirrors. Better UX than default sqlite3.

duckdb (CLI)
  brew install duckdb  (primary installation method)
  DuckDB native shell. Default REPL for queries and script execution. Fast,
  feature-rich, excellent for interactive exploration and development.

sqlite3
  (pre-installed on macOS)
  Native SQLite CLI for raw inspection and scripting. Use for validating
  portable mirrors and legacy compatibility checks.

---

## TIER 7: DEVELOPER EXPERIENCE & CLI ENHANCEMENT

### Search & Navigation

ripgrep (rg)
  brew install ripgrep  (already installed)
  Ultra-fast recursive search (faster than grep/ag). Search through code, logs,
  OCR output, documentation, and data files instantly. Essential for finding
  references across entire project.

fd
  brew install fd
  Modern find replacement. Faster, easier syntax, respects .gitignore. Used to
  scan directories for PDFs and data files in ingestion pipeline.

fzf
  brew install fzf  (already installed)
  Fuzzy finder for command-line with interactive filtering. File selection,
  command history search, integration with other tools. Makes CLI navigation
  significantly faster.

### Code Viewing & Formatting

bat
  brew install bat  (already installed)
  Cat clone with syntax highlighting and Git integration. Read SQL files,
  schemas, and documentation with beautiful syntax highlighting. Better than
  cat for development work.

eza
  brew install eza  (already installed)
  Modern ls replacement with Git integration and better formatting. Enhanced
  directory listings showing Git status, file metadata, tree views. Better
  project navigation.

### Shell Enhancement

starship
  brew install starship  (already installed)
  Fast, customizable shell prompt with Git, language, and directory context.
  Shows current database, Git branch, project context. Better situational
  awareness in terminal.

zsh-autosuggestions
  (already installed)
  Fish-like autosuggestions for Zsh based on command history. Faster command
  entry, fewer typos.

zsh-completions
  (already installed)
  Additional completion definitions for Zsh. Better tab-completion for tools
  and commands.

zsh-syntax-highlighting
  (already installed)
  Fish-like syntax highlighting for Zsh. Real-time feedback on command validity
  before execution.

---

## TIER 8: BUILD & ORCHESTRATION

just
  brew install just
  Modern make alternative with cleaner syntax. Task runner to orchestrate
  pipeline (sanitize → catalog → ocr → fts → sync). Better error messages,
  easier to read/write than Makefile.

make
  (pre-installed on macOS)
  Traditional build automation. Fallback option if just not preferred. Well-known,
  universal compatibility.

shellcheck
  brew install shellcheck  (already installed)
  Shell script static analysis tool. Ensures CLI scripts are bug-free, portable,
  and follow best practices. Prevents common bash pitfalls.

treefmt
  cargo install treefmt
  Unified formatter to keep scripts, Python, YAML, and SQL clean. One command
  formats entire project. Consistent code style across languages.

---

## TIER 9: VERSION CONTROL & PROJECT MANAGEMENT

git
  (already installed)
  Distributed version control. Core requirement for Git-based schema management,
  collaboration, backup strategy. Essential for tracking migrations and data.

git-lfs
  brew install git-lfs  (already installed)
  Git Large File Storage for versioning PDF manuals, images, binary data
  efficiently without bloating repository. Critical for OEM manual management.

gh
  brew install gh  (already installed)
  GitHub CLI for repository management, issues, PRs from terminal. Manage repo,
  create releases, handle issues without leaving terminal. Streamlines workflow.

---

## TIER 10: PYTHON RUNTIME & ENVIRONMENT

python@3.14
  (already installed)
  Python interpreter for RAG framework, ingestion scripts, and data processing.
  Required for LangChain, Unstructured, sentence-transformers, and all pip
  packages.

pipx
  brew install pipx  (already installed)
  Install Python applications in isolated environments. Install command-line
  tools without dependency conflicts. Clean tool management.

---

## TIER 11: OPTIONAL ANALYTICS & FUTURE INTEGRATIONS

spacy
  pip install spacy
  python -m spacy download en_core_web_sm
  NLP library for entity extraction (part numbers, model names, symptoms).
  Extract structured information from unstructured text. Named entity recognition.

duckdb-engine
  pip install duckdb-engine
  SQLAlchemy-compatible adapter. Enables scripted access to DuckDB from Python
  notebooks and analytics tools. Jupyter integration.

flock (experimental)
  Future consideration once stable
  LLM-augmented querying within DuckDB. Experimental tool for natural language
  SQL generation. Track for future integration when mature.

---

## INSTALLATION PRIORITY ORDER

### Phase 1: Core Foundation (Day 1)
brew install duckdb sqlite just
pip install sentence-transformers langchain langchain-community

### Phase 2: Ingestion Pipeline (Week 1)
brew install ocrmypdf unpaper poppler
pip install unstructured layoutparser camelot-py[cv] trafilatura
pip install "detectron2@git+https://github.com/facebookresearch/detectron2.git"
pip install pytesseract pillow beautifulsoup4

### Phase 3: LLM & RAG (Week 1)
brew install ollama
ollama pull llama3.1:8b
pip install openai anthropic

### Phase 4: Developer Tools (Week 2)
brew install usql pspg litecli
pip install sqlglot pandas numpy
cargo install treefmt

### Phase 5: Optional/As-Needed
pip install spacy scrapy playwright duckdb-engine
pip install sqlite-vss haystack-ai

---

## DUCKDB EXTENSION INITIALIZATION

# Create initialization script: ~/.duckdbrc
INSTALL fts;
INSTALL vss;
INSTALL sqlite;
INSTALL httpfs;
INSTALL json;
INSTALL excel;
INSTALL icu;
INSTALL cache_httpfs FROM community;
LOAD fts;
LOAD vss;
LOAD sqlite;
LOAD httpfs;
LOAD json;

---

## ARCHITECTURE SUMMARY

Database Layer:
  DuckDB (primary) with FTS + VSS extensions
  SQLite (portable mirrors via duckdb-sqlite)
  
Ingestion:
  Unstructured (unified parsing)
  LayoutParser (diagram structure)
  OCRmyPDF (production OCR)
  Trafilatura (forum extraction)
  
Vector Search:
  DuckDB-VSS (native semantic search)
  sentence-transformers (embeddings)
  
RAG Framework:
  LangChain (initial development)
  Optional Haystack (if more control needed)
  
LLM Runtime:
  Ollama (local/offline)
  OpenAI/Anthropic APIs (cloud/quality)
  
CLI:
  usql (universal database access)
  pspg (beautiful output)
  Custom Python CLI (conversational interface)

---

## TOTAL TOOL COUNT

Core Database: 2 (duckdb, sqlite)
DuckDB Extensions: 9 (fts, vss, sqlite, httpfs, json, excel, icu, cache_httpfs, spatial)
Ingestion: 12 (unstructured, layoutparser, camelot, ocrmypdf, tesseract, imagemagick, unpaper, trafilatura, beautifulsoup, scrapy, playwright, poppler)
Vector/Embeddings: 2 (sentence-transformers, sqlite-vss optional)
RAG/LLM: 4 (langchain, haystack optional, ollama, openai/anthropic)
SQL/Data: 3 (sqlglot, pandas, numpy)
CLI/Database: 5 (usql, pspg, litecli, duckdb, sqlite3)
Dev Experience: 7 (ripgrep, fd, fzf, bat, eza, starship, zsh tools)
Build/Orchestration: 3 (just, make, shellcheck, treefmt)
Version Control: 3 (git, git-lfs, gh)
Python: 2 (python, pipx)
Optional: 3 (spacy, duckdb-engine, flock)

TOTAL: 57 tools (29 new installations, 28 already on system)

---

## KEY ARCHITECTURAL DECISIONS

1. DuckDB-VSS eliminates need for separate ChromaDB/Qdrant
   Unified SQL interface, faster queries, atomic transactions

2. SQLite mirrors enable Git-friendly portability
   Share knowledge base as single-file artifacts, version control data

3. Unstructured + LayoutParser for superior document understanding
   Better diagram parsing, structure recognition, element detection

4. OCRmyPDF for production-ready text extraction
   Higher accuracy, less custom code vs. pytesseract alone

5. Trafilatura for purpose-built forum scraping
   Cleaner text extraction from technical forums vs. generic scraping

6. cache_httpfs for offline resilience
   Query remote data without re-downloading, faster iteration

7. LangChain for rapid development, Haystack as migration path
   Start fast, scale to production complexity as needed

8. Ollama for local inference, APIs for quality
   Privacy option with local models, quality option with cloud

---

END OF TOOLCHAIN SPECIFICATION