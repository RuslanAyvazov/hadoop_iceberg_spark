import importlib.util
import pathlib
import unittest


SERVER_PATH = pathlib.Path(__file__).parents[1] / "ui" / "server.py"
SPEC = importlib.util.spec_from_file_location("ozone_ui_server", SERVER_PATH)
SERVER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SERVER)


class ValidationTests(unittest.TestCase):
    def test_accepts_valid_ozone_name(self):
        self.assertEqual(SERVER.validate_ozone_name("raw-data", "Bucket"), "raw-data")
        self.assertEqual(SERVER.validate_ozone_name("UPPER", "Bucket"), "upper")

    def test_rejects_short_or_unsafe_name(self):
        for value in ("ab", "raw_data", "-bucket"):
            with self.subTest(value=value), self.assertRaises(SERVER.ApiError):
                SERVER.validate_ozone_name(value, "Bucket")

    def test_normalizes_valid_ofs_path(self):
        self.assertEqual(
            SERVER.normalize_ofs_path("ofs://om/spark/data/folder"),
            "ofs://om/spark/data/folder",
        )

    def test_rejects_non_ozone_or_parent_path(self):
        for value in ("s3a://bucket/data", "ofs://om/volume", "ofs://om/v/b/../secret"):
            with self.subTest(value=value), self.assertRaises(SERVER.ApiError):
                SERVER.normalize_ofs_path(value)

    def test_infers_supported_formats(self):
        self.assertEqual(SERVER.infer_format("ofs://om/v/b/file.csv"), "csv")
        self.assertEqual(SERVER.infer_format("ofs://om/v/b/file.jsonl"), "json")
        self.assertEqual(SERVER.infer_format("ofs://om/v/b/table"), "parquet")
        self.assertEqual(SERVER.infer_format("ofs://om/v/b/table", "json"), "json")


if __name__ == "__main__":
    unittest.main()
