from pyspark.sql import SparkSession


spark = SparkSession.builder.appName("ozone-dataframe-example").getOrCreate()

target = "ofs://om/spark/data/users-parquet"
source = spark.createDataFrame(
    [(1, "Анна"), (2, "Борис"), (3, "Светлана")],
    ["id", "name"],
)

source.write.mode("overwrite").parquet(target)

loaded = spark.read.parquet(target).orderBy("id")
loaded.show(truncate=False)

assert loaded.count() == 3
print(f"OZONE_DATAFRAME_OK path={target} rows=3")

spark.stop()
