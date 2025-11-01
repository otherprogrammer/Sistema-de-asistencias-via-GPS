"""
Configuration module for SAP HR integration.
Loads settings from environment variables and .env file.
"""

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional
from dotenv import load_dotenv

# Base directory for the integration package
PACKAGE_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = PACKAGE_DIR.parent.parent

# Load .env file from integration folder first, then project root
load_dotenv(PACKAGE_DIR / ".env")
load_dotenv(PROJECT_ROOT / ".env")


@dataclass(frozen=True)
class FirebaseConfig:
    """Firebase Connection Configuration"""
    project_id: str = os.getenv("FIREBASE_PROJECT_ID", "flutter-gps-attendance")
    credentials_path: Optional[str] = os.getenv("FIREBASE_CREDENTIALS_PATH")
    use_rest_api: bool = os.getenv("FIREBASE_USE_REST_API", "true").lower() in ("true", "1", "yes")
    api_key: Optional[str] = os.getenv("FIREBASE_API_KEY")
    database_id: str = os.getenv("FIREBASE_DATABASE_ID", "(default)")
    attendances_collection: str = os.getenv("FIREBASE_ATTENDANCES_COLLECTION", "attendances")
    users_collection: str = os.getenv("FIREBASE_USERS_COLLECTION", "users")
    worksites_collection: str = os.getenv("FIREBASE_WORKSITES_COLLECTION", "worksites")


@dataclass(frozen=True)
class SAPConfig:
    """SAP SuccessFactors / SAP HCM Configuration"""
    base_url: str = os.getenv("SAP_BASE_URL", "https://api-preview.successfactors.com")
    company_id: str = os.getenv("SAP_COMPANY_ID", "SAPCUST01")
    client_id: str = os.getenv("SAP_CLIENT_ID", "sf_integration_client")
    client_secret: str = os.getenv("SAP_CLIENT_SECRET", "")
    token_url: str = os.getenv("SAP_TOKEN_URL", "https://api-preview.successfactors.com/oauth/token")
    username: Optional[str] = os.getenv("SAP_USERNAME")
    password: Optional[str] = os.getenv("SAP_PASSWORD")
    time_type_regular: str = os.getenv("SAP_TIME_TYPE_REGULAR", "REGULAR_WORK")
    time_type_overtime: str = os.getenv("SAP_TIME_TYPE_OVERTIME", "OVERTIME_WORK")
    default_cost_center: str = os.getenv("SAP_DEFAULT_COST_CENTER", "CC_CONSTRUCTION_01")
    dry_run: bool = os.getenv("SAP_DRY_RUN", "true").lower() in ("true", "1", "yes")
    batch_size: int = int(os.getenv("SAP_BATCH_SIZE", "50"))
    timeout_seconds: int = int(os.getenv("SAP_TIMEOUT_SECONDS", "30"))


@dataclass(frozen=True)
class ValidationConfig:
    """Attendance validation rules"""
    max_shift_hours: float = float(os.getenv("VAL_MAX_SHIFT_HOURS", "16.0"))
    min_shift_hours: float = float(os.getenv("VAL_MIN_SHIFT_HOURS", "0.25"))
    duplicate_window_minutes: int = int(os.getenv("VAL_DUPLICATE_WINDOW_MINUTES", "5"))
    require_valid_geofence: bool = os.getenv("VAL_REQUIRE_VALID_GEOFENCE", "false").lower() in ("true", "1", "yes")
    timezone: str = os.getenv("VAL_TIMEZONE", "America/Lima")


@dataclass(frozen=True)
class ExportConfig:
    """Export and reporting settings"""
    output_dir: Path = field(default_factory=lambda: Path(os.getenv("EXPORT_OUTPUT_DIR", str(PACKAGE_DIR / "exports"))))
    csv_delimiter: str = os.getenv("EXPORT_CSV_DELIMITER", ",")
    include_raw_metadata: bool = os.getenv("EXPORT_INCLUDE_METADATA", "false").lower() in ("true", "1", "yes")


@dataclass(frozen=True)
class Settings:
    """Global Integration Settings"""
    firebase: FirebaseConfig = field(default_factory=FirebaseConfig)
    sap: SAPConfig = field(default_factory=SAPConfig)
    validation: ValidationConfig = field(default_factory=ValidationConfig)
    export: ExportConfig = field(default_factory=ExportConfig)


settings = Settings()
