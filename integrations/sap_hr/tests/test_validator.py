"""
Unit tests for the AttendanceValidator and Deduplication engine.
"""

from datetime import datetime, date
from integrations.sap_hr.validator import AttendanceValidator
from integrations.sap_hr.models import (
    NormalizedAttendance,
    PunchDetail,
    ValidationCode,
    AttendanceStatus,
)


def test_validator_accepts_valid_record(sample_valid_attendance):
    validator = AttendanceValidator()
    result = validator.validate_record(sample_valid_attendance)

    assert result.is_valid is True
    assert result.code == ValidationCode.VALID


def test_validator_detects_duplicate_document_id(sample_valid_attendance):
    validator = AttendanceValidator()
    # First validation succeeds
    res1 = validator.validate_record(sample_valid_attendance)
    assert res1.is_valid is True

    # Same document ID rejected as duplicate
    res2 = validator.validate_record(sample_valid_attendance)
    assert res2.is_valid is False
    assert res2.code == ValidationCode.DUPLICATE


def test_validator_detects_timestamp_window_duplicate(sample_valid_attendance, sample_duplicate_attendance):
    validator = AttendanceValidator()
    res1 = validator.validate_record(sample_valid_attendance)
    assert res1.is_valid is True

    # 2 minutes later within 5-min window should be flagged as DUPLICATE
    res2 = validator.validate_record(sample_duplicate_attendance)
    assert res2.is_valid is False
    assert res2.code == ValidationCode.DUPLICATE


def test_validator_rejects_missing_dni(sample_valid_attendance):
    validator = AttendanceValidator()
    sample_valid_attendance.worker_dni = None

    result = validator.validate_record(sample_valid_attendance)
    assert result.is_valid is False
    assert result.code == ValidationCode.MISSING_WORKER_DNI


def test_validator_rejects_missing_punch_in(sample_valid_attendance):
    validator = AttendanceValidator()
    sample_valid_attendance.punch_in = None

    result = validator.validate_record(sample_valid_attendance)
    assert result.is_valid is False
    assert result.code == ValidationCode.MISSING_PUNCH_IN


def test_validator_rejects_invalid_coordinates(sample_valid_attendance):
    validator = AttendanceValidator()
    sample_valid_attendance.punch_in = PunchDetail(
        timestamp=datetime(2025, 10, 20, 8, 0, 0),
        latitude=0.0,
        longitude=0.0,
        is_valid_location=False,
    )

    result = validator.validate_record(sample_valid_attendance)
    assert result.is_valid is False
    assert result.code == ValidationCode.INVALID_COORDINATES


def test_validator_rejects_punch_out_earlier_than_in(sample_valid_attendance):
    validator = AttendanceValidator()
    # Punch out earlier than punch in
    sample_valid_attendance.punch_out = PunchDetail(
        timestamp=datetime(2025, 10, 20, 7, 0, 0),
        latitude=-12.1216,
        longitude=-77.0288,
        is_valid_location=True,
    )

    result = validator.validate_record(sample_valid_attendance)
    assert result.is_valid is False
    assert result.code == ValidationCode.INVALID_HOURS
