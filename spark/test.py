from pyspark.sql import SparkSession
spark = SparkSession.builder.appName("SmokeTest").enableHiveSupport().getOrCreate()
df = spark.sql("SELECT * FROM test_table")
df.show()
