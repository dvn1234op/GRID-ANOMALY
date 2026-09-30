from pyspark.sql import SparkSession

print("Initializing Spark with Hive Support...")
spark = SparkSession.builder \
    .appName("Hive Integration Test") \
    .enableHiveSupport() \
    .config("hive.metastore.uris", "thrift://hive-metastore:9083") \
    .getOrCreate()

print("Querying Hive 'smartmeter.features' table...")
df = spark.sql("SELECT lclid, tstp, energy, lag_48, rolling_mean_48 FROM smartmeter.features LIMIT 5")
df.show()

print("Spark can successfully query Hive tables!")
spark.stop()
