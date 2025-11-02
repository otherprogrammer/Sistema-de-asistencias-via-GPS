"""
Unit tests for the AttendanceExtractor and Biometric Privacy Filter.
"""

from pathlib import Path
from integrations.sap_hr.extractor import AttendanceExtractor
from integrations.sap_hr.cli import create_sample_seed_file


def test_extractor_sanitizes_and_excludes_biometrics(tmp_path):
    seed_file = tmp_path / "seed_test.json"
    create_sample_seed_file(seed_file)

    extractor = AttendanceExtractor()
    records = extractor.extract_all(mock_file_path=seed_file)

    assert len(records) > 0

    for rec in records:
        # Verify no biometric fields are present in the record attributes
        assert not hasattr(rec, "faceEmbedding")
        assert not hasattr(rec, "face_embedding")
        assert not hasattr(rec, "faceImageUrl")
        assert not hasattr(rec, "face_image_url")

        # Worker data is denormalized correctly
        assert rec.worker_id != ""
        assert rec.worksite_id != ""
        assert rec.shift_date is not None


def test_extractor_date_filters(tmp_path):
    from datetime import date
    seed_file = tmp_path / "seed_test.json"
    create_sample_seed_file(seed_file)

    extractor = AttendanceExtractor()
    # Filter for single day 2025-10-21
    records_filtered = extractor.extract_all(
        start_date=date(2025, 10, 21),
        end_date=date(2025, 10, 21),
        mock_file_path=seed_file,
    )

    for rec in records_filtered:
        assert rec.shift_date == date(2025, 10, 21)
