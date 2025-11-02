"""
Production adapter for SAP SuccessFactors Time Tracking OData v2 API.
Entity: ExternalTimeData
Documentation: SAP SuccessFactors Employee Central Time Tracking Integration
"""

import json
import logging
import time
from typing import List, Dict, Any, Optional

import requests

from .base import SAPHRAdapterBase
from ..config import settings, SAPConfig
from ..models import NormalizedAttendance, SAPExternalTimeDataPayload

logger = logging.getLogger(__name__)


class SuccessFactorsTimeTrackingAdapter(SAPHRAdapterBase):
    """
    Adapter communicating with SAP SuccessFactors OData v2 API for Time Tracking.
    Targets entity 'ExternalTimeData' for raw punch entries or duration time data.
    """

    def __init__(self, config: Optional[SAPConfig] = None):
        self.config = config or settings.sap
        self._csrf_token: Optional[str] = None
        self._session_cookies: Dict[str, str] = {}
        self._access_token: Optional[str] = None

    @property
    def endpoint_url(self) -> str:
        base = self.config.base_url.rstrip("/")
        return f"{base}/odata/v2/ExternalTimeData"

    def authenticate(self) -> bool:
        """
        Authenticate against SuccessFactors.
        Supports OAuth 2.0 or Basic Auth with CSRF token retrieval.
        In simulation/dry-run mode, immediately returns True with simulated token.
        """
        if self.config.dry_run:
            logger.info("SAP Adapter running in DRY-RUN simulation mode. Authentication simulated.")
            self._csrf_token = "SIMULATED_CSRF_TOKEN_SF_2025"
            return True

        # Check for OAuth2 client credentials
        if self.config.client_secret and self.config.token_url:
            return self._obtain_oauth_token()

        # Basic Auth + CSRF Fetch
        if self.config.username and self.config.password:
            return self._fetch_csrf_token()

        logger.error("No valid SAP credentials provided (neither OAuth2 nor Basic Auth configured)")
        return False

    def transform(self, record: NormalizedAttendance) -> SAPExternalTimeDataPayload:
        """
        Transform a NormalizedAttendance record into a SuccessFactors ExternalTimeData entity.
        Maps worker DNI to SAP userId / personIdExternal.
        """
        user_id = record.worker_dni if record.worker_dni else record.worker_id
        start_date_str = record.shift_date.strftime("%Y-%m-%d")

        start_time_str = "08:00:00"
        if record.punch_in:
            start_time_str = record.punch_in.timestamp.strftime("%H:%M:%S")

        end_date_str = start_date_str
        end_time_str = start_time_str
        if record.punch_out:
            end_date_str = record.punch_out.timestamp.strftime("%Y-%m-%d")
            end_time_str = record.punch_out.timestamp.strftime("%H:%M:%S")

        hours = record.calculate_hours()
        cost_center = record.worksite_id or self.config.default_cost_center

        comment = (
            f"Obra: {record.worksite_name} | "
            f"GPS Validado: {'SI' if record.punch_in and record.punch_in.is_valid_location else 'NO'} | "
            f"Biometria: {'VALIDADA' if record.biometric_verified else 'NO'}"
        )

        return SAPExternalTimeDataPayload(
            external_code=f"ATT_{record.record_id}",
            user_id=user_id,
            start_date=start_date_str,
            start_time=start_time_str,
            end_date=end_date_str,
            end_time=end_time_str,
            time_type=self.config.time_type_regular,
            hours=hours,
            cost_center=cost_center,
            status="APPROVED",
            source="MOBILE_GPS_FACIAL",
            comment=comment,
        )

    def send_record(self, record: NormalizedAttendance) -> Dict[str, Any]:
        """Send a single transformed attendance record to SAP SuccessFactors"""
        payload = self.transform(record)
        odata_payload = payload.to_odata_dict()

        if self.config.dry_run:
            return self._simulate_sap_success(payload)

        headers = self._build_headers()
        try:
            resp = requests.post(
                self.endpoint_url,
                json=odata_payload,
                headers=headers,
                cookies=self._session_cookies,
                timeout=self.config.timeout_seconds,
            )
            return self._parse_sap_response(resp, payload.external_code)
        except Exception as e:
            logger.error("Failed to post record %s to SAP: %s", payload.external_code, e)
            return {
                "success": False,
                "external_code": payload.external_code,
                "status_code": 0,
                "error": str(e),
                "simulated": False,
            }

    def send_batch(self, records: List[NormalizedAttendance]) -> List[Dict[str, Any]]:
        """
        Send a batch of records.
        In live mode, uses OData $batch if possible or sequential requests with backoff.
        """
        results = []
        for record in records:
            res = self.send_record(record)
            results.append(res)
            # Gentle pacing in live mode
            if not self.config.dry_run:
                time.sleep(0.05)
        return results

    def health_check(self) -> Dict[str, Any]:
        """Test SAP SuccessFactors service availability"""
        if self.config.dry_run:
            return {
                "status": "SIMULATED_HEALTHY",
                "mode": "DRY_RUN",
                "endpoint": self.endpoint_url,
                "target_entity": "ExternalTimeData",
                "company_id": self.config.company_id,
            }

        headers = self._build_headers()
        try:
            test_url = f"{self.config.base_url.rstrip('/')}/odata/v2/ExternalTimeData?$top=1"
            resp = requests.get(test_url, headers=headers, timeout=10)
            return {
                "status": "UP" if resp.status_code == 200 else "DEGRADED",
                "status_code": resp.status_code,
                "endpoint": test_url,
                "mode": "LIVE",
            }
        except Exception as e:
            return {
                "status": "DOWN",
                "error": str(e),
                "endpoint": self.endpoint_url,
                "mode": "LIVE",
            }

    def _simulate_sap_success(self, payload: SAPExternalTimeDataPayload) -> Dict[str, Any]:
        """Return a realistic simulated SAP SuccessFactors OData v2 response"""
        return {
            "success": True,
            "simulated": True,
            "status_code": 201,
            "external_code": payload.external_code,
            "sap_response": {
                "d": {
                    "__metadata": {
                        "uri": f"{self.endpoint_url}('{payload.external_code}')",
                        "type": "SFOData.ExternalTimeData",
                    },
                    "externalCode": payload.external_code,
                    "userId": payload.user_id,
                    "startDate": f"/Date(1729382400000)/",
                    "startTime": payload.start_time,
                    "endDate": f"/Date(1729382400000)/",
                    "endTime": payload.end_time,
                    "timeType": payload.time_type,
                    "status": "APPROVED",
                    "hours": str(payload.hours or "0.00"),
                    "costCenter": payload.cost_center,
                }
            },
        }

    def _build_headers(self) -> Dict[str, str]:
        """Build HTTP headers required by SAP OData v2"""
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json",
        }
        if self._csrf_token:
            headers["X-CSRF-Token"] = self._csrf_token

        if self._access_token:
            headers["Authorization"] = f"Bearer {self._access_token}"
        elif self.config.username and self.config.password:
            # Basic Auth in format username@companyId:password
            import base64
            auth_str = f"{self.config.username}@{self.config.company_id}:{self.config.password}"
            encoded = base64.b64encode(auth_str.encode("utf-8")).decode("utf-8")
            headers["Authorization"] = f"Basic {encoded}"

        return headers

    def _fetch_csrf_token(self) -> bool:
        """Fetch X-CSRF-Token from SuccessFactors service root"""
        root_url = f"{self.config.base_url.rstrip('/')}/odata/v2/"
        headers = {
            "X-CSRF-Token": "Fetch",
            "Accept": "application/json",
        }
        # Add basic auth
        if self.config.username and self.config.password:
            import base64
            auth_str = f"{self.config.username}@{self.config.company_id}:{self.config.password}"
            encoded = base64.b64encode(auth_str.encode("utf-8")).decode("utf-8")
            headers["Authorization"] = f"Basic {encoded}"

        try:
            resp = requests.get(root_url, headers=headers, timeout=self.config.timeout_seconds)
            token = resp.headers.get("x-csrf-token") or resp.headers.get("X-CSRF-Token")
            if token:
                self._csrf_token = token
                self._session_cookies = dict(resp.cookies)
                return True
            logger.warning("CSRF token not present in SAP response headers")
            return False
        except Exception as e:
            logger.error("Error fetching SAP CSRF token: %s", e)
            return False

    def _obtain_oauth_token(self) -> bool:
        """Obtain OAuth 2.0 token using client credentials"""
        data = {
            "client_id": self.config.client_id,
            "client_secret": self.config.client_secret,
            "grant_type": "client_credentials",
            "company_id": self.config.company_id,
        }
        try:
            resp = requests.post(self.config.token_url, data=data, timeout=15)
            if resp.status_code == 200:
                self._access_token = resp.json().get("access_token")
                return bool(self._access_token)
            logger.error("OAuth token request failed with status %d: %s", resp.status_code, resp.text)
            return False
        except Exception as e:
            logger.error("OAuth authentication exception: %s", e)
            return False

    def _parse_sap_response(self, resp: requests.Response, external_code: str) -> Dict[str, Any]:
        """Parse HTTP response from SAP SuccessFactors"""
        if resp.status_code in (200, 201):
            try:
                body = resp.json()
            except Exception:
                body = resp.text
            return {
                "success": True,
                "external_code": external_code,
                "status_code": resp.status_code,
                "sap_response": body,
                "simulated": False,
            }
        else:
            error_msg = resp.text
            try:
                err_json = resp.json()
                if "error" in err_json and "message" in err_json["error"]:
                    error_msg = err_json["error"]["message"].get("value", error_msg)
            except Exception:
                pass
            return {
                "success": False,
                "external_code": external_code,
                "status_code": resp.status_code,
                "error": error_msg,
                "simulated": False,
            }
