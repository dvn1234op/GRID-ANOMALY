import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions._
import org.apache.spark.ml.Pipeline
import org.apache.spark.ml.feature.{StringIndexer, OneHotEncoder, VectorAssembler}
import org.apache.spark.ml.regression.{RandomForestRegressor, GBTRegressor}
import org.apache.spark.ml.evaluation.RegressionEvaluator
import java.io.{File, PrintWriter}

// 1. Init Spark
val spark = SparkSession.builder().appName("GridAnomalyForecasting").getOrCreate()
import spark.implicits._

println("=== Phase 4: Forecasting ===")

// 2. Load Data
val isFull = sys.env.getOrElse("MODE", "--subset") == "--full"

val featuresDF = spark.read.orc("hdfs://namenode:8020/user/hive/warehouse/smartmeter.db/features")
  .filter($"month".startsWith("2013"))
  .na.drop() // Drop rows with null lags/rolling stats

// 3. Time-based Split
var train = featuresDF.filter($"tstp" < "2013-09-01 00:00:00").cache()
if (isFull) {
  println("FULL DATA MODE: Sampling training data to 5% to fit laptop memory bounds.")
  train = train.sample(0.05).cache()
}
val valid = featuresDF.filter($"tstp" >= "2013-09-01 00:00:00" && $"tstp" < "2013-11-01 00:00:00").cache()
val test = featuresDF.filter($"tstp" >= "2013-11-01 00:00:00").cache()

println(s"Data Split -> Train: ${train.count()}, Valid: ${valid.count()}, Test: ${test.count()}")

// 4. MLlib Pipeline
val tariffIndexer = new StringIndexer().setInputCol("tariff").setOutputCol("tariff_idx").setHandleInvalid("keep")
val acornIndexer = new StringIndexer().setInputCol("acorn_group").setOutputCol("acorn_idx").setHandleInvalid("keep")

val tariffEncoder = new OneHotEncoder().setInputCol("tariff_idx").setOutputCol("tariff_vec")
val acornEncoder = new OneHotEncoder().setInputCol("acorn_idx").setOutputCol("acorn_vec")

val featureCols = Array("lag_1", "lag_48", "lag_336", "rolling_mean_48", "rolling_std_48", "temperature", "hour_of_day", "is_weekend", "is_holiday", "tariff_vec", "acorn_vec")
val assembler = new VectorAssembler().setInputCols(featureCols).setOutputCol("features_vec")

// Using Random Forest for fast training on laptop
val rf = new RandomForestRegressor()
  .setLabelCol("energy")
  .setFeaturesCol("features_vec")
  .setNumTrees(10)
  .setMaxDepth(5)

val pipeline = new Pipeline().setStages(Array(tariffIndexer, acornIndexer, tariffEncoder, acornEncoder, assembler, rf))

// 5. Train Model
println("Training RandomForestRegressor...")
val model = pipeline.fit(train)

// 6. Predict on Test Set
println("Making predictions on test set...")
val predictions = model.transform(test)

// 7. Calculate Metrics (Model vs Baselines)
val resultsDF = predictions.select(
  $"lclid", $"tstp", $"acorn_group", $"tariff", $"hour_of_day",
  $"energy".as("actual"),
  $"prediction",
  $"lag_48".as("baseline_yesterday"),
  $"lag_336".as("baseline_lastweek")
)

def smape(actual: org.apache.spark.sql.Column, pred: org.apache.spark.sql.Column): org.apache.spark.sql.Column = {
  abs(actual - pred) * 2.0 / (abs(actual) + abs(pred) + 1e-6)
}

val evalDF = resultsDF
  .withColumn("err_model_sq", pow($"actual" - $"prediction", 2))
  .withColumn("err_model_abs", abs($"actual" - $"prediction"))
  .withColumn("smape_model", smape($"actual", $"prediction"))
  .withColumn("err_yest_sq", pow($"actual" - $"baseline_yesterday", 2))
  .withColumn("err_yest_abs", abs($"actual" - $"baseline_yesterday"))
  .withColumn("smape_yest", smape($"actual", $"baseline_yesterday"))
  .withColumn("err_week_sq", pow($"actual" - $"baseline_lastweek", 2))
  .withColumn("err_week_abs", abs($"actual" - $"baseline_lastweek"))
  .withColumn("smape_week", smape($"actual", $"baseline_lastweek"))
  .cache()

// Overall Metrics
val overall = evalDF.agg(
  sqrt(avg("err_model_sq")).as("Model_RMSE"),
  avg("err_model_abs").as("Model_MAE"),
  avg("smape_model").as("Model_sMAPE"),
  sqrt(avg("err_yest_sq")).as("Yesterday_RMSE"),
  avg("err_yest_abs").as("Yesterday_MAE"),
  avg("smape_yest").as("Yesterday_sMAPE"),
  sqrt(avg("err_week_sq")).as("LastWeek_RMSE"),
  avg("err_week_abs").as("LastWeek_MAE"),
  avg("smape_week").as("LastWeek_sMAPE")
).first()

new File("/opt/project/results").mkdirs()

val metricsWriter = new PrintWriter(new File("/opt/project/results/forecast_metrics_overall.csv"))
metricsWriter.println("Model_Type,RMSE,MAE,sMAPE")
metricsWriter.println(s"RandomForest,${overall.getAs[Double]("Model_RMSE")},${overall.getAs[Double]("Model_MAE")},${overall.getAs[Double]("Model_sMAPE")}")
metricsWriter.println(s"Baseline_Yesterday,${overall.getAs[Double]("Yesterday_RMSE")},${overall.getAs[Double]("Yesterday_MAE")},${overall.getAs[Double]("Yesterday_sMAPE")}")
metricsWriter.println(s"Baseline_LastWeek,${overall.getAs[Double]("LastWeek_RMSE")},${overall.getAs[Double]("LastWeek_MAE")},${overall.getAs[Double]("LastWeek_sMAPE")}")
metricsWriter.close()

// Grouped Metrics (Acorn, Tariff, Hour)
evalDF.groupBy("acorn_group").agg(sqrt(avg("err_model_sq")).as("rmse"), avg("err_model_abs").as("mae"), avg("smape_model").as("smape"))
  .coalesce(1).write.mode("overwrite").csv("file:///opt/project/results/forecast_metrics_by_acorn")

evalDF.groupBy("tariff").agg(sqrt(avg("err_model_sq")).as("rmse"), avg("err_model_abs").as("mae"), avg("smape_model").as("smape"))
  .coalesce(1).write.mode("overwrite").csv("file:///opt/project/results/forecast_metrics_by_tariff")

evalDF.groupBy("hour_of_day").agg(sqrt(avg("err_model_sq")).as("rmse"), avg("err_model_abs").as("mae"), avg("smape_model").as("smape"))
  .coalesce(1).write.mode("overwrite").csv("file:///opt/project/results/forecast_metrics_by_hour")

// 8. Feature Importances
val rfModel = model.stages.last.asInstanceOf[org.apache.spark.ml.regression.RandomForestRegressionModel]
val importances = rfModel.featureImportances.toArray

// Match importances to columns (approximating indices since OneHotEncoder expands)
val featWriter = new PrintWriter(new File("/opt/project/results/feature_importances.txt"))
featWriter.println("Feature Importances Vector (ordered by assembler input):")
featWriter.println(featureCols.mkString(", "))
featWriter.println(importances.mkString(", "))
featWriter.close()

println("=== Forecasting Phase Complete! Metrics saved to results/ ===")
System.exit(0)
