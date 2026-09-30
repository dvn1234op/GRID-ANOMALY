import pandas as pd
import numpy as np
from sklearn.cluster import KMeans
from sklearn.metrics import precision_score, recall_score, f1_score
import matplotlib.pyplot as plt
import glob
import os

print("=== Phase 5: Anomaly Detection ===")

# 1. Load Data
valid_files = glob.glob('results/valid_predictions/*.csv')
test_files = glob.glob('results/test_predictions/*.csv')

if not valid_files or not test_files:
    print("Prediction files not found! Ensure anomaly_prep.scala finished.")
    exit(1)

valid_df = pd.read_csv(valid_files[0])
test_df = pd.read_csv(test_files[0])

valid_df['tstp'] = pd.to_datetime(valid_df['tstp'])
test_df['tstp'] = pd.to_datetime(test_df['tstp'])
test_df = test_df.sort_values(['lclid', 'tstp']).reset_index(drop=True)

# 2. Detector A: Tune k*sigma on Validation
valid_df['residual'] = np.abs(valid_df['actual'] - valid_df['prediction'])
sigma = valid_df['residual'].std()
k = 3.5
threshold = k * sigma
print(f"Residual Threshold (k={k}, sigma={sigma:.4f}): {threshold:.4f}")

# 3. Inject Synthetic Anomalies into Test Set
np.random.seed(42)
test_df['injected_actual'] = test_df['actual'].copy()
test_df['is_anomaly'] = 0
test_df['anomaly_type'] = 'None'

# Pick random households and days to inject
households = test_df['lclid'].unique()
num_anomalies = 500

anomaly_indices = np.random.choice(test_df.index, size=num_anomalies, replace=False)
for idx in anomaly_indices:
    atype = np.random.choice(['Spike', 'Drop', 'Flatline'])
    if atype == 'Spike':
        test_df.loc[idx, 'injected_actual'] = test_df.loc[idx, 'actual'] * np.random.uniform(5, 10)
        test_df.loc[idx, 'is_anomaly'] = 1
        test_df.loc[idx, 'anomaly_type'] = 'Spike'
    elif atype == 'Drop':
        test_df.loc[idx, 'injected_actual'] = test_df.loc[idx, 'actual'] * np.random.uniform(0, 0.1)
        test_df.loc[idx, 'is_anomaly'] = 1
        test_df.loc[idx, 'anomaly_type'] = 'Drop'
    elif atype == 'Flatline':
        # Flatline for 3 hours (6 steps)
        if idx + 6 < len(test_df) and test_df.loc[idx, 'lclid'] == test_df.loc[idx+6, 'lclid']:
            val = test_df.loc[idx, 'actual']
            test_df.loc[idx:idx+5, 'injected_actual'] = val
            test_df.loc[idx:idx+5, 'is_anomaly'] = 1
            test_df.loc[idx:idx+5, 'anomaly_type'] = 'Flatline'

print(f"Injected {test_df['is_anomaly'].sum()} anomalous readings.")

# 4. Evaluate Detector A
test_df['detector_A_flag'] = np.abs(test_df['injected_actual'] - test_df['prediction']) > threshold

prec_a = precision_score(test_df['is_anomaly'], test_df['detector_A_flag'])
rec_a = recall_score(test_df['is_anomaly'], test_df['detector_A_flag'])
f1_a = f1_score(test_df['is_anomaly'], test_df['detector_A_flag'])
print(f"Detector A (Residuals) - Precision: {prec_a:.3f}, Recall: {rec_a:.3f}, F1: {f1_a:.3f}")

# 5. Detector B: K-Means on Daily Profiles
print("Extracting daily profiles for K-Means...")
test_df['date'] = test_df['tstp'].dt.date
daily_profiles = test_df.pivot_table(index=['lclid', 'date'], columns=test_df['tstp'].dt.time, values='injected_actual').dropna()

kmeans = KMeans(n_clusters=5, random_state=42)
clusters = kmeans.fit_predict(daily_profiles.values)
distances = kmeans.transform(daily_profiles.values)
min_distances = np.min(distances, axis=1)

# Flag top 5% furthest days as anomalies
dist_threshold = np.percentile(min_distances, 95)
daily_profiles['detector_B_flag'] = (min_distances > dist_threshold).astype(int)

# Ground truth for days (if any reading in a day is an anomaly, the day is anomalous)
daily_gt = test_df.groupby(['lclid', 'date'])['is_anomaly'].max()
daily_eval = daily_profiles[['detector_B_flag']].join(daily_gt, how='inner')

prec_b = precision_score(daily_eval['is_anomaly'], daily_eval['detector_B_flag'])
rec_b = recall_score(daily_eval['is_anomaly'], daily_eval['detector_B_flag'])
f1_b = f1_score(daily_eval['is_anomaly'], daily_eval['detector_B_flag'])
print(f"Detector B (K-Means) - Precision: {prec_b:.3f}, Recall: {rec_b:.3f}, F1: {f1_b:.3f}")

# 6. Plot Examples
spike_idx = test_df[test_df['anomaly_type'] == 'Spike'].index[0]
lclid_ex = test_df.loc[spike_idx, 'lclid']
date_ex = test_df.loc[spike_idx, 'date']

ex_data = test_df[(test_df['lclid'] == lclid_ex) & (test_df['date'] == date_ex)].copy()

plt.figure(figsize=(10, 5))
plt.plot(ex_data['tstp'], ex_data['injected_actual'], label='Injected Actual', marker='o', color='red')
plt.plot(ex_data['tstp'], ex_data['actual'], label='Original Actual', linestyle='--', color='blue')
plt.plot(ex_data['tstp'], ex_data['prediction'], label='Forecast', color='green')
plt.scatter(ex_data[ex_data['detector_A_flag']]['tstp'], ex_data[ex_data['detector_A_flag']]['injected_actual'], 
            color='black', s=100, zorder=5, label='Flagged by Detector A')
plt.title(f"Detector A - Spike Detection ({lclid_ex} on {date_ex})")
plt.legend()
plt.savefig('results/detector_A_example.png')

print("Saved plots to results/detector_A_example.png")
with open('results/anomaly_metrics.txt', 'w') as f:
    f.write(f"Detector A - Prec: {prec_a:.3f}, Rec: {rec_a:.3f}, F1: {f1_a:.3f}\n")
    f.write(f"Detector B - Prec: {prec_b:.3f}, Rec: {rec_b:.3f}, F1: {f1_b:.3f}\n")

print("Done! Phase 5 Complete.")
