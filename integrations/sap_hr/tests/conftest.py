"""
Pytest fixtures for SAP HR integration testing.
"""

from datetime import datetime, date
import pytest

from integrations.sap_hr.models import (
    NormalizedAttendance,
    PunchDetail,
    AttendanceStatus,
)


@pytest.fixture
def sample_valid_attendance():
    """A standard valid normalized attendance record"""
    return NormalizedAttendance(
        record_id="test_rec_001",
        worker_id="uid_worker_100",
        worker_dni="70891234",
        worker_name="Juan Perez Gomez",
        worksite_id="site_alpha",
        worksite_name="Torre Empresarial",
        shift_date=date(2025, 10, 20),
        punch_in=PunchDetail(
            timestamp=datetime(2025, 10, 20, 8, 0, 0),
            latitude=-12.1215,
            longitude=-77.0289,
            is_valid_location=True,
        ),
        punch_out=PunchDetail(
            timestamp=datetime(2025, 10, 20, 17, 0, 0),
            latitude=-12.1216,
            longitude=-77.0288,
            is_valid_location=True,
        ),
        worked_hours=9.0,
        status=AttendanceStatus.PRESENTE,
        biometric_verified=True,
    )


@pytest.fixture
def sample_duplicate_attendance():
    """A duplicate attendance punch 2 minutes later for the same worker"""
    return NormalizedAttendance(
        record_id="test_rec_002_dup",
        worker_id="uid_worker_100",
        worker_dni="70891234",
        worker_name="Juan Perez Gomez",
        worksite_id="site_alpha",
        worksite_name="Torre Empresarial",
        shift_date=date(2025, 10, 20),
        punch_in=PunchDetail(
            timestamp=datetime(2025, 10, 20, 8, 2, 0),
            latitude=-12.1215,
            longitude=-77.0289,
            is_valid_location=True,
        ),
        punch_out=PunchDetail(
            timestamp=datetime(2025, 10, 20, 17, 0, 0),
            latitude=-12.1216,
            longitude=-77.0288,
            is_valid_location=True,
        ),
        worked_hours=8.96,
        status=AttendanceStatus.PRESENTE,
        biometric_verified=True,
    )
