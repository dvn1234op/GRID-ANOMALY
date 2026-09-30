# Project Proposal: Grid Anomaly Detection & Load Forecasting

**Course:** CSE412 Big Data & Large-Scale Computing
**Team Members:** ____________________, ____________________, ____________________

## Problem Statement
The goal of this project is to build a comprehensive Big Data pipeline to analyze and model energy consumption patterns using smart meter data. We aim to forecast short-term electricity load for individual households and detect anomalous consumption behavior. This will provide insights into energy usage patterns, including the impact of dynamic pricing (Time-of-Use tariffs) and weather conditions, enabling better grid management and demand response strategies.

## Dataset
* **Source:** Kaggle - "Smart meters in London" (`jeanmidev/smart-meters-in-london`). This is a refactored copy of the UK Power Networks Low Carbon London dataset.
* **Size:** Approximately 10 GB unzipped, containing ~167 million rows of half-hourly kWh readings from 5,567 households between November 2011 and February 2014. It includes hourly weather data and household metadata.
* **License:** *Note: To be verified.* (Expected to be an open data license compatible with academic use, derived from the original UK Power Networks dataset).

## Pipeline Architecture
The project will implement a robust data processing pipeline using the following tools:
* **HDFS:** Provides distributed, reliable, and scalable storage for the raw and processed large-scale dataset.
* **Pig:** Used for initial ETL tasks including data cleaning, type casting, timezone alignment, and joining disparate datasets due to its efficient data flow scripting.
* **Hive:** Serves as the data warehouse, enabling structured data querying, window function aggregations for feature engineering, and efficient columnar storage (ORC) for downstream machine learning.
* **Spark MLlib:** Chosen for its distributed machine learning capabilities to efficiently train and evaluate forecasting and anomaly detection models on the processed dataset.

## Expected Outcome
1. A reproducible, automated data pipeline running on a local Docker environment.
2. An analytical report detailing short-term load forecasting performance (using models like GBT or Random Forest Regressors) compared to baselines.
3. An evaluation of anomaly detection methods (residual-based and K-means clustering) against synthetically injected anomalies.
4. Insights into the effects of ToU tariffs and household demographics (ACORN groups) on energy consumption.

## Risks & Mitigation
* **Resource Constraints:** Processing 10 GB of data on a single laptop may cause memory or storage bottlenecks. *Mitigation:* We will develop and test the pipeline on a reproducible subset (~300-500 households, ~10M rows) and carefully size Spark configurations. Full data will primarily be used to demonstrate scaling capabilities.
* **Data Quality Issues:** The dataset contains known quirks like missing values, "Null" strings, and misaligned timestamps. *Mitigation:* A dedicated Pig ETL phase will handle parsing, deduplication, timezone alignment, and bad record isolation (logging rejects).
* **Environment Complexity:** Integrating multiple Big Data components can lead to compatibility issues. *Mitigation:* We will use pinned tool versions in a managed Docker Compose stack and verify compatibility before building.
