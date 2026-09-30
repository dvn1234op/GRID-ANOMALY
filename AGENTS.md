# CSE412 Big Data Applied Project: Grid Anomaly Detection & Load Forecasting

## Context
University course project (CSE412, Big Data & Large-Scale Computing), team of 3.
Dataset: Kaggle "Smart meters in London" (slug `jeanmidev/smart-meters-in-london`), a refactored copy of the
UK Power Networks Low Carbon London data: 5,567 households, half-hourly kWh readings (Nov 2011 - Feb 2014),
~167M rows / ~10 GB unzipped, plus hourly weather and household metadata.
Everything must run on the USER'S LAPTOP (single node, Docker). Ask for RAM / free disk / CPU cores before
sizing any config. Assume ~16 GB RAM and 70+ GB free disk until told otherwise.

## Grading (out of 20). Design everything to satisfy this
- Minimum 3 course tools with REAL data flow; each stage's output feeds the next:
  HDFS -> Pig -> Hive -> Spark MLlib. No manual copying between stages.
- Proposal (2), Implementation & integration (7), Analytical quality (3: results must mean something),
  Demo (3: <=10 min, real execution, honest scoping), Docs & report (3: architecture diagram,
  reproducible setup), Presentation & Q&A (2).
- Deliverables: proposal, code + README (setup, run steps, tool versions), 6-10 page report (architecture,
  per-tool justification, results, challenges, individual contribution section), demo script,
  evidence for two check-ins (working ingestion; draft analytical results).

## Dataset facts (from memory of the Kaggle page; VERIFY every one by inspecting the real files)
- Files (approx.): `halfhourly_dataset.zip` (block files `block_0.csv` ... ~112 blocks; each household's data
  is in one block; columns roughly `LCLid, tstp, energy(kWh/hh)`), `informations_households.csv` (household id,
  ACORN group, tariff Std vs ToU, which block file), `weather_hourly_darksky.csv`, `weather_daily_darksky.csv`,
  `acorn_details.csv`, `uk_bank_holidays.csv`, plus redundant `daily_dataset.zip` and `hhblock_dataset.zip`.
- DO NOT download the redundant daily/hhblock zips (wastes disk). Download only what the pipeline needs, one
  file at a time with `kaggle datasets download -d jeanmidev/smart-meters-in-london -f <file>`.
- Known quirks to handle: the reading column is named `energy(kWh/hh)` (parentheses and slash), it can hold the
  literal string "Null"; timestamps carry 7 fractional digits; households start/stop at different dates;
  possible duplicate rows; check whether meter timestamps and DarkSky weather timestamps use the same timezone
  and align them explicitly; ToU-tariff households behave differently in 2013 (dynamic pricing trial), so keep
  tariff as a feature and consider evaluating Std and ToU separately.
- Proposed modelling window: calendar year 2013, where coverage is best. Verify household coverage and get my
  approval before fixing the window. Ingest everything in HDFS, but model on the agreed window.

## Working rules (always follow)
1. Work ONE phase at a time. When a phase is done: run it for real, show logs/output, summarize, then STOP and
   wait for my approval. Do not start the next phase on your own.
2. Before writing code for a phase, give a short plan and wait for my OK.
3. Never claim something works unless you executed it and saw the result. Never invent numbers, timings, or
   metrics. Every figure in the report must trace to a file in logs/ or results/.
4. Ask before any large download and state its expected size. The Kaggle API token is at
   `~/.kaggle/kaggle.json` (or the newer token env var); tell me exactly what to do if it is missing.
   Never hard-code or print secrets.
5. Pin and document every tool version. Check compatibility BEFORE building (Hive 3.x needs Java 8, Pig has
   limited Hadoop 3 support, etc.). If the ideal combo is impractical, propose the closest workable one and
   explain the tradeoff.
6. Use Docker Compose: HDFS (namenode + datanode, replication 1), Hive (metastore + HiveServer2), Pig client,
   Spark/PySpark with Hive support.
7. Develop on a reproducible SUBSET (~300-500 households chosen with a fixed seed, ~10M rows). Every script
   takes --subset or --full. Run FULL data only for ingestion / ETL / scaling evidence.
8. Small, commented, idempotent scripts. All config in one place. Keep the repo tidy.
9. Be honest about scope: if full-data ML training is infeasible on a laptop, train on a sample and say so in
   code, README, and report.
10. Keep terminal commands scoped to this project folder. Do not use a browser agent unless a download truly
    needs it.

## Repo layout
docker/ (compose + configs) | data/ (gitignored) | pig/ | hive/ | spark/ | scripts/ (download.sh,
load_hdfs.sh, run_pipeline.sh, run_subset.sh, run_full.sh) | results/ | logs/ | docs/ (architecture Mermaid +
PNG, proposal.md, report.md, demo_script.md) | README.md

## Phases

### Phase P: Proposal (no infrastructure needed)
Draft docs/proposal.md (1 page): problem statement, dataset (Kaggle source, size, license note to verify),
pipeline HDFS -> Pig -> Hive -> Spark MLlib with one line of justification per tool, expected outcome, risks.

### Phase 0: Environment
Ask for laptop specs. Propose the version matrix. Build docker-compose. Smoke-test each service (HDFS put/get,
Pig on HDFS, Hive create/select, PySpark reading a Hive table).
Done when: one command starts the stack and a smoke-test script passes.

### Phase 1: Data and ingestion (check-in 1 evidence)
Download the needed Kaggle files (see Dataset facts). Inspect the real schema and document it in
docs/data_schema.md. Load raw files to HDFS /raw. Log row counts and load time. Create the fixed-seed household
subset (by LCLid). Done when: raw data in HDFS, counts logged, subset ready.

### Phase 2: Pig ETL (HDFS -> Pig -> HDFS)
Cast types; parse timestamps; treat "Null"/empty/negative readings as bad records written to a rejects path
with a reason; dedupe (household, timestamp); join hourly weather (half-hour -> its hour, timezone-aligned),
holiday flags, and household metadata (ACORN group, tariff). Write cleaned data to /clean. Log counts
in/out/rejected per rule. Done when: cleaned data in HDFS and reject counts explained.

### Phase 3: Hive warehouse (HDFS -> Hive)
External table over Pig output, then CTAS to partitioned ORC (e.g. by month). Validation queries proving the
cleaning worked (no nulls/negatives, one row per household-timestamp, date coverage, per-household
completeness). Feature SQL with window functions: lag 1, lag 48, lag 336, rolling 48-step mean and std, hour,
day-of-week, is_weekend, holiday flag, temperature, tariff, ACORN group. Reporting queries (consumption by
ACORN group, peak-hour profiles, Std vs ToU) saved to results/.
Done when: Hive tables queryable from Spark; validation output saved.

### Phase 4: Forecasting (Hive -> Spark MLlib)
Predict next-half-hour consumption per household. Baselines: same time last week, same time yesterday.
Models: GBTRegressor and/or RandomForestRegressor in an MLlib Pipeline. TIME-BASED split only (train early
months, validate next, test last), no leakage (lags strictly from the past). Metrics: RMSE, MAE, sMAPE
(zero-safe) vs baselines, overall and by ACORN group, tariff, and hour of day; feature importances.
Save to results/. Done when: metrics table saved and model compared honestly to baselines.

### Phase 5: Anomaly detection (check-in 2 evidence)
Detector A: residual-based, flag |actual - forecast| > k*sigma per household (tune k on validation, never test).
Detector B: K-means on daily load profiles, flag days far from their centroid. No ground truth exists, so INJECT
synthetic anomalies (fixed seed) into a held-out copy of the test period: spikes (x5-x10), drops to ~0,
flatlines of N hours, slow drift; keep a label table. Report precision/recall/F1 per anomaly type and
detector, example plots, and sanity-check what is flagged in the real data.
Done when: metrics + plots in results/.

### Phase 6: Scaling evidence
Time each stage on subset vs full data; vary Spark partitions/cores where meaningful; record disk usage per
stage. Produce a runtime-vs-size table/plot and an honest note on what does not scale on one laptop.

### Phase 7: Docs, report, demo
README (prereqs, exact commands, versions, expected runtimes, troubleshooting). Architecture diagram
(Mermaid + PNG) showing HDFS -> Pig -> Hive -> Spark and the data format at each hop. Report (6-10 pages,
markdown, real figures only) with a blank individual-contributions section. Demo script (<=10 min) built on a
fast run_subset.sh flow.

### Optional stretch (ONLY if I ask): Kafka -> Spark Structured Streaming -> Hive live scoring.

## Definition of done
scripts/run_pipeline.sh --subset runs raw-in-HDFS to final metrics and plots with no manual steps; --full does
the same on all data; a fresh machine can reproduce it from the README; every reported number traces to a log or
results file.
