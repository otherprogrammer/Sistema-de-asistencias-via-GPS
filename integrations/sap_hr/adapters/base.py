"""
Base abstract adapter for SAP HR systems.
Decouples data extraction/validation from the target enterprise software.
"""

from abc import ABC, abstractmethod
from typing import List, Dict, Any, Optional

from ..models import NormalizedAttendance


class SAPHRAdapterBase(ABC):
    """Abstract interface for all SAP HR connectors"""

    @abstractmethod
    def authenticate(self) -> bool:
        """Authenticate against target SAP service or check token validity"""
        pass

    @abstractmethod
    def transform(self, record: NormalizedAttendance) -> Any:
        """Transform normalized attendance into target SAP payload structure"""
        pass

    @abstractmethod
    def send_record(self, record: NormalizedAttendance) -> Dict[str, Any]:
        """Send or simulate sending a single attendance event to SAP"""
        pass

    @abstractmethod
    def send_batch(self, records: List[NormalizedAttendance]) -> List[Dict[str, Any]]:
        """Send or simulate sending a batch of records to SAP"""
        pass

    @abstractmethod
    def health_check(self) -> Dict[str, Any]:
        """Verify connectivity, permissions, and service availability"""
        pass
