# Spark, Scala, JupyterLab и Apache Ozone

Учебный стенд показывает Apache Ozone как хранилище для Spark. JupyterLab
запускает Scala-код через ядро Apache Toree, а Spark читает и пишет данные
непосредственно по адресам `ofs://`.

При первом запуске автоматически создаются volume `/spark`, FSO-bucket
`/spark/warehouse` и `/spark/data`, а также S3-bucket `/s3v/s3-demo`.
FSO (`FILE_SYSTEM_OPTIMIZED`) — тип bucket, приспособленный к каталогам,
переименованиям и другим файловым операциям Spark.

## Что запускается

| Сервис | Назначение | Адрес с компьютера |
|---|---|---|
| JupyterLab + Apache Toree | Блокноты Scala и Spark DataFrame | http://localhost:8888 |
| Ozone Recon | Состояние Ozone, volumes, buckets и keys | http://localhost:9888 |
| Ozone Manager | Метаданные Ozone | http://localhost:9874 |
| Storage Container Manager | Узлы, контейнеры и репликация | http://localhost:9876 |
| S3 Gateway | S3-совместимый доступ | http://localhost:9878 |
| Spark Thrift Server | Spark SQL из DBeaver или Beeline | `localhost:10000` |
| Spark UI | Текущие задания Thrift Server | http://localhost:4040 |

Стенд использует Apache Ozone `2.2.1`, Spark `3.5.4`, Scala `2.12`,
Iceberg `1.6.1`, JupyterLab `4.6.3` и Apache Toree `0.5.0`.

## 1. Запуск

Понадобится Docker Compose 2 и не менее 7–8 ГБ памяти для Docker.

```bash
cd hadoop_iceberg_spark_ozone
docker compose up -d
docker compose ps
```

Стенд готов, когда `ozone-init` завершился с кодом `0`, а `spark` и `jupyter`
имеют состояние `healthy`. Откройте <http://localhost:8888>.

Jupyter доступен только с текущего компьютера через `127.0.0.1`. В учебном
стенде пароль и токен отключены. При необходимости задайте токен перед запуском:

```bash
export JUPYTER_TOKEN='my-secret-token'
docker compose up -d
```

Рабочие блокноты сохраняются в именованном томе `jupyter-work`. Поэтому правки
не исчезают после `docker compose down` или обновления образа.

## 2. Первый блокнот Scala

Откройте файл `01_spark_scala_ozone.ipynb` и выполняйте ячейки сверху вниз.
Он использует ядро **Apache Toree - Scala** и показывает полный путь данных:

```text
Scala Seq -> Spark DataFrame -> Parquet в Ozone -> Spark DataFrame
```

Основной адрес файловой системы:

```text
ofs://om/<volume>/<bucket>/<path>
```

Минимальный пример Scala из блокнота:

```scala
import org.apache.spark.sql.SparkSession

val ozoneSpark = SparkSession.builder()
  .appName("Jupyter Scala with Apache Ozone")
  .getOrCreate()

import ozoneSpark.implicits._

val path = "ofs://om/spark/data/my-scala-data"
val df = Seq((1L, "Анна"), (2L, "Борис")).toDF("id", "name")

df.write.mode("overwrite").parquet(path)
ozoneSpark.read.parquet(path).show(false)
```

JupyterLab — оболочка для файлов и блокнотов. Apache Toree — ядро, которое
принимает Scala-код из ячейки и выполняет его внутри Spark. Поэтому результат
является настоящим Spark DataFrame, а не таблицей, нарисованной интерфейсом.

## 3. Как устроены данные Ozone

Ozone хранит данные в иерархии:

```text
volume -> bucket -> key
проект -> хранилище -> файл или объект
```

Посмотреть автоматически созданные объекты:

```bash
docker compose exec om ozone sh volume list /
docker compose exec om ozone sh bucket list /spark
docker compose exec om ozone sh key list /spark/data
```

Создать собственные volume и bucket:

```bash
docker compose exec om ozone sh volume create /training
docker compose exec om ozone sh bucket create /training/raw --layout fso
docker compose exec om ozone sh bucket list /training
```

После записи из блокнота физические файлы можно увидеть так:

```bash
docker compose exec om ozone sh key list /spark/data
```

## 4. Iceberg в Ozone

Spark-каталог `ozone` уже настроен. Его хранилище находится в
`ofs://om/spark/warehouse`. В готовом блокноте есть Scala-ячейка:

```scala
ozoneSpark.sql("CREATE NAMESPACE IF NOT EXISTS ozone.notebook")
ozoneSpark.sql("""
  CREATE TABLE IF NOT EXISTS ozone.notebook.events (
    id BIGINT,
    message STRING
  ) USING iceberg
""")
ozoneSpark.sql("INSERT INTO ozone.notebook.events VALUES (1, 'Scala works')")
ozoneSpark.sql("SELECT * FROM ozone.notebook.events").show(false)
```

## 5. DBeaver остаётся доступен

JupyterLab нужен для Scala, Spark DataFrame и пошаговых экспериментов. DBeaver
можно использовать параллельно для SQL по адресу:

```text
jdbc:hive2://localhost:10000/default;auth=noSasl
```

Пользователь: `hive`. Пароль пустой.

## 6. Автоматическая проверка

Linux или WSL:

```bash
bash scripts/smoke-test.sh
```

Проверка выполняет SQL через Spark Thrift Server, записывает Parquet в Ozone,
затем исполняет готовый Scala-блокнот через ядро Toree. Успешный итог:

```text
JUPYTER_SCALA_OZONE_OK
```

## 7. Штатные интерфейсы Ozone

Recon по адресу <http://localhost:9888> показывает состояние кластера и
метаданные. Создание и точная настройка volume/bucket выполняются через
`ozone sh`. JupyterLab отвечает за работу с данными через Spark, а не за
администрирование Ozone.

## Остановка и очистка

Обычная остановка сохраняет данные и блокноты:

```bash
docker compose down
```

Полная очистка удаляет все данные стенда и рабочие блокноты:

```bash
docker compose down -v
```

Не запускайте этот стенд одновременно с HDFS-вариантами репозитория без смены
портов: по умолчанию они используют `4040` и `10000`.
