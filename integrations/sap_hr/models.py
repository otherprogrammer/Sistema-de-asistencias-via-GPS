"""
Domain models for attendance data normalization and SAP HR payload mapping.
"""

from dataclasses import dataclass, field
from datetime import datetime, date, time
from enum import Enum
from typing import Optional, List, Dict, Any


class AttendanceStatus(str, Enum):
    PRESENTE = "Presente"
    INCOMPLETO = "Incompleto"
    AUSENTE = "Ausente"
    TARDE = "Tarde"
    INTENTO_FALLIDO = "Intento Fallido"


class ValidationCode(str, Enum):
    VALID = "VALID"
    DUPLICATE = "DUPLICATE"
    MISSING_PUNCH_IN = "MISSING_PUNCH_IN"
    MISSING_PUNCH_OUT = "MISSING_PUNCH_OUT"
    INVALID_HOURS = "INVALID_HOURS"
    INVALID_COORDINATES = "INVALID_COORDINATES"
    GEOFENCE_VIOLATION = "GEOFENCE_VIOLATION"
    MISSING_WORKER_DNI = "MISSING_WORKER_DNI"


@dataclass
class PunchDetail:
    """Represents a single clock-in or clock-out punch"""
    timestamp: datetime
    latitude: float
    longitude: float
    is_valid_location: bool

    def to_dict(self) -> Dict[str, Any]:
        return {
            "timestamp": self.timestamp.isoformat(),
            "latitude": self.latitude,
            "longitude": self.longitude,
            "is_valid_location": self.is_valid_location,
        }


@dataclass
class NormalizedAttendance:
    """
    Sanitized and normalized attendance record ready for ERP integration.
    Notice: Excludes any biometric vectors or facial images.
    """
    record_id: str
    worker_id: str
    worker_dni: Optional[str]
    worker_name: str
    worksite_id: str
    worksite_name: str
    shift_date: date
    punch_in: Optional[PunchDetail] = None
    punch_out: Optional[PunchDetail] = None
    worked_hours: Optional[float] = None
    status: AttendanceStatus = AttendanceStatus.PRESENTE
    biometric_verified: bool = True  # Flag confirming facial authentication occurred locally

    def calculate_hours(self) -> Optional[float]:
        """Calculate worked hours between punch_in and punch_out if available"""
        if self.punch_in and self.punch_out:
            delta = self.punch_out.timestamp - self.punch_in.timestamp
            return round(max(0.0, delta.total_seconds() / 3600.0), 2)
        return self.worked_hours


@dataclass
class ValidationResult:
    """Validation outcome for an individual attendance record"""
    record_id: str
    is_valid: bool
    code: ValidationCode
    message: str
    normalized_record: Optional[NormalizedAttendance] = None


@dataclass
class SAPExternalTimeDataPayload:
    """
    Standard SAP SuccessFactors Time Tracking OData v2 entity: ExternalTimeData
    Official API spec reference:
    https://help.sap.com/docs/SAP_SUCCESSFACTORS_EMPLOYEE_CENTRAL/time-tracking/externaltimedata
    """
    external_code: str
    user_id: str  # SAP personIdExternal / userId
    start_date: str  # Format: YYYY-MM-DD
    start_time: str  # Format: PT08H30M00S or HH:mm:ss
    end_date: str  # Format: YYYY-MM-DD
    end_time: str  # Format: PT17H30M00S or HH:mm:ss
    time_type: str  # e.g., REGULAR_WORK
    hours: Optional[float] = None
    cost_center: Optional[str] = None
    status: str = "PENDING"
    # Metadata for SAP audit trail
    source: str = "MOBILE_GPS_FACIAL"
    comment: Optional[str] = None

    def to_odata_dict(self) -> Dict[str, Any]:
        """Convert to standard OData v2 JSON payload for SuccessFactors"""
        data: Dict[str, Any] = {
            "__metadata": {
                "uri": "ExternalTimeData",
                "type": "SFOData.ExternalTimeData"
            },
            "externalCode": self.external_code,
            "userId": self.user_id,
            "startDate": f"/Date({int(datetime.strptime(self.start_date, '%Y-%m-%d').timestamp() * 1000)})/",
            "startTime": self.start_time,
            "endDate": f"/Date({int(datetime.strptime(self.end_date, '%Y-%m-%d').timestamp() * 1000)})/",
            "endTime": self.end_time,
            "timeType": self.time_type,
            "status": "APPROVED",
        }
        if self.hours is not None:
            data["hours"] = self.hours
        if self.cost_center:
            data["costCenter"] = self.cost_center
        if self.comment:
            data["comment"] = self.comment
        return data


@dataclass
class ProcessingReport:
    """Summary report of the integration process"""
    start_time: datetime = field(default_factory=datetime.now)
    end_time: Optional[datetime] = None
    total_extracted: int = 0
    total_valid: int = 0
    total_rejected: int = 0
    total_duplicates: int = 0
    total_exported: int = 0
    sap_transferred: int = 0
    sap_simulated: int = 0
    sap_errors: int = 0
    validation_issues: List[Dict[str, Any]] = field(default_factory=list)
    sap_responses: List[Dict[str, Any]] = field(default_factory=list)

    def finish(self) -> None:
        self.end_time = datetime.now()

    @property
    def duration_seconds(self) -> float:
        if self.end_time:
            return round((self.end_time - self.start_time).total_seconds(), 2)
        return 0.0

    def to_dict(self) -> Dict[str, Any]:
        return {
            "execution": {
                "started_at": self.start_time.isoformat(),
                "finished_at": self.end_time.isoformat() if self.end_time else None,
                "duration_seconds": self.duration_seconds,
            },
            "metrics": {
                "total_extracted": self.total_extracted,
                "total_valid": self.total_valid,
                "total_rejected": self.total_rejected,
                "total_duplicates": self.total_duplicates,
                "total_exported": self.total_exported,
                "sap_transferred": self.sap_transferred,
                "sap_simulated": self.sap_simulated,
                "sap_errors": self.sap_errors,
            },
            "issues": self.validation_issues[:50],  # Cap issues preview to first 50
        }
