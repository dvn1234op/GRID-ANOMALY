# System Architecture

The pipeline processes smart meter data from raw CSVs to actionable ML insights through four main stages, strictly flowing from one tool to the next without manual intervention.

## Architecture Diagram

```mermaid
flowchart TD
    %% Define Nodes
    A[Kaggle Source\n167M rows (10GB)] -->|extract_data.py| B(HDFS /raw\nRaw CSVs)
    
    subgraph Hadoop Ecosystem
        B -->|Pig ETL\n(Type casting, dedupe, join)| C(HDFS /clean\nCleaned CSVs)
        C -->|Hive DDL\nExternal Table| D[(Hive Metastore\nreadings_raw)]
        D -->|CTAS\n(Partitioned ORC, Window funcs)| E[(Hive Metastore\nfeatures_orc)]
    end
    
    subgraph Spark Analytics
        E -->|Spark SQL\nread.orc| F[Spark MLlib\nRandomForestRegressor]
        F -->|Time-based Split\nModel Training| G[Spark MLlib\nKMeans & Residuals]
    end
    
    %% Outputs
    F --> H([Results / Metrics\nforecast_metrics.csv])
    G --> I([Anomaly Reports\ndetector_plots.png])
    E --> J([Reporting Queries\npeak_profiles.csv])
    
    %% Formatting
    classDef hdfs fill:#f9f,stroke:#333,stroke-width:2px;
    classDef hive fill:#ff9,stroke:#333,stroke-width:2px;
    classDef spark fill:#9cf,stroke:#333,stroke-width:2px;
    
    class B,C hdfs;
    class D,E hive;
    class F,G spark;
```

## Data Format at Each Hop

1. **HDFS (`/raw`)**: Distributed, raw CSV blocks (`block_*.csv`). 
2. **Pig (`/clean`)**: Cleaned CSV files (nulls removed, types cast, weather and metadata joined). Deduped by `(LCLid, tstp)`.
3. **Hive (`features`)**: Highly compressed, columnar ORC format, partitioned by `month` (e.g., `month=2013-01`). Feature engineered columns added (lags, rolling stats).
4. **Spark (`DataFrame`)**: In-memory Resilient Distributed Datasets (RDDs/DataFrames) utilized by MLlib pipelines for forecasting and KMeans clustering. Predictions exported back to local CSV for anomaly injection evaluation.
