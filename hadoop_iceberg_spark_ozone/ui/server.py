#!/usr/bin/env python3
"""Small dependency-free web UI for exploring Ozone with Spark DataFrames."""

from __future__ import annotations

import json
import mimetypes
import os
import re
import signal
import threading
import time
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, unquote, urlparse


STATIC_ROOT = Path(__file__).resolve().parent / "static"
NAME_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$")
SUPPORTED_FORMATS = {"parquet", "csv", "json"}
MAX_BODY_BYTES = 1_048_576


class ApiError(Exception):
    def __init__(self, message: str, status: int = HTTPStatus.BAD_REQUEST):
        super().__init__(message)
        self.status = status


def validate_ozone_name(value: Any, label: str) -> str:
    name = str(value or "").strip().lower()
    if not NAME_PATTERN.fullmatch(name):
        raise ApiError(
            f"{label}: используйте 3–63 символа — строчные латинские буквы, цифры и дефис."
        )
    return name


def normalize_ofs_path(value: Any) -> str:
    raw = str(value or "").strip()
    parsed = urlparse(raw)
    if parsed.scheme != "ofs" or parsed.netloc != "om":
        raise ApiError("Путь должен начинаться с ofs://om/.")
    parts = [unquote(part) for part in parsed.path.split("/") if part]
    if len(parts) < 2:
        raise ApiError("Укажите volume и bucket: ofs://om/<volume>/<bucket>.")
    if any(part in {".", ".."} for part in parts):
        raise ApiError("Переходы . и .. в пути запрещены.")
    return "ofs://om/" + "/".join(parts)


def infer_format(path: str, requested: Any = "auto") -> str:
    selected = str(requested or "auto").lower()
    if selected in SUPPORTED_FORMATS:
        return selected
    if selected != "auto":
        raise ApiError("Поддерживаются форматы Parquet, CSV и JSON.")
    lowered = path.lower().rstrip("/")
    if lowered.endswith(".csv"):
        return "csv"
    if lowered.endswith(".json") or lowered.endswith(".jsonl"):
        return "json"
    return "parquet"


def clean_error(error: Exception) -> str:
    lines = [line.strip() for line in str(error).splitlines() if line.strip()]
    if not lines:
        return "Неизвестная ошибка Spark или Ozone."
    for line in lines:
        if "Caused by:" in line:
            return line.split("Caused by:", 1)[1].strip()[:500]
    return lines[0][:500]


class OzoneSparkService:
    def __init__(self) -> None:
        self._lock = threading.RLock()
        self._spark = None
        self._ozone_client = None

    def start(self) -> None:
        with self._lock:
            if self._spark is not None:
                return
            from pyspark.sql import SparkSession

            self._spark = (
                SparkSession.builder.appName("Ozone Explorer")
                .config("spark.ui.enabled", "false")
                .config("spark.sql.session.timeZone", "UTC")
                .getOrCreate()
            )
            self._spark.sparkContext.setLogLevel(os.getenv("SPARK_LOG_LEVEL", "WARN"))

            jvm = self._spark._jvm
            conf = jvm.org.apache.hadoop.hdds.conf.OzoneConfiguration()
            conf.set("ozone.om.address", os.getenv("OZONE_OM_ADDRESS", "om:9862"))
            conf.set("ozone.replication", "1")
            conf.set("ozone.replication.type", "RATIS")
            self._ozone_client = (
                jvm.org.apache.hadoop.ozone.client.OzoneClientFactory.getRpcClient(conf)
            )

    @property
    def spark(self):
        self.start()
        return self._spark

    @property
    def store(self):
        self.start()
        return self._ozone_client.getObjectStore()

    def close(self) -> None:
        with self._lock:
            if self._ozone_client is not None:
                self._ozone_client.close()
                self._ozone_client = None
            if self._spark is not None:
                self._spark.stop()
                self._spark = None

    def list_namespace(self) -> dict[str, Any]:
        with self._lock:
            volumes: list[dict[str, Any]] = []
            iterator = self.store.listVolumes("")
            while iterator.hasNext():
                volume = iterator.next()
                buckets: list[dict[str, Any]] = []
                bucket_iterator = volume.listBuckets("")
                while bucket_iterator.hasNext():
                    bucket = bucket_iterator.next()
                    buckets.append(
                        {
                            "name": bucket.getName(),
                            "layout": str(bucket.getBucketLayout()),
                            "path": f"ofs://om/{volume.getName()}/{bucket.getName()}",
                        }
                    )
                volumes.append(
                    {
                        "name": volume.getName(),
                        "owner": volume.getOwner(),
                        "buckets": sorted(buckets, key=lambda item: item["name"]),
                    }
                )
            return {"volumes": sorted(volumes, key=lambda item: item["name"])}

    def create_volume(self, payload: dict[str, Any]) -> dict[str, Any]:
        name = validate_ozone_name(payload.get("name"), "Имя volume")
        with self._lock:
            self.store.createVolume(name)
        return {"name": name, "command": f"ozone sh volume create /{name}"}

    def create_bucket(self, payload: dict[str, Any]) -> dict[str, Any]:
        volume_name = validate_ozone_name(payload.get("volume"), "Имя volume")
        bucket_name = validate_ozone_name(payload.get("name"), "Имя bucket")
        layout = str(payload.get("layout") or "FILE_SYSTEM_OPTIMIZED").upper()
        if layout not in {"FILE_SYSTEM_OPTIMIZED", "OBJECT_STORE"}:
            raise ApiError("Выберите FSO или Object Store layout.")

        with self._lock:
            jvm = self.spark._jvm
            bucket_layout = jvm.org.apache.hadoop.ozone.om.helpers.BucketLayout.valueOf(
                layout
            )
            bucket_args = (
                jvm.org.apache.hadoop.ozone.client.BucketArgs.newBuilder()
                .setBucketLayout(bucket_layout)
                .build()
            )
            self.store.getVolume(volume_name).createBucket(bucket_name, bucket_args)
        layout_arg = "fso" if layout == "FILE_SYSTEM_OPTIMIZED" else "obs"
        return {
            "volume": volume_name,
            "name": bucket_name,
            "layout": layout,
            "path": f"ofs://om/{volume_name}/{bucket_name}",
            "command": (
                f"ozone sh bucket create /{volume_name}/{bucket_name} "
                f"--layout {layout_arg}"
            ),
        }

    def list_files(self, raw_path: Any) -> dict[str, Any]:
        path = normalize_ofs_path(raw_path)
        with self._lock:
            jvm = self.spark._jvm
            hadoop_path = jvm.org.apache.hadoop.fs.Path(path)
            file_system = hadoop_path.getFileSystem(
                self.spark.sparkContext._jsc.hadoopConfiguration()
            )
            if not file_system.exists(hadoop_path):
                raise ApiError("Путь не найден в Ozone.", HTTPStatus.NOT_FOUND)
            statuses = file_system.listStatus(hadoop_path)
            files = []
            for status in statuses:
                modified = datetime.fromtimestamp(
                    status.getModificationTime() / 1000, tz=timezone.utc
                ).isoformat()
                files.append(
                    {
                        "name": status.getPath().getName(),
                        "path": status.getPath().toString(),
                        "directory": bool(status.isDirectory()),
                        "size": int(status.getLen()),
                        "modified": modified,
                    }
                )
        files.sort(key=lambda item: (not item["directory"], item["name"].lower()))
        return {"path": path, "files": files}

    def preview(self, payload: dict[str, Any]) -> dict[str, Any]:
        path = normalize_ofs_path(payload.get("path"))
        data_format = infer_format(path, payload.get("format"))
        try:
            limit = int(payload.get("limit", 50))
        except (TypeError, ValueError) as error:
            raise ApiError("Лимит строк должен быть целым числом.") from error
        if not 1 <= limit <= 200:
            raise ApiError("Лимит строк должен быть от 1 до 200.")

        started = time.perf_counter()
        with self._lock:
            reader = self.spark.read.format(data_format)
            if data_format == "csv":
                reader = reader.option("header", "true").option("inferSchema", "true")
            dataframe = reader.load(path)
            schema = json.loads(dataframe.schema.json())
            raw_rows = dataframe.limit(limit + 1).toJSON().collect()
            rows = [json.loads(row) for row in raw_rows[:limit]]
            columns = list(dataframe.columns)
            tree = dataframe._jdf.schema().treeString()

        elapsed_ms = round((time.perf_counter() - started) * 1000)
        method = "parquet" if data_format == "parquet" else f'format("{data_format}").load'
        if data_format == "parquet":
            command = f'spark.read.parquet("{path}")'
        else:
            command = f'spark.read.format("{data_format}").load("{path}")'
        return {
            "path": path,
            "format": data_format,
            "columns": columns,
            "schema": schema.get("fields", []),
            "schemaTree": tree,
            "rows": rows,
            "truncated": len(raw_rows) > limit,
            "limit": limit,
            "elapsedMs": elapsed_ms,
            "command": command,
            "reader": method,
        }


SERVICE = OzoneSparkService()


class RequestHandler(BaseHTTPRequestHandler):
    server_version = "OzoneExplorer/1.0"

    def log_message(self, format_string: str, *args: Any) -> None:
        print(f"[ozone-ui] {self.address_string()} {format_string % args}", flush=True)

    def send_json(self, payload: Any, status: int = HTTPStatus.OK) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def read_json(self) -> dict[str, Any]:
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError as error:
            raise ApiError("Некорректный размер запроса.") from error
        if length <= 0 or length > MAX_BODY_BYTES:
            raise ApiError("Тело запроса пустое или слишком большое.")
        try:
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise ApiError("Ожидался корректный JSON.") from error
        if not isinstance(payload, dict):
            raise ApiError("JSON должен быть объектом.")
        return payload

    def handle_api_error(self, error: Exception) -> None:
        if isinstance(error, ApiError):
            self.send_json({"error": str(error)}, error.status)
            return
        print(f"[ozone-ui] API failure: {error}", flush=True)
        self.send_json(
            {"error": clean_error(error)}, HTTPStatus.INTERNAL_SERVER_ERROR
        )

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        try:
            if parsed.path == "/api/health":
                self.send_json({"status": "ok", "spark": SERVICE._spark is not None})
            elif parsed.path == "/api/namespace":
                self.send_json(SERVICE.list_namespace())
            elif parsed.path == "/api/files":
                query = parse_qs(parsed.query)
                self.send_json(SERVICE.list_files(query.get("path", [""])[0]))
            elif parsed.path.startswith("/api/"):
                raise ApiError("API-метод не найден.", HTTPStatus.NOT_FOUND)
            else:
                self.send_static(parsed.path)
        except Exception as error:  # noqa: BLE001 - API boundary
            self.handle_api_error(error)

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        try:
            payload = self.read_json()
            if parsed.path == "/api/volumes":
                self.send_json(SERVICE.create_volume(payload), HTTPStatus.CREATED)
            elif parsed.path == "/api/buckets":
                self.send_json(SERVICE.create_bucket(payload), HTTPStatus.CREATED)
            elif parsed.path == "/api/preview":
                self.send_json(SERVICE.preview(payload))
            else:
                raise ApiError("API-метод не найден.", HTTPStatus.NOT_FOUND)
        except Exception as error:  # noqa: BLE001 - API boundary
            self.handle_api_error(error)

    def send_static(self, request_path: str) -> None:
        relative = "index.html" if request_path in {"", "/"} else request_path.lstrip("/")
        candidate = (STATIC_ROOT / relative).resolve()
        if STATIC_ROOT not in candidate.parents and candidate != STATIC_ROOT:
            raise ApiError("Файл не найден.", HTTPStatus.NOT_FOUND)
        if not candidate.is_file():
            candidate = STATIC_ROOT / "index.html"
        body = candidate.read_bytes()
        content_type = mimetypes.guess_type(candidate.name)[0] or "application/octet-stream"
        if content_type.startswith("text/") or content_type == "application/javascript":
            content_type += "; charset=utf-8"
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-cache")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Security-Policy", "default-src 'self'; style-src 'self'; script-src 'self'; img-src 'self' data:; connect-src 'self'")
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    host = os.getenv("OZONE_UI_HOST", "0.0.0.0")
    port = int(os.getenv("OZONE_UI_PORT", "8090"))
    print("[ozone-ui] Starting Spark and Ozone clients", flush=True)
    SERVICE.start()
    server = ThreadingHTTPServer((host, port), RequestHandler)

    def shutdown(_signum=None, _frame=None) -> None:
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    print(f"[ozone-ui] Ready on http://{host}:{port}", flush=True)
    try:
        server.serve_forever(poll_interval=0.5)
    finally:
        server.server_close()
        SERVICE.close()


if __name__ == "__main__":
    main()
