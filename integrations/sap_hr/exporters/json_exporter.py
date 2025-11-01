"""
JSON Exporter for normalized attendance records and audit reports.
"""

import json
from datetime import datetime, date
from pathlib import Path
from typing import List, Dict, Any, Optional

from ..models import NormalizedAttendance, ProcessingReport


def _json_serial_helper(obj: Any) -> Any:
    """Helper to serialize dates and datetimes to ISO 8601 strings"""
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    raise TypeError(f"Type {type(obj)} not serializable")


def export_to_json(
    records: List[NormalizedAttendance],
    output_path: Path,
    report: Optional[ProcessingReport] = None,
) -> Path:
    """
    Export normalized attendance records along with validation report to JSON.
    """
    output_path.parent.mkdir(parents=True, exist_ok=True)

    data: Dict[str, Any] = {
        "metadata": {
            "source_system": "Flutter GPS & Facial Attendance",
            "target_system": "SAP HR / SuccessFactors Time Tracking",
            "exported_at": datetime.now().isoformat(),
            "records_count": len(records),
            "biometric_templates_included": False,
        },
        "report": report.to_dict() if report else None,
        "records": [
            {
                "record_id": r.record_id,
                "worker_id": r.worker_id,
                "worker_dni": r.worker_dni,
                "worker_name": r.worker_name,
                "worksite_id": r.worksite_id,
                "worksite_name": r.worksite_name,
                "shift_date": r.shift_date.isoformat(),
                "punch_in": r.punch_in.to_dict() if r.punch_in else None,
                "punch_out": r.punch_out.to_dict() if r.punch_out else None,
                "worked_hours": r.calculate_hours(),
                "status": r.status.value,
                "biometric_verified": r.biometric_verified,
            }
            for r in records
        ],
    }

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, default=_json_serial_helper, ensure_ascii=False)

    return output_path
