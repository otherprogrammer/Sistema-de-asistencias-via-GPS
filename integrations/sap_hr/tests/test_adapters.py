"""
Unit tests for SAP HR Adapters (SuccessFactors Time Tracking & SAP ERP HCM).
"""

from integrations.sap_hr.adapters.successfactors import SuccessFactorsTimeTrackingAdapter
from integrations.sap_hr.adapters.sap_erp import SAPERPHCMAdapter


def test_successfactors_transform_payload(sample_valid_attendance):
    adapter = SuccessFactorsTimeTrackingAdapter()
    payload = adapter.transform(sample_valid_attendance)

    assert payload.external_code == f"ATT_{sample_valid_attendance.record_id}"
    assert payload.user_id == sample_valid_attendance.worker_dni
    assert payload.start_date == "2025-10-20"
    assert payload.start_time == "08:00:00"
    assert payload.end_date == "2025-10-20"
    assert payload.end_time == "17:00:00"
    assert payload.hours == 9.0

    odata_dict = payload.to_odata_dict()
    assert odata_dict["__metadata"]["type"] == "SFOData.ExternalTimeData"
    assert odata_dict["externalCode"] == f"ATT_{sample_valid_attendance.record_id}"
    assert odata_dict["status"] == "APPROVED"


def test_successfactors_dry_run_simulation(sample_valid_attendance):
    adapter = SuccessFactorsTimeTrackingAdapter()
    res = adapter.send_record(sample_valid_attendance)

    assert res["success"] is True
    assert res["simulated"] is True
    assert res["status_code"] == 201
    assert "d" in res["sap_response"]
    assert res["sap_response"]["d"]["externalCode"] == f"ATT_{sample_valid_attendance.record_id}"


def test_successfactors_health_check():
    adapter = SuccessFactorsTimeTrackingAdapter()
    status = adapter.health_check()

    assert status["status"] == "SIMULATED_HEALTHY"
    assert status["mode"] == "DRY_RUN"
    assert status["target_entity"] == "ExternalTimeData"


def test_sap_erp_hcm_transform(sample_valid_attendance):
    adapter = SAPERPHCMAdapter()
    events = adapter.transform(sample_valid_attendance)

    # Must contain both P10 (entry) and P20 (exit)
    assert len(events) == 2
    in_event = events[0]
    out_event = events[1]

    assert in_event["SATZA"] == "P10"
    assert in_event["LTIME"] == "080000"
    assert in_event["PERNR"] == sample_valid_attendance.worker_dni[:8].zfill(8)

    assert out_event["SATZA"] == "P20"
    assert out_event["LTIME"] == "170000"
