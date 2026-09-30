USE smartmeter;

-- Consumption by ACORN group
SELECT acorn_group, AVG(energy) as avg_consumption, SUM(energy) as total_consumption
FROM features
GROUP BY acorn_group
ORDER BY avg_consumption DESC;

-- Peak-hour profiles
SELECT hour_of_day, AVG(energy) as avg_energy
FROM features
GROUP BY hour_of_day
ORDER BY hour_of_day;

-- Std vs ToU
SELECT tariff, hour_of_day, AVG(energy) as avg_energy
FROM features
GROUP BY tariff, hour_of_day
ORDER BY tariff, hour_of_day;
