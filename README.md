# Hadoop, Spark и Iceberg в Docker

[![Проверка конфигураций](https://github.com/RuslanAyvazov/hadoop_iceberg_spark/actions/workflows/validate.yml/badge.svg)](https://github.com/RuslanAyvazov/hadoop_iceberg_spark/actions/workflows/validate.yml)
[![Сборка Docker-образов](https://github.com/RuslanAyvazov/hadoop_iceberg_spark/actions/workflows/publish-images.yml/badge.svg)](https://github.com/RuslanAyvazov/hadoop_iceberg_spark/actions/workflows/publish-images.yml)

Три готовые сборки для локальной работы с Hadoop HDFS или Apache Ozone,
Spark SQL, Apache Iceberg и Parquet. Все запускаются через Docker Compose.
Ozone-вариант по умолчанию открывает JupyterLab со Scala; SQL-сервер для
DBeaver в нём включается отдельно.

## Быстрый запуск

Склонируйте репозиторий:

```bash
git clone https://github.com/RuslanAyvazov/hadoop_iceberg_spark.git
cd hadoop_iceberg_spark
```

Для первого знакомства запустите одноузловой вариант:

```bash
cd hadoop_iceberg_spark_single_node
docker compose up -d
docker compose ps
```

Кластерный вариант запускается аналогично:

```bash
cd ../hadoop_iceberg_spark_cluster
docker compose up -d
docker compose ps
```

Для знакомства с Apache Ozone и его связкой со Spark:

```bash
cd ../hadoop_iceberg_spark_ozone
docker compose up -d
docker compose ps
```

После запуска откройте JupyterLab по адресу <http://localhost:8888> и выберите
готовый блокнот `01_spark_scala_ozone.ipynb`. Scala-код выполняется ядром
Apache Toree внутри Spark и читает Ozone как Spark DataFrame через `ofs://`.

Не запускайте сборки одновременно с настройками по умолчанию: они
используют одинаковые порты на компьютере.

## Готовые образы и локальная сборка

При обычном запуске Docker сначала получает готовый образ из GitHub Container
Registry. Если образ уже скачан, он используется повторно:

```bash
docker compose up -d
```

Чтобы явно скачать свежий готовый образ и запретить локальную сборку:

```bash
docker compose pull
docker compose up -d --no-build
```

Для самостоятельной сборки из `Dockerfile` используйте:

```bash
docker compose up -d --build
```

Для HDFS опубликованы два образа для `linux/amd64`:

```text
ghcr.io/ruslanayvazov/hadoop-iceberg-spark-single-node:3.3.6-3.5.4
ghcr.io/ruslanayvazov/hadoop-iceberg-spark-cluster:3.3.6-3.5.4
```

Ozone-вариант использует официальный образ `apache/ozone:2.2.1-slim` и готовый
образ Spark с JupyterLab и Scala-ядром Apache Toree:
`ghcr.io/ruslanayvazov/hadoop-iceberg-spark-ozone:2.2.1-3.5.4`.

## Подключение DBeaver

В одноузловой и кластерной сборках SQL-сервер запускается сразу. В
Ozone-сборке сначала включите необязательный профиль:

```bash
docker compose --profile sql up -d spark
```

Затем создайте в DBeaver подключение с драйвером Apache Hive:

| Параметр | Значение |
|---|---|
| Сервер | `localhost` |
| Порт | `10000` |
| База или схема | `default` |
| Пользователь | `hive` |
| Пароль | оставить пустым |

Полный адрес подключения:

```text
jdbc:hive2://localhost:10000/default;auth=noSasl
```

Проверочный запрос:

```sql
CREATE NAMESPACE IF NOT EXISTS spark_catalog.demo;

CREATE TABLE IF NOT EXISTS spark_catalog.demo.events (
    id BIGINT,
    message STRING,
    created_at TIMESTAMP
)
USING iceberg;

INSERT INTO spark_catalog.demo.events
VALUES (1, 'Spark SQL works', current_timestamp());

SELECT * FROM spark_catalog.demo.events;
```

## Какой вариант выбрать

| Вариант | Для чего подходит | Требования к памяти Docker |
|---|---|---:|
| [Одноузловой](hadoop_iceberg_spark_single_node/) | SQL, Iceberg, Parquet, знакомство с HDFS | от 6 ГБ |
| [Кластерный](hadoop_iceberg_spark_cluster/) | Три HDFS-узла, YARN, репликация и эксперименты с отказами | от 12 ГБ, желательно 16 ГБ |
| [Ozone](hadoop_iceberg_spark_ozone/) | JupyterLab, Scala, Spark DataFrame через `ofs://`, volumes/buckets/keys, S3 Gateway и Recon | от 7–8 ГБ |

Подробные инструкции по запуску, проверке, настройке Spark, хранению данных и
диагностике находятся в `README` соответствующей сборки.

## Остановка и данные

В каталоге запущенной сборки выполните:

```bash
docker compose down
```

Данные хранилища и служебных каталогов сохранятся в именованных томах Docker. Команда
ниже удалит контейнеры вместе со всеми данными выбранной сборки:

```bash
docker compose down -v
```

Все конфигурации предназначены для обучения и локальной разработки. Они не
включают защиту и отказоустойчивость, необходимые для промышленной среды.
