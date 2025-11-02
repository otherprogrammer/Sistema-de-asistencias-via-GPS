"""
Orchestration service for the attendance integration pipeline.
Coordinates: Extraction -> Validation & Deduplication -> File Export -> SAP HR Transfer.
"""

import logging
from datetime import date
from pathlib import Path
from typing import Optional, Dict, Any, List

from .config import settings
from .extractor import AttendanceExtractor
from .validator import AttendanceValidator
from .exporters import export_to_json, export_to_csv
from .adapters.base import SAPHRAdapterBase
from .adapters.successfactors import SuccessFactorsTimeTrackingAdapter
from .models import ProcessingReport, NormalizedAttendance

logger = logging.getLogger(__name__)


class AttendanceSyncService:
    """
    Main service coordinating extraction, normalization, deduplication,
    exportation, and transmission of attendance data to SAP HR.
    """

    def __init__(
        self,
        adapter: Optional[SAPHRAdapterBase] = None,
        extractor: Optional[AttendanceExtractor] = None,
        validator: Optional[AttendanceValidator] = None,
    ):
        self.extractor = extractor or AttendanceExtractor()
        self.validator = validator or AttendanceValidator()
        self.adapter = adapter or SuccessFactorsTimeTrackingAdapter()

    def run_sync(
        self,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        worker_id: Optional[str] = None,
        mock_file_path: Optional[Path] = None,
        export_csv_path: Optional[Path] = None,
        export_json_path: Optional[Path] = None,
        transfer_to_sap: bool = True,
    ) -> ProcessingReport:
        """
        Execute the full synchronization workflow.
        """
        logger.info("=== Starting SAP HR Attendance Synchronization ===")

        # 1. Extraction from Firebase or seed file
        extracted = self.extractor.extract_all(
            start_date=start_date,
            end_date=end_date,
            worker_id=worker_id,
            mock_file_path=mock_file_path,
        )
        logger.info("Extraction stage finished: %d raw records", len(extracted))

        # 2. Validation and Deduplication
        valid_records, report = self.validator.validate_batch(extracted)
        logger.info(
            "Validation stage finished: %d valid, %d rejected (%d duplicates)",
            report.total_valid,
            report.total_rejected,
            report.total_duplicates,
        )

        # 3. File Exports (CSV)
        out_dir = settings.export.output_dir
        out_dir.mkdir(parents=True, exist_ok=True)

        if not export_csv_path:
            export_csv_path = out_dir / f"sap_attendance_{date.today().isoformat()}.csv"
        if not export_json_path:
            export_json_path = out_dir / f"sap_attendance_{date.today().isoformat()}.json"

        export_to_csv(valid_records, export_csv_path, delimiter=settings.export.csv_delimiter)
        report.total_exported = len(valid_records)
        logger.info("Generated CSV export at: %s", export_csv_path)

        # 4. Transmission / Simulation to SAP HR
        if transfer_to_sap and valid_records:
            logger.info("Initiating transfer to SAP HR (Mode: %s)...", "SIMULATION" if settings.sap.dry_run else "LIVE")
            self.adapter.authenticate()

            results = self.adapter.send_batch(valid_records)
            for res in results:
                if res.get("simulated"):
                    report.sap_simulated += 1
                elif res.get("success"):
                    report.sap_transferred += 1
                else:
                    report.sap_errors += 1

                report.sap_responses.append(res)

        report.finish()

        # Write final JSON audit trail with complete transfer metrics
        export_to_json(valid_records, export_json_path, report=report)
        logger.info("Generated JSON audit log at: %s", export_json_path)

        logger.info("=== Synchronization completed in %.2fs ===", report.duration_seconds)
        return report
