import org.apache.spark.sql.SparkSession
import org.apache.spark.ml.Pipeline
import org.apache.spark.ml.feature.{StringIndexer, OneHotEncoder, VectorAssembler}
import org.apache.spark.ml.regression.RandomForestRegressor

val spark = SparkSession.builder().appName("AnomalyPrep").getOrCreate()
import spark.implicits._

val featuresDF = spark.read.orc("hdfs://namenode:8020/user/hive/warehouse/smartmeter.db/features").filter($"month".startsWith("2013")).na.drop()
val train = featuresDF.filter($"tstp" < "2013-09-01 00:00:00").cache()
val valid = featuresDF.filter($"tstp" >= "2013-09-01 00:00:00" && $"tstp" < "2013-11-01 00:00:00").cache()
val test = featuresDF.filter($"tstp" >= "2013-11-01 00:00:00").cache()

val tariffIndexer = new StringIndexer().setInputCol("tariff").setOutputCol("tariff_idx").setHandleInvalid("keep")
val acornIndexer = new StringIndexer().setInputCol("acorn_group").setOutputCol("acorn_idx").setHandleInvalid("keep")
val tariffEncoder = new OneHotEncoder().setInputCol("tariff_idx").setOutputCol("tariff_vec")
val acornEncoder = new OneHotEncoder().setInputCol("acorn_idx").setOutputCol("acorn_vec")
val featureCols = Array("lag_1", "lag_48", "lag_336", "rolling_mean_48", "rolling_std_48", "temperature", "hour_of_day", "is_weekend", "is_holiday", "tariff_vec", "acorn_vec")
val assembler = new VectorAssembler().setInputCols(featureCols).setOutputCol("features_vec")

val rf = new RandomForestRegressor().setLabelCol("energy").setFeaturesCol("features_vec").setNumTrees(10).setMaxDepth(5)
val pipeline = new Pipeline().setStages(Array(tariffIndexer, acornIndexer, tariffEncoder, acornEncoder, assembler, rf))

val model = pipeline.fit(train)

val validPreds = model.transform(valid).select($"lclid", $"tstp", $"energy".as("actual"), $"prediction")
validPreds.coalesce(1).write.mode("overwrite").option("header", "true").csv("file:///opt/project/results/valid_predictions")

val testPreds = model.transform(test).select($"lclid", $"tstp", $"energy".as("actual"), $"prediction")
testPreds.coalesce(1).write.mode("overwrite").option("header", "true").csv("file:///opt/project/results/test_predictions")

System.exit(0)
