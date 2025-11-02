"""
End-to-End Integration Test for the entire Attendance -> SAP HR pipeline.
"""

from pathlib import Path
from integrations.sap_hr.cli import create_sample_seed_file
from integrations.sap_hr.sync_service import AttendanceSyncService
from integrations.sap_hr.adapters.successfactors import SuccessFactorsTimeTrackingAdapter


def test_end_to_end_pipeline_simulation(tmp_path):
    seed_file = tmp_path / "seed_e2e.json"
    create_sample_seed_file(seed_file)

    csv_output = tmp_path / "exports" / "test_out.csv"
    json_output = tmp_path / "exports" / "test_out.json"

    adapter = SuccessFactorsTimeTrackingAdapter()
    service = AttendanceSyncService(adapter=adapter)

    report = service.run_sync(
        mock_file_path=seed_file,
        export_csv_path=csv_output,
        export_json_path=json_output,
        transfer_to_sap=True,
    )

    # In sample_historical_firestore.json:
    # 7 attendances total:
    # - 1 valid Day 1 worker 1
    # - 1 duplicate of worker 1 (should be rejected)
    # - 1 valid Day 1 worker 2
    # - 1 valid Day 1 worker 3
    # - 1 invalid (missing DNI)
    # - 1 invalid (bad GPS 0,0)
    # - 1 valid Day 2 worker 1
    # Expected: 4 valid records, 3 rejected (1 duplicate, 1 missing DNI, 1 bad GPS)

    assert report.total_extracted == 7
    assert report.total_valid == 4
    assert report.total_rejected == 3
    assert report.total_duplicates == 1
    assert report.total_exported == 4
    assert report.sap_simulated == 4
    assert report.sap_errors == 0

    assert csv_output.exists()
    assert json_output.exists()
