import org.apache.spark.sql.SparkSession

val spark = SparkSession.builder().appName("HiveIntegrationTest").getOrCreate()

println("=== Spark Hive Integration Test ===")
val df = spark.read.orc("hdfs://namenode:8020/user/hive/warehouse/smartmeter.db/features")
df.createOrReplaceTempView("features")
spark.sql("SELECT lclid, energy, lag_48, rolling_mean_48 FROM features LIMIT 5").show()
println("=== Success ===")
System.exit(0)
