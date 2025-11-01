"""
CSV Exporter formatted for SAP SuccessFactors Data Workbench and SAP HCM Batch Input.
"""

import csv
from pathlib import Path
from typing import List

from ..config import settings
from ..models import NormalizedAttendance


def export_to_csv(
    records: List[NormalizedAttendance],
    output_path: Path,
    delimiter: str = ",",
) -> Path:
    """
    Export normalized attendance records into CSV format compliant with SAP external time upload specs.
    """
    output_path.parent.mkdir(parents=True, exist_ok=True)

    headers = [
        "EXTERNAL_CODE",
        "SAP_USER_ID",
        "NATIONAL_ID_DNI",
        "EMPLOYEE_NAME",
        "START_DATE",
        "START_TIME",
        "END_DATE",
        "END_TIME",
        "TIME_TYPE",
        "HOURS",
        "COST_CENTER",
        "WORKSITE_NAME",
        "PUNCH_IN_LAT",
        "PUNCH_IN_LON",
        "PUNCH_OUT_LAT",
        "PUNCH_OUT_LON",
        "BIOMETRIC_VERIFIED",
        "ATTENDANCE_STATUS",
    ]

    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, delimiter=delimiter)
        writer.writerow(headers)

        for r in records:
            ext_code = f"ATT_{r.record_id}"
            user_id = r.worker_dni or r.worker_id

            start_date_str = r.shift_date.strftime("%Y-%m-%d")
            start_time_str = r.punch_in.timestamp.strftime("%H:%M:%S") if r.punch_in else ""

            if r.punch_out:
                end_date_str = r.punch_out.timestamp.strftime("%Y-%m-%d")
                end_time_str = r.punch_out.timestamp.strftime("%H:%M:%S")
                out_lat = f"{r.punch_out.latitude:.6f}"
                out_lon = f"{r.punch_out.longitude:.6f}"
            else:
                end_date_str = start_date_str
                end_time_str = ""
                out_lat = ""
                out_lon = ""

            in_lat = f"{r.punch_in.latitude:.6f}" if r.punch_in else ""
            in_lon = f"{r.punch_in.longitude:.6f}" if r.punch_in else ""

            hours = r.calculate_hours()
            hours_str = f"{hours:.2f}" if hours is not None else ""

            writer.writerow([
                ext_code,
                user_id,
                r.worker_dni or "",
                r.worker_name,
                start_date_str,
                start_time_str,
                end_date_str,
                end_time_str,
                settings.sap.time_type_regular,
                hours_str,
                r.worksite_id,
                r.worksite_name,
                in_lat,
                in_lon,
                out_lat,
                out_lon,
                "TRUE" if r.biometric_verified else "FALSE",
                r.status.value,
            ])

    return output_path
