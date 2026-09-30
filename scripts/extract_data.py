import zipfile
import os
import sys

zip_path = 'Dataset.zip'
out_dir = 'data'

needed_files = [
    'informations_households.csv',
    'weather_hourly_darksky.csv',
    'weather_daily_darksky.csv',
    'acorn_details.csv',
    'uk_bank_holidays.csv'
]

os.makedirs(out_dir, exist_ok=True)

print(f"Extracting selected files from {zip_path} to {out_dir}...")
with zipfile.ZipFile(zip_path, 'r') as z:
    for f in z.namelist():
        if any(f.endswith(nf) for nf in needed_files) or 'halfhourly_dataset/halfhourly_dataset/' in f:
            # Flatten path for root files
            if '/' not in f:
                print(f"Extracting {f}")
                z.extract(f, out_dir)
            elif 'halfhourly_dataset/halfhourly_dataset/' in f:
                # Extract directly to data/halfhourly_dataset/
                filename = os.path.basename(f)
                if filename.endswith('.csv'):
                    os.makedirs(os.path.join(out_dir, 'halfhourly_dataset'), exist_ok=True)
                    out_path = os.path.join(out_dir, 'halfhourly_dataset', filename)
                    with z.open(f) as source, open(out_path, 'wb') as target:
                        target.write(source.read())

print("Extraction complete.")
