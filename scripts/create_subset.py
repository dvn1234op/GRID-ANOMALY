import pandas as pd
import random
import os
import glob
import time

seed = 42
n_households = 400
random.seed(seed)

print("Loading informations_households.csv...")
info_df = pd.read_csv('data/informations_households.csv')
all_lclid = info_df['LCLid'].unique().tolist()
subset_lclid = set(random.sample(all_lclid, n_households))
print(f"Selected {len(subset_lclid)} households for subset.")

in_dir = 'data/halfhourly_dataset'
out_dir = 'data/subset_halfhourly_dataset'
os.makedirs(out_dir, exist_ok=True)

blocks = glob.glob(os.path.join(in_dir, '*.csv'))
print(f"Filtering {len(blocks)} block files...")
start_time = time.time()

total_rows = 0
for block in sorted(blocks):
    df = pd.read_csv(block)
    filtered = df[df['LCLid'].isin(subset_lclid)]
    if not filtered.empty:
        out_path = os.path.join(out_dir, os.path.basename(block))
        filtered.to_csv(out_path, index=False)
        total_rows += len(filtered)
        print(f"Saved {os.path.basename(block)}: {len(filtered)} rows")

print(f"Subset created! Total rows: {total_rows}")
print(f"Time taken: {time.time() - start_time:.2f} seconds")
