import json
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
NOTEBOOK = ROOT / "notebooks" / "01_spark_scala_ozone.ipynb"


class ScalaOzoneNotebookTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.notebook = json.loads(NOTEBOOK.read_text(encoding="utf-8"))

    def test_uses_toree_scala_kernel(self):
        kernelspec = self.notebook["metadata"]["kernelspec"]
        self.assertEqual(kernelspec["name"], "apache_toree_scala")
        self.assertEqual(kernelspec["language"], "scala")

    def test_every_cell_has_stable_id(self):
        self.assertTrue(all(cell.get("id") for cell in self.notebook["cells"]))

    def test_contains_real_ozone_dataframe_roundtrip(self):
        source = "\n".join(
            "".join(cell.get("source", [])) for cell in self.notebook["cells"]
        )
        self.assertIn("ofs://om/spark/data/notebook-users-scala", source)
        self.assertIn('.write.mode("overwrite").parquet(ozonePath)', source)
        self.assertIn("read.parquet(ozonePath)", source)
        self.assertIn("SCALA_OZONE_OK rows=3", source)


if __name__ == "__main__":
    unittest.main()
