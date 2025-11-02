"""
Command-Line Interface for the SAP HR Attendance Integration Module.
"""

import argparse
import json
import logging
import sys
from datetime import datetime
from pathlib import Path

from .config import settings, PACKAGE_DIR
from .sync_service import AttendanceSyncService
from .adapters.successfactors import SuccessFactorsTimeTrackingAdapter


def setup_logging(verbose: bool = False) -> None:
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )


def create_sample_seed_file(dest_path: Path) -> Path:
    """
    Creates a realistic historical dataset matching the project's Firestore schema.
    Used for simulation, demonstration, and offline automated testing.
    """
    sample_data = {
        "users": [
            {
                "uid": "worker_user_001",
                "role": "trabajador",
                "dni": "72491023",
                "fullName": "Carlos Mendoza Rivera",
                "assignedWorksiteId": "worksite_miraflores_01",
                "isActive": True,
                "faceRegistered": True,
                # Note: biometric vectors and photos are kept in Firebase and NEVER exported
            },
            {
                "uid": "worker_user_002",
                "role": "trabajador",
                "dni": "45892011",
                "fullName": "Jorge Luis Quispe",
                "assignedWorksiteId": "worksite_miraflores_01",
                "isActive": True,
                "faceRegistered": True,
            },
            {
                "uid": "worker_user_003",
                "role": "trabajador",
                "dni": "10482904",
                "fullName": "Pedro Gomez Sanchez",
                "assignedWorksiteId": "worksite_san_isidro_02",
                "isActive": True,
                "faceRegistered": True,
            },
            {
                "uid": "worker_user_004_nodni",
                "role": "trabajador",
                "dni": None,  # Will test missing DNI validation
                "fullName": "Trabajador Sin DNI",
                "assignedWorksiteId": "worksite_miraflores_01",
                "isActive": True,
            },
        ],
        "worksites": [
            {
                "id": "worksite_miraflores_01",
                "name": "Edificio Residencial Parque Alto",
                "latitude": -12.121500,
                "longitude": -77.028900,
                "radius": 120.0,
            },
            {
                "id": "worksite_san_isidro_02",
                "name": "Centro Empresarial Las Camelias",
                "latitude": -12.095400,
                "longitude": -77.032100,
                "radius": 150.0,
            },
        ],
        "attendances": [
            # 1. Valid complete shift (Worker 1 - Day 1)
            {
                "id": "att_20251020_001",
                "workerId": "worker_user_001",
                "worksiteId": "worksite_miraflores_01",
                "date": "2025-10-20T00:00:00Z",
                "punchIn": {
                    "timestamp": "2025-10-20T08:02:15Z",
                    "location": {"latitude": -12.121480, "longitude": -77.028890},
                    "isValid": True,
                },
                "punchOut": {
                    "timestamp": "2025-10-20T17:31:40Z",
                    "location": {"latitude": -12.121510, "longitude": -77.028910},
                    "isValid": True,
                },
                "status": "Presente",
                "workedHours": 9.49,
            },
            # 2. Duplicate record (same worker, identical timestamp window) -> should be flagged as DUPLICATE
            {
                "id": "att_20251020_001_dup",
                "workerId": "worker_user_001",
                "worksiteId": "worksite_miraflores_01",
                "date": "2025-10-20T00:00:00Z",
                "punchIn": {
                    "timestamp": "2025-10-20T08:02:40Z",
                    "location": {"latitude": -12.121480, "longitude": -77.028890},
                    "isValid": True,
                },
                "punchOut": {
                    "timestamp": "2025-10-20T17:31:40Z",
                    "location": {"latitude": -12.121510, "longitude": -77.028910},
                    "isValid": True,
                },
                "status": "Presente",
                "workedHours": 9.49,
            },
            # 3. Valid shift with slight overtime (Worker 2 - Day 1)
            {
                "id": "att_20251020_002",
                "workerId": "worker_user_002",
                "worksiteId": "worksite_miraflores_01",
                "date": "2025-10-20T00:00:00Z",
                "punchIn": {
                    "timestamp": "2025-10-20T07:55:10Z",
                    "location": {"latitude": -12.121520, "longitude": -77.028880},
                    "isValid": True,
                },
                "punchOut": {
                    "timestamp": "2025-10-20T18:05:00Z",
                    "location": {"latitude": -12.121530, "longitude": -77.028900},
                    "isValid": True,
                },
                "status": "Presente",
                "workedHours": 10.16,
            },
            # 4. Valid shift at another worksite (Worker 3 - Day 1)
            {
                "id": "att_20251020_003",
                "workerId": "worker_user_003",
                "worksiteId": "worksite_san_isidro_02",
                "date": "2025-10-20T00:00:00Z",
                "punchIn": {
                    "timestamp": "2025-10-20T08:10:00Z",
                    "location": {"latitude": -12.095410, "longitude": -77.032090},
                    "isValid": True,
                },
                "punchOut": {
                    "timestamp": "2025-10-20T17:00:00Z",
                    "location": {"latitude": -12.095400, "longitude": -77.032110},
                    "isValid": True,
                },
                "status": "Presente",
                "workedHours": 8.83,
            },
            # 5. Invalid Record: Missing DNI (Worker 4)
            {
                "id": "att_20251020_004",
                "workerId": "worker_user_004_nodni",
                "worksiteId": "worksite_miraflores_01",
                "date": "2025-10-20T00:00:00Z",
                "punchIn": {
                    "timestamp": "2025-10-20T08:30:00Z",
                    "location": {"latitude": -12.121500, "longitude": -77.028900},
                    "isValid": True,
                },
                "punchOut": {
                    "timestamp": "2025-10-20T17:30:00Z",
                    "location": {"latitude": -12.121500, "longitude": -77.028900},
                    "isValid": True,
                },
                "status": "Presente",
            },
            # 6. Invalid Record: Invalid GPS coordinates (0.0, 0.0)
            {
                "id": "att_20251020_005_bad_gps",
                "workerId": "worker_user_002",
                "worksiteId": "worksite_miraflores_01",
                "date": "2025-10-21T00:00:00Z",
                "punchIn": {
                    "timestamp": "2025-10-21T08:00:00Z",
                    "location": {"latitude": 0.0, "longitude": 0.0},
                    "isValid": False,
                },
                "punchOut": {
                    "timestamp": "2025-10-21T17:00:00Z",
                    "location": {"latitude": 0.0, "longitude": 0.0},
                    "isValid": False,
                },
                "status": "Presente",
            },
            # 7. Valid Day 2 Shift (Worker 1)
            {
                "id": "att_20251021_001",
                "workerId": "worker_user_001",
                "worksiteId": "worksite_miraflores_01",
                "date": "2025-10-21T00:00:00Z",
                "punchIn": {
                    "timestamp": "2025-10-21T08:05:00Z",
                    "location": {"latitude": -12.121490, "longitude": -77.028895},
                    "isValid": True,
                },
                "punchOut": {
                    "timestamp": "2025-10-21T17:25:00Z",
                    "location": {"latitude": -12.121515, "longitude": -77.028905},
                    "isValid": True,
                },
                "status": "Presente",
                "workedHours": 9.33,
            },
        ],
    }

    dest_path.parent.mkdir(parents=True, exist_ok=True)
    with open(dest_path, "w", encoding="utf-8") as f:
        json.dump(sample_data, f, indent=2, ensure_ascii=False)

    return dest_path


def main() -> None:
    parser = argparse.ArgumentParser(
        description="SAP HR / SuccessFactors Attendance Integration CLI"
    )
    parser.add_argument(
        "--start-date",
        type=str,
        help="Start date filter (YYYY-MM-DD)",
    )
    parser.add_argument(
        "--end-date",
        type=str,
        help="End date filter (YYYY-MM-DD)",
    )
    parser.add_argument(
        "--worker-id",
        type=str,
        help="Filter extraction by specific Worker ID",
    )
    parser.add_argument(
        "--mock-data",
        type=str,
        help="Path to JSON seed file (offline/simulation mode)",
    )
    parser.add_argument(
        "--generate-sample",
        action="store_true",
        help="Generate a realistic sample historical JSON file and exit",
    )
    parser.add_argument(
        "--health-check",
        action="store_true",
        help="Check health and connectivity with SAP HR endpoint",
    )
    parser.add_argument(
        "--live",
        action="store_true",
        help="Execute real live transfer to SAP (disables default simulation mode)",
    )
    parser.add_argument(
        "--export-csv",
        type=str,
        help="Custom destination path for CSV export",
    )
    parser.add_argument(
        "--export-json",
        type=str,
        help="Custom destination path for JSON export",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Enable verbose debug logging",
    )

    args = parser.parse_args()
    setup_logging(args.verbose)

    # 1. Generate sample if requested
    if args.generate_sample:
        sample_path = PACKAGE_DIR / "data" / "sample_historical_firestore.json"
        created = create_sample_seed_file(sample_path)
        print(f"\n[OK] Realistic sample seed dataset created at: {created}\n")
        return

    # 2. Health check
    if args.health_check:
        adapter = SuccessFactorsTimeTrackingAdapter()
        status = adapter.health_check()
        print("\n=== SAP HR Connection Health Check ===")
        print(json.dumps(status, indent=2))
        return

    # Parse dates
    start_dt = datetime.strptime(args.start_date, "%Y-%m-%d").date() if args.start_date else None
    end_dt = datetime.strptime(args.end_date, "%Y-%m-%d").date() if args.end_date else None

    # Check for seed file or generate default sample if no remote creds
    mock_path = Path(args.mock_data) if args.mock_data else None
    if not mock_path and not settings.firebase.credentials_path:
        default_sample = PACKAGE_DIR / "data" / "sample_historical_firestore.json"
        if not default_sample.exists():
            create_sample_seed_file(default_sample)
        mock_path = default_sample

    # Determine simulation vs live
    is_dry_run = not args.live

    # Run service
    service = AttendanceSyncService()
    report = service.run_sync(
        start_date=start_dt,
        end_date=end_dt,
        worker_id=args.worker_id,
        mock_file_path=mock_path,
        export_csv_path=Path(args.export_csv) if args.export_csv else None,
        export_json_path=Path(args.export_json) if args.export_json else None,
        transfer_to_sap=True,
    )

    # Print summary
    print("\n" + "=" * 60)
    print("        INFORME DE PROCESAMIENTO - INTEGRACIÓN SAP HR")
    print("=" * 60)
    print(f"Duración de la ejecución:  {report.duration_seconds} segundos")
    print(f"Total registros extraídos: {report.total_extracted}")
    print(f"Registros válidos:         {report.total_valid}")
    print(f"Registros rechazados:      {report.total_rejected}")
    print(f"  - Duplicados detectados: {report.total_duplicates}")
    print(f"Registros exportados:      {report.total_exported}")
    print(f"Envíos simulados a SAP:    {report.sap_simulated}")
    print(f"Envíos en vivo a SAP:      {report.sap_transferred}")
    print(f"Errores de conexión SAP:   {report.sap_errors}")
    print("=" * 60)

    if report.validation_issues:
        print("\nDetalle de incidencias de validación / rechazados:")
        for idx, issue in enumerate(report.validation_issues, 1):
            print(f"  {idx}. [{issue['code']}] Doc: {issue['record_id']} | {issue['worker_name']} - {issue['message']}")

    print("\n[OK] Ejecución completada exitosamente.\n")


if __name__ == "__main__":
    main()
