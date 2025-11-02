"""
Unit tests for CSV and JSON exporters.
"""

import csv
import json
from integrations.sap_hr.exporters import export_to_csv, export_to_json


def test_export_to_csv(sample_valid_attendance, tmp_path):
    csv_file = tmp_path / "test_export.csv"
    export_to_csv([sample_valid_attendance], csv_file)

    assert csv_file.exists()

    with open(csv_file, "r", encoding="utf-8") as f:
        reader = list(csv.reader(f))
        assert len(reader) == 2  # Header + 1 row
        header = reader[0]
        row = reader[1]

        assert "EXTERNAL_CODE" in header
        assert "SAP_USER_ID" in header
        assert "BIOMETRIC_VERIFIED" in header

        assert row[0] == f"ATT_{sample_valid_attendance.record_id}"
        assert row[1] == sample_valid_attendance.worker_dni
        assert row[2] == sample_valid_attendance.worker_dni
        assert row[16] == "TRUE"  # Biometric verified flag


def test_export_to_json(sample_valid_attendance, tmp_path):
    json_file = tmp_path / "test_export.json"
    export_to_json([sample_valid_attendance], json_file)

    assert json_file.exists()

    with open(json_file, "r", encoding="utf-8") as f:
        data = json.load(f)

        assert "metadata" in data
        assert data["metadata"]["biometric_templates_included"] is False
        assert len(data["records"]) == 1
        rec = data["records"][0]
        assert rec["record_id"] == sample_valid_attendance.record_id
        assert rec["worker_dni"] == sample_valid_attendance.worker_dni
        assert rec["biometric_verified"] is True
