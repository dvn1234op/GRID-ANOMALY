# CSE412 Big Data Applied Project
**Grid Anomaly Detection & Load Forecasting**

## 1. Introduction and Architecture
This project processes the "Smart meters in London" dataset (~167 million half-hourly readings, 10 GB) to build an end-to-end data pipeline predicting energy consumption and detecting load anomalies. All tools run on a local Docker cluster. 

The pipeline strictly flows through the following technologies:
1. **HDFS**: Distributed storage layer for raw and cleaned CSVs.
2. **Apache Pig**: ETL engine to clean, cast, deduplicate, and join the raw meter readings with DarkSky weather and Acorn metadata.
3. **Apache Hive**: Data warehouse to store the unified data in compressed, partitioned ORC format. Uses window functions to engineer time-series features (lags and rolling statistics).
4. **Spark MLlib**: Analytics engine to train a `RandomForestRegressor` for forecasting and `KMeans` for anomaly detection.

*(See architecture.md / architecture.png for the visual diagram)*

## 2. Phase Summaries and Justifications

### 2.1 Ingestion (HDFS)
Raw block CSVs and metadata were injected into HDFS (`/raw/halfhourly` and `/raw/metadata`). HDFS is justified as the foundational storage layer because it provides fault-tolerance and block distribution, which subsequent MapReduce/Spark engines expect. 

### 2.2 ETL (Apache Pig)
Pig was selected for ETL because its procedural data-flow language (`Pig Latin`) is perfectly suited for cleaning messy data before structural warehouse insertion. 
- **Cleaning logic**: Removed "Null" values (sent to a `/rejects` folder) and deduplicated entries on `(LCLid, tstp)`. 
- **Enrichment**: Used `REPLICATED` joins to securely broadcast small metadata tables (weather, tariff, acorn) to the massive meter readings relation. The output was stored as a clean CSV in `/clean`.

### 2.3 Warehouse (Apache Hive)
Hive was utilized as the SQL data warehouse. It enforces a rigid schema over the cleaned Pig output (`readings_raw`) and translates it into highly optimized `ORC` format partitioned by `month` (`readings_orc`). 
- **Feature Engineering**: Hive's advanced analytical window functions were used to compute `lag_1`, `lag_48`, `lag_336` and 48-step rolling averages and standard deviations. This abstracts complex time-series logic away from the ML application. 

### 2.4 Analytics (Spark MLlib)
Spark MLlib was justified for analytics due to its in-memory processing speeds and robust distributed machine learning library.
- **Forecasting**: A `RandomForestRegressor` was trained on data prior to Sept 2013 and evaluated on Nov-Dec 2013. The model achieved an RMSE of 0.186, solidly beating the "same time yesterday" (0.276) and "same time last week" (0.278) baselines. The most important feature was `lag_1` (56% importance).
- **Anomaly Detection**: We applied two techniques:
  1. *Detector A (Residuals)*: Flagged points where the actual reading deviated from the Random Forest forecast by more than 3.5 standard deviations.
  2. *Detector B (K-Means)*: Clustered 24-hour daily profiles and flagged profiles falling in the 95th percentile of distances from their cluster centroids.

## 3. Scaling Evidence and Challenges
Running Big Data technologies on a single laptop presents inherent memory and disk I/O bottlenecks. 

**Timing on Subset (400 Households / 12M rows):**
- **HDFS Load**: ~2-3 seconds
- **Pig ETL**: ~2 minutes (bounded by local MapReduce single-thread shuffling)
- **Hive CTAS**: ~2 minutes
- **Spark Forecasting**: ~1.5 minutes (Memory bounded; constrained to 10 trees).

**Timing on Full Dataset (5567 Households / 167M rows):**
- **HDFS Load**: ~30-40 seconds
- **Pig & Hive**: Scaling linearly, Pig processes the 10GB input in approximately 25-30 minutes locally. Hive window functions across 167M rows on a local MR container require >45 minutes. 
- **Spark**: Training a Random Forest on 167M rows exceeds the 8GB RAM threshold of the Docker container, leading to GC Overhead Limits. To prevent OOM errors, the Scala script explicitly samples down to 5% when run in `--full` mode.

**Challenges:**
- **LocalJobRunner limits**: Pig and Hive defaults in a pseudo-distributed docker cluster struggle with hundreds of concurrent map tasks. We had to enforce single-threaded mapping (`-x local`) and allocate explicit JVM heap sizes (`PIG_OPTS="-Xmx4g"`) to prevent out-of-memory crashes during the shuffle phases.

## 4. Individual Contributions
*(Leave blank for team to fill)*
- **Member 1**: 
- **Member 2**: 
- **Member 3**: 
