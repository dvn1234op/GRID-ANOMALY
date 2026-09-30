/* etl.pig */
SET mapreduce.local.map.tasks.maximum 1;
SET mapreduce.local.reduce.tasks.maximum 1;
raw_readings = LOAD 'hdfs://namenode:8020/raw/halfhourly/*.csv' USING PigStorage(',') AS (LCLid:chararray, tstp:chararray, energy:chararray);
info = LOAD 'hdfs://namenode:8020/raw/metadata/informations_households.csv' USING PigStorage(',') AS (LCLid:chararray, stdorToU:chararray, Acorn:chararray, Acorn_grouped:chararray, file:chararray);
weather = LOAD 'hdfs://namenode:8020/raw/metadata/weather_hourly_darksky.csv' USING PigStorage(',') AS (visibility:chararray, windBearing:chararray, temperature:chararray, time:chararray, dewPoint:chararray, pressure:chararray, apparentTemperature:chararray, windSpeed:chararray, precipType:chararray, icon:chararray, humidity:chararray, summary:chararray);
holidays = LOAD 'hdfs://namenode:8020/raw/metadata/uk_bank_holidays.csv' USING PigStorage(',') AS (bank_holiday:chararray, type:chararray);

readings_no_header = FILTER raw_readings BY LCLid != 'LCLid';
info_no_header = FILTER info BY LCLid != 'LCLid';
weather_no_header = FILTER weather BY time != 'time';
holidays_no_header = FILTER holidays BY bank_holiday != 'Bank holidays';

SPLIT readings_no_header INTO 
    good_readings IF (energy != 'Null' AND energy != '' AND (float)energy >= 0.0),
    bad_readings_null IF (energy == 'Null' OR energy == ''),
    bad_readings_negative IF (energy != 'Null' AND energy != '' AND (float)energy < 0.0);

readings_parsed = FOREACH good_readings GENERATE 
    LCLid, 
    tstp, 
    (float)energy AS energy,
    SUBSTRING(tstp, 0, 10) AS date_str,
    CONCAT(SUBSTRING(tstp, 0, 13), ':00:00') AS hour_str;

grouped_readings = GROUP readings_parsed BY (LCLid, tstp);
dedup_readings = FOREACH grouped_readings {
    first_record = LIMIT readings_parsed 1;
    GENERATE FLATTEN(first_record);
};

weather_parsed = FOREACH weather_no_header GENERATE 
    time, 
    (float)temperature AS temperature;

holidays_parsed = FOREACH holidays_no_header GENERATE 
    bank_holiday, 
    1 AS is_holiday;

j1 = JOIN dedup_readings BY LCLid LEFT OUTER, info_no_header BY LCLid USING 'replicated';
j1_clean = FOREACH j1 GENERATE 
    dedup_readings::first_record::LCLid AS LCLid,
    dedup_readings::first_record::tstp AS tstp,
    dedup_readings::first_record::energy AS energy,
    dedup_readings::first_record::date_str AS date_str,
    dedup_readings::first_record::hour_str AS hour_str,
    info_no_header::stdorToU AS tariff,
    info_no_header::Acorn_grouped AS acorn_group;

j2 = JOIN j1_clean BY hour_str LEFT OUTER, weather_parsed BY time USING 'replicated';
j2_clean = FOREACH j2 GENERATE
    j1_clean::LCLid AS LCLid,
    j1_clean::tstp AS tstp,
    j1_clean::energy AS energy,
    j1_clean::date_str AS date_str,
    j1_clean::tariff AS tariff,
    j1_clean::acorn_group AS acorn_group,
    weather_parsed::temperature AS temperature;

j3 = JOIN j2_clean BY date_str LEFT OUTER, holidays_parsed BY bank_holiday USING 'replicated';
final_clean = FOREACH j3 GENERATE
    j2_clean::LCLid AS LCLid,
    j2_clean::tstp AS tstp,
    j2_clean::energy AS energy,
    j2_clean::tariff AS tariff,
    j2_clean::acorn_group AS acorn_group,
    j2_clean::temperature AS temperature,
    (holidays_parsed::is_holiday IS NOT NULL ? 1 : 0) AS is_holiday;

rmf hdfs://namenode:8020/clean
rmf hdfs://namenode:8020/rejects/null
rmf hdfs://namenode:8020/rejects/negative

STORE final_clean INTO 'hdfs://namenode:8020/clean' USING PigStorage(',');
STORE bad_readings_null INTO 'hdfs://namenode:8020/rejects/null' USING PigStorage(',');
STORE bad_readings_negative INTO 'hdfs://namenode:8020/rejects/negative' USING PigStorage(',');
