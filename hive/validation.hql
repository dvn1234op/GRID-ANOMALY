USE smartmeter;

-- Validation 1: No nulls or negatives in energy
SELECT 'Null or Negative Energy Count' as metric, COUNT(*) as val 
FROM readings_orc 
WHERE energy IS NULL OR energy < 0;

-- Validation 2: Uniqueness per household-timestamp
SELECT 'Duplicate (LCLid, tstp) Count' as metric, COUNT(*) as val
FROM (
    SELECT lclid, tstp, COUNT(*) as cnt
    FROM readings_orc
    GROUP BY lclid, tstp
    HAVING cnt > 1
) dupes;

-- Validation 3: Date coverage
SELECT 'Min Date' as metric, CAST(MIN(tstp) AS STRING) as val FROM readings_orc
UNION ALL
SELECT 'Max Date' as metric, CAST(MAX(tstp) AS STRING) as val FROM readings_orc;
