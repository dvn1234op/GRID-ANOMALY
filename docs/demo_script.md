# CSE412 Project Demo Script (10 min)

**Prep Before Demo**:
- Have a clean terminal open in the project root.
- Ensure Docker Desktop is running.
- Run `docker-compose -f docker/docker-compose.yml up -d` to start the cluster.

---

### Minute 0-2: Introduction and Scope
- Introduce team and problem: "We built a pipeline to forecast energy demand and detect anomalies in the London Smart Meter dataset."
- Show the architecture diagram (`docs/architecture.png`).
- Highlight that we are running the demo in `--subset` mode (400 households, 12 million rows) so it fits in a 10-minute live window without timing out. The `--full` mode scales the same way but takes ~1-2 hours due to local container constraints.

### Minute 2-3: Phase 1 & 2 (HDFS & Pig)
- Run the pipeline script: `./scripts/run_pipeline.sh --subset`
- Explain the terminal output as it happens.
- "Phase 1 loads the CSV blocks and metadata into HDFS `/raw`."
- "Phase 2 uses Pig to clean Nulls, cast types, and execute Replicated Joins against the weather/metadata tables."

### Minute 4-6: Phase 3 (Hive)
- The script enters Hive phase.
- "Hive is creating an external table over the Pig output, and using CTAS to convert it to highly compressed ORC format partitioned by month."
- Explain the window functions: "We used Hive window functions to calculate 1-step, 48-step, and 336-step lags entirely in SQL."
- Show `results/reporting_output.csv` quickly to prove aggregation works.

### Minute 6-8: Phase 4 (Spark Forecasting)
- The script triggers Spark MLlib.
- "Spark reads the ORC files directly from HDFS, filters for 2013, and trains a RandomForestRegressor."
- Show the `results/forecast_metrics_overall.csv`. Point out how our RandomForest RMSE (0.18) beats the temporal baselines (0.27).

### Minute 8-10: Phase 5 (Anomaly Detection)
- "Finally, we used Python and Scikit-Learn to inject synthetic anomalies (Spikes, Drops) into the test set to evaluate our detectors."
- "Detector A flagged residuals > 3.5 standard deviations from the Spark prediction. Detector B used K-Means to find anomalous daily load profiles."
- Show the output plot `results/detector_A_example.png` to visually prove the anomaly was caught.
- Take questions!
