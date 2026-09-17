# Spark, Iceberg и Apache Ozone: учебный стенд

Этот вариант показывает Apache Ozone как хранилище для Spark. При запуске
создаются Ozone volume `/spark`, два FSO-bucket `/spark/warehouse` и
`/spark/data`, а также S3-bucket `/s3v/s3-demo`.

FSO (`FILE_SYSTEM_OPTIMIZED`) — тип bucket, оптимизированный для каталогов,
переименований и других привычных файловых операций. Именно его удобно
использовать со Spark через адреса `ofs://`.

## Что запускается

| Сервис | Назначение | Адрес с компьютера |
|---|---|---|
| Ozone Manager (OM) | volumes, buckets, keys и права | http://localhost:9874 |
| Storage Container Manager (SCM) | datanodes, контейнеры и репликация | http://localhost:9876 |
| Recon | сводный интерфейс наблюдения, только чтение | http://localhost:9888 |
| S3 Gateway | S3-совместимый доступ к Ozone | http://localhost:9878 |
| Ozone Explorer | Создание volume/bucket и просмотр файлов через Spark DataFrame | http://localhost:8090 |
| Spark Thrift Server | SQL из DBeaver/Beeline | `localhost:10000` |
| Spark UI | текущие задания Spark | http://localhost:4040 |

Стенд использует официальный образ Apache Ozone `2.2.1-slim`, Spark `3.5.4`
и Iceberg `1.6.1`.
Данные Ozone и локальный служебный каталог Spark сохраняются в именованных
томах Docker.

## 1. Запуск

Понадобится Docker Compose 2 и не менее 7–8 ГБ памяти для Docker.

```bash
cd hadoop_iceberg_spark_ozone
docker compose up -d
docker compose ps
```

Первый запуск дольше последующих: Docker скачивает официальный образ Ozone и
образ Spark либо собирает его локально. Стенд готов, когда `ozone-init`
завершился с кодом `0`, а `spark` и `ozone-ui` имеют состояние `healthy`.

Флаг `--build` для обычного запуска не нужен. Используйте его только после
изменения `Dockerfile` или файлов конфигурации Spark.

```bash
docker compose logs ozone-init
docker compose logs -f spark
```

## 2. Ozone Explorer: volume, bucket и Spark DataFrame в браузере

Откройте <http://localhost:8090>. Это учебный интерфейс из того же Docker-образа,
что и Spark. Он обращается к Ozone через Java-клиент, а выбранные данные читает
настоящим `spark.read` — строки и схема не имитируются в браузере.

Работа строится слева направо:

1. Создайте volume или нажмите `+ bucket` у существующего volume.
2. Выберите bucket и перейдите по каталогам в средней колонке.
3. Выберите файл либо каталог Parquet, CSV или JSON.
4. Нажмите **Открыть как DataFrame**. Справа появятся схема, строки и команда
   PySpark, которой были прочитаны данные.

Для каталогов с файлами Parquet обычно оставляйте формат `Авто`. Для CSV
интерфейс включает заголовок и определение типов по данным. Предпросмотр
ограничен 200 строками и предназначен для изучения, а не для выгрузки больших
наборов данных.

## 3. Первая проверка Ozone

Ozone хранит данные в иерархии: volume (том, верхняя область проекта), bucket
(бакет, контейнер данных) и key (ключ, отдельный файл или объект).

```text
volume -> bucket -> key
проект -> хранилище -> файл или объект
```

Посмотрите автоматически созданные объекты:

```bash
docker compose exec om ozone sh volume list /
docker compose exec om ozone sh bucket list /spark
docker compose exec om ozone sh bucket info /spark/data
docker compose exec om ozone sh key list /spark/data
```

Создайте собственные volume и bucket:

```bash
docker compose exec om ozone sh volume create /training
docker compose exec om ozone sh bucket create /training/raw --layout fso
docker compose exec om ozone sh bucket list /training
```

Запишите обычный файл и прочитайте его:

```bash
docker compose exec om bash -lc 'printf "hello ozone\n" >/tmp/hello.txt'
docker compose exec om ozone sh key put /training/raw/hello.txt /tmp/hello.txt
docker compose exec om ozone sh key list /training/raw
docker compose exec om ozone sh key get /training/raw/hello.txt /tmp/from-ozone.txt
docker compose exec om cat /tmp/from-ozone.txt
```

Полную справку можно получить без выхода из стенда:

```bash
docker compose exec om ozone sh volume --help
docker compose exec om ozone sh bucket --help
docker compose exec om ozone sh key --help
```

## 4. Spark читает и пишет Ozone

Основной адрес файловой системы в этом стенде:

```text
ofs://om/<volume>/<bucket>/<path>
```

Запустите готовый пример DataFrame:

```bash
docker compose exec spark \
  /opt/spark/bin/spark-submit /opt/lab/examples/ozone_dataframe.py
```

Он записывает Parquet в `ofs://om/spark/data/users-parquet`, читает его обратно
и печатает три строки. После этого файлы видны через Ozone Shell:

```bash
docker compose exec om ozone sh key list /spark/data
```

Для экспериментов в интерактивной консоли Spark:

```bash
docker compose exec spark /opt/spark/bin/pyspark
```

Пример внутри PySpark:

```python
path = "ofs://om/spark/data/my-numbers"
spark.range(1, 6).write.mode("overwrite").parquet(path)
spark.read.parquet(path).show()
```

## 5. Iceberg-таблица в Ozone через DBeaver

DBeaver остаётся удобным интерфейсом для Spark SQL. Он не управляет кластером
Ozone напрямую: SQL выполняет Spark, а Spark записывает файлы и метаданные в
Ozone.

Создайте подключение Apache Hive:

| Параметр | Значение |
|---|---|
| Сервер | `localhost` |
| Порт | `10000` |
| База | `default` |
| Пользователь | `hive` |
| Пароль | пустой |

```text
jdbc:hive2://localhost:10000/default;auth=noSasl
```

Проверочный SQL:

```sql
CREATE NAMESPACE IF NOT EXISTS ozone.demo;

CREATE TABLE IF NOT EXISTS ozone.demo.events (
    id BIGINT,
    message STRING,
    created_at TIMESTAMP
)
USING iceberg;

INSERT INTO ozone.demo.events
VALUES (1, 'Iceberg table in Ozone', current_timestamp());

SELECT * FROM ozone.demo.events;
SELECT * FROM ozone.demo.events.snapshots;
```

Каталог Iceberg имеет имя `ozone`, а его warehouse находится в
`ofs://om/spark/warehouse`.

## 6. Автоматическая сквозная проверка

Linux или WSL:

```bash
bash scripts/smoke-test.sh
```

Windows PowerShell, если команда `docker` доступна в Windows:

```powershell
.\scripts\smoke-test.ps1
```

Проверка создаёт Iceberg-таблицу через JDBC, записывает Parquet через PySpark,
читает данные обратно, показывает ключи в Ozone и вызывает предпросмотр через
API Ozone Explorer.

## 7. S3-совместимый доступ

Ozone имеет S3 Gateway. В учебном стенде создан bucket `s3-demo` в специальном
volume `/s3v`. При установленном AWS CLI можно выполнить:

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
aws --endpoint-url http://localhost:9878 s3api list-buckets
aws --endpoint-url http://localhost:9878 s3 cp ./README.md s3://s3-demo/readme.md
aws --endpoint-url http://localhost:9878 s3 ls s3://s3-demo/
```

Защита в учебном стенде выключена, поэтому подходят любые непустые ключи.
В защищённом кластере секрет выдаётся командой `ozone s3 getsecret`.

## Какой интерфейс для чего использовать

| Задача | Удобный интерфейс |
|---|---|
| Создать volume/bucket и просмотреть данные как DataFrame | Ozone Explorer |
| Настроить квоту, права и расширенные параметры | `ozone sh` |
| Посмотреть здоровье, объёмы, buckets и keys | Recon, только чтение |
| Выполнять SQL по таблицам | DBeaver или Beeline |
| Учиться DataFrame и файловым операциям Spark | PySpark / `spark-submit` |
| Работать как с S3-хранилищем | AWS CLI или другой S3-совместимый клиент |

Штатные интерфейсы OM, SCM и Recon прежде всего показывают состояние и
метаданные и не заменяют `ozone sh` для всех операций. Добавленный Ozone
Explorer закрывает учебный сценарий создания хранилищ и чтения данных через
Spark; расширенное администрирование остаётся в командной строке.

## Остановка и очистка

Обычная остановка сохраняет данные:

```bash
docker compose down
```

Полная очистка удаляет все данные этого стенда:

```bash
docker compose down -v
```

Не запускайте этот стенд одновременно с HDFS-вариантами репозитория без смены
портов: по умолчанию они используют `4040` и `10000`.
