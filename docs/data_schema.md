# Smart Meters in London: Data Schema

This document outlines the raw schema of the dataset as extracted from the source files.

## 1. Meter Readings (`halfhourly_dataset.zip` -> `block_*.csv`)
* **`LCLid`** (String): Unique household identifier.
* **`tstp`** (String / Timestamp): The timestamp of the reading. Note the format carries 7 fractional digits (e.g. `2012-09-28 09:00:00.0000000`).
* **`energy(kWh/hh)`** (String): The half-hourly energy consumption in kWh. Note the problematic column name (parentheses, slash) and the fact that it contains literal `"Null"` strings (and potentially empty/negative values) requiring cleaning.

## 2. Household Metadata (`informations_households.csv`)
* **`LCLid`** (String): Unique household identifier.
* **`stdorToU`** (String): Tariff type (`Std` for standard, `ToU` for Time of Use dynamic pricing trial).
* **`Acorn`** (String): The specific ACORN demographic group (e.g., `ACORN-A`).
* **`Acorn_grouped`** (String): A broader grouping of the ACORN classification (e.g., `Affluent`).
* **`file`** (String): The specific block file containing this household's data (e.g., `block_0`).

## 3. Hourly Weather Data (`weather_hourly_darksky.csv`)
* **`time`** (String / Timestamp): The hour of the reading (e.g., `2011-11-11 00:00:00`). Note: Need to verify if this aligns with the meter timezone (UTC vs local time).
* **`temperature`** (Float): The temperature in degrees Celsius.
* **`visibility`** (Float): Visibility distance.
* **`windBearing`** (Integer): Wind direction.
* **`dewPoint`** (Float): Dew point temperature.
* **`pressure`** (Float): Atmospheric pressure.
* **`apparentTemperature`** (Float): "Feels like" temperature.
* **`windSpeed`** (Float): Wind speed.
* **`precipType`** (String): Type of precipitation (e.g., `rain`, `snow`).
* **`icon`** (String): A text summary icon of the weather.
* **`humidity`** (Float): Relative humidity ratio.
* **`summary`** (String): A text summary of the weather.

## 4. Daily Weather Data (`weather_daily_darksky.csv`)
Contains daily aggregate measures (min, max, avg) for temperature, wind, pressure, precipitation, sunrise/sunset times, and moon phase. (This is generally redundant if we roll up hourly data or use hourly directly).

## 5. Bank Holidays (`uk_bank_holidays.csv`)
* **`Bank holidays`** (String / Date): The date of the holiday (e.g., `2012-12-26`).
* **`Type`** (String): The name of the holiday (e.g., `Boxing Day`).

## 6. ACORN Details (`acorn_details.csv`)
Contains demographic lookup percentages per ACORN category. The columns are `MAIN CATEGORIES, CATEGORIES, REFERENCE, ACORN-A ... ACORN-Q`.
