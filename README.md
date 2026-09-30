# Grid Anomaly Detection & Load Forecasting

A Big Data pipeline processing London smart meter data using HDFS, Pig, Hive, and Spark MLlib.
Developed for CSE412 Big Data Applied Project.

## Prerequisites
- Docker & Docker Compose
- `python3` with `pandas`, `scikit-learn`, `matplotlib` (for local metric evaluation)
- Kaggle dataset `jeanmidev/smart-meters-in-london` (Zipped as `Dataset.zip` in root, or use Kaggle CLI).

## Setup
1. Extract data locally (ensure `Dataset.zip` is present in the root directory):
   ```bash
   python3 scripts/extract_data.py --subset
   ```
2. Start the Hadoop/Spark cluster:
   ```bash
   docker-compose -f docker/docker-compose.yml up -d
   ```
   *Wait 30-60 seconds for the Hive Metastore to initialize.*

## Run the Pipeline
The entire end-to-end pipeline (Ingestion -> Pig -> Hive -> Spark -> Anomaly Python) is automated. 

To run on the fast subset (400 households, ~12 million rows, takes ~8-10 mins):
```bash
./scripts/run_pipeline.sh --subset
```

To run on the full dataset (5,567 households, ~167 million rows, takes 1-2 hours):
```bash
./scripts/run_pipeline.sh --full
```
*(Note: Full mode heavily samples the ML training set to avoid Out-Of-Memory errors on a single laptop JVM).*

## Outputs
All results are dynamically generated and saved to `results/`:
- `forecast_metrics_*.csv`: MLlib RMSE/MAE/sMAPE evaluation vs temporal baselines.
- `reporting_output.csv`: Hive SQL aggregations (Acorn profiling).
- `anomaly_metrics.txt` & `detector_A_example.png`: Anomaly detection scores and visual plots.

## Tool Versions
- **Hadoop**: 3.2.1 (HDFS Node)
- **Pig**: 0.17.0 (Local Client)
- **Hive**: 2.3.2 (with PostgreSQL metastore)
- **Spark**: 3.5.8 (Scala 2.12 via spark-shell)
