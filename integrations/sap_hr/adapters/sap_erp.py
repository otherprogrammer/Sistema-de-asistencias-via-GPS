"""
Adapter for SAP ERP HCM / S/4HANA On-Premise Time Events (Infotype 2011 / BAPI_TIMEEVENT_STORE).
Generates compliant event records for SAP RFC connector or IDoc HRMD_A.
"""

import logging
from typing import List, Dict, Any, Optional

from .base import SAPHRAdapterBase
from ..config import settings, SAPConfig
from ..models import NormalizedAttendance

logger = logging.getLogger(__name__)


class SAPERPHCMAdapter(SAPHRAdapterBase):
    """
    Adapter targeting SAP ERP HCM (ECC 6.0 / S/4HANA) Time Management (PT).
    Translates clock-in / clock-out punches into SAP Infotype 2011 Time Events (TEVEN).
    """

    def __init__(self, config: Optional[SAPConfig] = None):
        self.config = config or settings.sap

    def authenticate(self) -> bool:
        logger.info("SAP ERP HCM connector ready in simulated RFC mode")
        return True

    def transform(self, record: NormalizedAttendance) -> List[Dict[str, Any]]:
        """
        Translate into SAP BAPI_TIMEEVENT_STORE table entries:
        - SATZA 'P10' = Clock-in (Kommen)
        - SATZA 'P20' = Clock-out (Gehen)
        """
        events = []
        pernr = (record.worker_dni or record.worker_id)[:8].zfill(8)

        if record.punch_in:
            events.append({
                "PERNR": pernr,
                "LDATE": record.punch_in.timestamp.strftime("%Y%m%d"),
                "LTIME": record.punch_in.timestamp.strftime("%H%M%S"),
                "SATZA": "P10",  # Clock-in
                "TERID": "MOB01",
                "ORIGF": "01",  # Origin: Recorded
                "DALLF": "",
                "ABWGR": "",
            })

        if record.punch_out:
            events.append({
                "PERNR": pernr,
                "LDATE": record.punch_out.timestamp.strftime("%Y%m%d"),
                "LTIME": record.punch_out.timestamp.strftime("%H%M%S"),
                "SATZA": "P20",  # Clock-out
                "TERID": "MOB01",
                "ORIGF": "01",
                "DALLF": "",
                "ABWGR": "",
            })

        return events

    def send_record(self, record: NormalizedAttendance) -> Dict[str, Any]:
        events = self.transform(record)
        return {
            "success": True,
            "record_id": record.record_id,
            "sap_events_count": len(events),
            "events": events,
            "simulated": True,
        }

    def send_batch(self, records: List[NormalizedAttendance]) -> List[Dict[str, Any]]:
        return [self.send_record(r) for r in records]

    def health_check(self) -> Dict[str, Any]:
        return {
            "status": "SIMULATED_HEALTHY",
            "type": "SAP_ERP_HCM_BAPI",
            "supported_events": ["P10 (Clock-in)", "P20 (Clock-out)"],
        }
