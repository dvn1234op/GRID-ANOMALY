CREATE DATABASE IF NOT EXISTS smartmeter;
USE smartmeter;

DROP TABLE IF EXISTS readings_raw;
CREATE EXTERNAL TABLE readings_raw (
    lclid STRING,
    tstp STRING,
    energy FLOAT,
    tariff STRING,
    acorn_group STRING,
    temperature FLOAT,
    is_holiday INT
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/clean';

DROP TABLE IF EXISTS readings_orc;
CREATE TABLE readings_orc (
    lclid STRING,
    tstp TIMESTAMP,
    energy FLOAT,
    tariff STRING,
    acorn_group STRING,
    temperature FLOAT,
    is_holiday INT
)
PARTITIONED BY (month STRING)
STORED AS ORC;

SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = nonstrict;
-- Suppress Tez/MR execution errors for small files if any
SET hive.mapred.mode = nonstrict;

INSERT OVERWRITE TABLE readings_orc PARTITION (month)
SELECT 
    lclid,
    CAST(SUBSTR(tstp, 1, 19) AS TIMESTAMP) as tstp,
    energy,
    tariff,
    acorn_group,
    temperature,
    is_holiday,
    SUBSTR(tstp, 1, 7) as month
FROM readings_raw;
