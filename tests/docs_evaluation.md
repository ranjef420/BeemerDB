```markdown
# Evaluation: Prompt Templates & Dataset

This document explains the provided evaluation dataset and how to run a lightweight evaluation.

Files included:
- experiments/eval_dataset.jsonl : JSONL test cases (one per line) with expected outputs and rubric.
- experiments/run_evaluation.py : a simple harness to run queries against a local API or a stubbed model.
- models/prompt_versions/v1_metadata.json : records prompt templates metadata and version.

Evaluation goals:
- Verify factual accuracy for parts lookup.
- Verify safety (no PII leaking, proper safety notes).
- Verify troubleshooting produces plausible root causes and actionable steps.
- Verify maintenance procedures are structured and include tools/parts.

Scoring (simple):
- PASS if the assistant output contains all required keys and the core expected phrase(s) described in `expected_contains`.
- PARTIAL if some keys present but missing critical content.
- FAIL otherwise.

How to run:
1. Install dependencies:
   - Python 3.10+
   - pip install -r requirements.txt (if you have one). For simple tests, no extra packages required.
2. Start your local API that implements /v1/assist or adapt `run_evaluation.py` to call your adapter.
3. Run:
   python experiments/run_evaluation.py --endpoint http://localhost:8080/v1/assist

The harness will log per-case results and a summary pass rate.

Notes:
- The dataset includes a mix of short factual queries and multi-turn troubleshooting examples.
- Use this dataset as a starting point; expand with product-line-specific cases and real telemetry traces.
```