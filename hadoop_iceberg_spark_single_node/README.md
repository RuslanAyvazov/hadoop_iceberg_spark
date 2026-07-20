# Hadoop, Spark и Iceberg: одноузловой стенд в Docker

[![Проверка конфигураций](https://github.com/RuslanAyvazov/hadoop_iceberg_spark/actions/workflows/validate.yml/badge.svg)](https://github.com/RuslanAyvazov/hadoop_iceberg_spark/actions/workflows/validate.yml)
[![Сборка Docker-образов](https://github.com/RuslanAyvazov/hadoop_iceberg_spark/actions/workflows/publish-images.yml/badge.svg)](https://github.com/RuslanAyvazov/hadoop_iceberg_spark/actions/workflows/publish-images.yml)

Готовый локальный стенд для Spark SQL, HDFS, Apache Iceberg, Parquet и Hive
Metastore. Вся инфраструктура запускается одной командой через Docker Compose,
а SQL-запросы можно выполнять из DBeaver на Windows.

## Быстрый запуск

Понадобятся:

- Docker Desktop или Docker Engine;
- Docker Compose версии 2;
- не менее 6 ГБ памяти, доступной Docker;
- около 10 ГБ свободного места для образа и данных;
- свободные порты `4040`, `9870` и `10000`.

Склонируйте репозиторий и запустите стенд:

```bash
git clone https://github.com/RuslanAyvazov/hadoop_iceberg_spark.git
cd hadoop_iceberg_spark/hadoop_iceberg_spark_single_node
docker compose up -d
docker compose ps
```

При первом запуске Docker скачивает готовый образ, форматирует новый HDFS и
создаёт схему Hive Metastore. Если готовый образ недоступен, Compose может
собрать его локально из `Dockerfile`.

Стенд готов, когда оба сервиса имеют состояние `healthy`:

```text
postgres   healthy
bigdata    healthy
```

Следить за запуском:

```bash
docker compose logs -f bigdata
```

## Готовый образ и локальная сборка

Готовый образ для `linux/amd64`:

```text
ghcr.io/ruslanayvazov/hadoop-iceberg-spark-single-node:3.3.6-3.5.4
```

Явно скачать его и исключить локальную сборку:

```bash
docker compose pull
docker compose up -d --no-build
```

Собрать образ самостоятельно:

```bash
docker compose up -d --build
```

## Подключение DBeaver

Создайте подключение с драйвером Apache Hive и укажите:

| Параметр | Значение |
|---|---|
| Сервер (Host) | `localhost` |
| Порт (Port) | `10000` |
| База или схема | `default` |
| Пользователь | `hive` |
| Пароль | оставить пустым |

Полный адрес JDBC — стандартного интерфейса подключения Java-приложений к
базам данных:

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

Некоторые версии DBeaver автоматически отправляют `SHOW INDEX ON`. Spark SQL
не поддерживает эту команду и может показать синтаксическую ошибку. Это не
мешает выполнению обычных запросов и работе с таблицами.

## Автоматическая проверка

В Linux или WSL:

```bash
bash scripts/smoke-test.sh
```

В Windows PowerShell:

```powershell
.\scripts\smoke-test.ps1
```

Проверка создаёт Iceberg-таблицу, записывает строку, читает её через JDBC и
показывает созданный снимок состояния Iceberg.

## Веб-интерфейсы

| Сервис | Адрес |
|---|---|
| HDFS NameNode | http://localhost:9870 |
| Активное приложение Spark | http://localhost:4040 |

## Что входит в стенд

| Компонент | Версия | Назначение |
|---|---:|---|
| Hadoop HDFS | 3.3.6 | Хранение файлов |
| Spark SQL | 3.5.4 | Выполнение SQL-запросов |
| Spark Thrift Server | 3.5.4 | Подключение DBeaver по JDBC |
| Apache Iceberg | 1.6.1 | Формат таблиц и управление снимками состояния |
| Parquet | 1.13.1 | Колоночное хранение файлов данных |
| Hive Metastore | 3.1.3 | Каталог баз, таблиц и расположений файлов |
| PostgreSQL | 16 | База данных Hive Metastore |
| Java | 17 | Среда выполнения Hadoop и Spark |

Spark работает в локальном режиме `local[*]`: один процесс использует все
доступные процессорные ядра контейнера. HDFS содержит один NameNode, один
DataNode и один SecondaryNameNode.

Если нужен стенд с тремя HDFS-узлами и распределением Spark через YARN,
используйте каталог
[`hadoop_iceberg_spark_cluster`](../hadoop_iceberg_spark_cluster/).

## Где сохраняются данные

Docker создаёт именованные тома — хранилища, которыми управляет сам Docker:

```text
hadoop-iceberg-spark-single-node_postgres-data
hadoop-iceberg-spark-single-node_hdfs-namenode
hadoop-iceberg-spark-single-node_hdfs-datanode
hadoop-iceberg-spark-single-node_hdfs-secondary
```

Обычная остановка сохраняет таблицы и метаданные:

```bash
docker compose down
```

Полностью удалить стенд вместе со всеми данными:

```bash
docker compose down -v
```

Флаг `-v` необратимо удаляет HDFS и базу Hive Metastore.

## Настройка портов и памяти

Создайте `.env` из примера:

```bash
cp .env.example .env
```

Для Windows PowerShell:

```powershell
Copy-Item .env.example .env
```

Пример:

```dotenv
HIVE_JDBC_PORT=10000
NAMENODE_UI_PORT=9870
SPARK_UI_PORT=4040
SPARK_DRIVER_MEMORY=2g
```

Общие параметры Spark находятся в
[`conf/spark/spark-defaults.conf`](conf/spark/spark-defaults.conf). После их
изменения пересоберите образ:

```bash
docker compose up -d --build
```

Параметры отдельного подключения можно менять командами SQL:

```sql
SET spark.sql.shuffle.partitions=16;
SET spark.sql.adaptive.enabled=true;
```

В DBeaver их можно выполнять автоматически через `Edit Connection → Connection
settings → Initialization → Bootstrap queries`.

## Диагностика

```bash
# Состояние контейнеров
docker compose ps

# Последние сообщения всех сервисов
docker compose logs --tail=200

# Список файлов в хранилище таблиц
docker compose exec bigdata hdfs dfs -ls -R /warehouse

# Подключение к Spark SQL из контейнера
docker compose exec bigdata /opt/spark/bin/beeline \
  -u 'jdbc:hive2://localhost:10000/default;auth=noSasl' \
  -n hive
```

Если порты заняты, измените их в `.env`. Для полностью чистого повторного
запуска используйте `docker compose down -v`, понимая, что эта команда удалит
все данные стенда.

## Безопасность

Стенд предназначен для локальной разработки и обучения. Порты опубликованы
только на `127.0.0.1`, а PostgreSQL не доступен снаружи Docker-сети. Не
публикуйте JDBC-порт в интернет и замените стандартные пароли перед
использованием в общей сети.
