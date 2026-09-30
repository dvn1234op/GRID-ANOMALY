USE smartmeter;

DROP TABLE IF EXISTS features;

CREATE TABLE features STORED AS ORC AS
SELECT
    lclid,
    tstp,
    energy,
    tariff,
    acorn_group,
    temperature,
    is_holiday,
    month,
    -- Time features
    HOUR(tstp) as hour_of_day,
    CASE WHEN DATE_FORMAT(tstp, 'u') IN (6, 7) THEN 1 ELSE 0 END as is_weekend,
    DATE_FORMAT(tstp, 'u') as day_of_week,
    -- Lags
    LAG(energy, 1) OVER (PARTITION BY lclid ORDER BY tstp) as lag_1,
    LAG(energy, 48) OVER (PARTITION BY lclid ORDER BY tstp) as lag_48,
    LAG(energy, 336) OVER (PARTITION BY lclid ORDER BY tstp) as lag_336,
    -- Rolling aggregates (48 steps = 24 hours)
    AVG(energy) OVER (
        PARTITION BY lclid 
        ORDER BY tstp 
        ROWS BETWEEN 48 PRECEDING AND 1 PRECEDING
    ) as rolling_mean_48,
    STDDEV(energy) OVER (
        PARTITION BY lclid 
        ORDER BY tstp 
        ROWS BETWEEN 48 PRECEDING AND 1 PRECEDING
    ) as rolling_std_48
FROM readings_orc;
