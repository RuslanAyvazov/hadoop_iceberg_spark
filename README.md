# Hadoop, Spark и Iceberg в Docker

[![Проверка конфигураций](https://github.com/RuslanAyvazov/hadoop_iceberg_spark/actions/workflows/validate.yml/badge.svg)](https://github.com/RuslanAyvazov/hadoop_iceberg_spark/actions/workflows/validate.yml)

Две готовые сборки для локальной работы с Hadoop HDFS, Spark SQL, Apache
Iceberg, Parquet и Hive Metastore. Обе запускаются через Docker Compose и
принимают SQL-запросы из DBeaver на Windows.

## Быстрый запуск

Склонируйте репозиторий:

```bash
git clone https://github.com/RuslanAyvazov/hadoop_iceberg_spark.git
cd hadoop_iceberg_spark
```

Для первого знакомства запустите одноузловой вариант:

```bash
cd hadoop_iceberg_spark_single_node
docker compose up -d --build
docker compose ps
```

Кластерный вариант запускается аналогично:

```bash
cd ../hadoop_iceberg_spark_cluster
docker compose up -d --build
docker compose ps
```

Не запускайте обе сборки одновременно с настройками по умолчанию: они
используют одинаковые порты на компьютере.

## Подключение DBeaver

После запуска любой сборки создайте подключение с драйвером Apache Hive:

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

Подробные инструкции по запуску, проверке, настройке Spark, хранению данных и
диагностике находятся в `README` соответствующей сборки.

## Остановка и данные

В каталоге запущенной сборки выполните:

```bash
docker compose down
```

Данные HDFS и Hive Metastore сохранятся в именованных томах Docker. Команда
ниже удалит контейнеры вместе со всеми данными выбранной сборки:

```bash
docker compose down -v
```

Обе конфигурации предназначены для обучения и локальной разработки. Они не
включают защиту и отказоустойчивость, необходимые для промышленной среды.
