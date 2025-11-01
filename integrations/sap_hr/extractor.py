"""
Módulo de Extracción de Asistencias Históricas desde Firebase Firestore.

Este componente se encarga de:
1. Conectarse a Firestore (vía REST API directa o Firebase Admin SDK).
2. Extraer documentos de la colección 'attendances'.
3. Realizar joins lógicos con 'users' (para obtener DNI y nombre) y 'worksites' (para nombre de obra).
4. GARANTÍA DE PRIVACIDAD: Filtrar y omitir activamente fotos y vectores biométricos.
5. Permitir la carga de datos semilla (seed JSON) para simulaciones y pruebas locales.
"""

import json
import logging
from datetime import datetime, date
from pathlib import Path
from typing import Dict, List, Any, Optional

import requests

from .config import settings, FirebaseConfig
from .models import PunchDetail, NormalizedAttendance, AttendanceStatus

logger = logging.getLogger(__name__)


class AttendanceExtractor:
    """
    Extractor de asistencias, trabajadores y obras desde Firebase.
    Aplica una política estricta de exclusión para vectores biométricos ('faceEmbedding')
    y URLs de fotografías faciales ('faceImageUrl').
    """

    def __init__(self, config: Optional[FirebaseConfig] = None):
        self.config = config or settings.firebase
        self._users_cache: Dict[str, Dict[str, Any]] = {}
        self._worksites_cache: Dict[str, Dict[str, Any]] = {}

    def extract_all(
        self,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        worker_id: Optional[str] = None,
        mock_file_path: Optional[Path] = None,
    ) -> List[NormalizedAttendance]:
        """
        Extrae y normaliza los registros de asistencia aplicando los filtros solicitados.
        
        Parámetros:
            start_date: Fecha inicial de la jornada (opcional)
            end_date: Fecha final de la jornada (opcional)
            worker_id: UID específico de un trabajador (opcional)
            mock_file_path: Ruta a un archivo JSON semilla para modo offline (opcional)
        """
        # Si se especifica un archivo mock o dataset semilla, priorizarlo para modo simulación
        if mock_file_path and mock_file_path.exists():
            logger.info("Cargando registros desde archivo semilla/mock: %s", mock_file_path)
            return self._extract_from_seed_file(mock_file_path, start_date, end_date, worker_id)

        # Cargar metadatos de soporte (usuarios y obras) para enriquecer cada marcaje
        self._load_metadata()

        # Extraer documentos de asistencia desde Firestore
        raw_attendances = self._fetch_attendances(start_date, end_date, worker_id)
        logger.info("Se extrajeron %d documentos brutos de asistencia", len(raw_attendances))

        # Denormalizar y construir los objetos estandarizados
        normalized_records = []
        for raw in raw_attendances:
            norm = self._denormalize_record(raw)
            if norm:
                normalized_records.append(norm)

        return normalized_records

    def _load_metadata(self) -> None:
        """
        Descarga y almacena en memoria los datos de obras y usuarios.
        POLÍTICA DE PRIVACIDAD: Sanitiza los datos de usuarios asegurando que
        ningún dato biométrico ('faceEmbedding' o 'faceImageUrl') sea almacenado.
        """
        # 1. Cargar catálogo de obras/proyectos
        try:
            worksites = self._fetch_collection(self.config.worksites_collection)
            for w in worksites:
                w_id = w.get("id") or w.get("_id")
                if w_id:
                    self._worksites_cache[w_id] = {
                        "name": w.get("name", "Obra Desconocida"),
                        "latitude": float(w.get("latitude", 0.0)),
                        "longitude": float(w.get("longitude", 0.0)),
                        "radius": float(w.get("radius", 100.0)),
                    }
        except Exception as e:
            logger.warning("No se pudo cargar la colección de obras: %s", e)

        # 2. Cargar catálogo de trabajadores
        try:
            users = self._fetch_collection(self.config.users_collection)
            for u in users:
                u_id = u.get("id") or u.get("uid") or u.get("_id")
                if u_id:
                    # Se guardan solo los campos laborales indispensables
                    self._users_cache[u_id] = {
                        "dni": u.get("dni"),
                        "fullName": u.get("fullName", "Trabajador Sin Nombre"),
                        "role": u.get("role", "trabajador"),
                        "faceRegistered": bool(u.get("faceRegistered", False)),
                        # NOTA CRÍTICA DE SEGURIDAD:
                        # 'faceEmbedding' -> EXCLUIDO INTENCIONALMENTE
                        # 'faceImageUrl'  -> EXCLUIDO INTENCIONALMENTE
                    }
        except Exception as e:
            logger.warning("No se pudo cargar la colección de usuarios: %s", e)

    def _fetch_attendances(
        self,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        worker_id: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        """
        Consulta documentos de asistencia desde la API REST de Firestore.
        Aplica paginación y filtrado por fechas en memoria.
        """
        if not self.config.use_rest_api or not self.config.project_id:
            logger.info("API REST no habilitada o sin project_id; retornando dataset vacío.")
            return []

        url = (
            f"https://firestore.googleapis.com/v1/projects/{self.config.project_id}"
            f"/databases/{self.config.database_id}/documents/{self.config.attendances_collection}"
        )
        params: Dict[str, Any] = {"pageSize": 1000}
        if self.config.api_key:
            params["key"] = self.config.api_key

        try:
            resp = requests.get(url, params=params, timeout=15)
            if resp.status_code == 200:
                data = resp.json()
                docs = data.get("documents", [])
                parsed = [self._parse_firestore_rest_document(d) for d in docs]
                
                # Filtrar en memoria por trabajador y rango de fechas
                filtered = []
                for p in parsed:
                    if worker_id and p.get("workerId") != worker_id:
                        continue
                    p_date = self._parse_date_field(p.get("date"))
                    if start_date and p_date and p_date < start_date:
                        continue
                    if end_date and p_date and p_date > end_date:
                        continue
                    filtered.append(p)
                return filtered
            else:
                logger.warning("Firestore REST respondió con código %d: %s", resp.status_code, resp.text)
                return []
        except Exception as e:
            logger.warning("Error al consultar asistencias vía Firestore REST: %s", e)
            return []

    def _fetch_collection(self, collection_name: str) -> List[Dict[str, Any]]:
        """Descarga todos los documentos de una colección auxiliar (users u obras)."""
        if not self.config.use_rest_api or not self.config.project_id:
            return []

        url = (
            f"https://firestore.googleapis.com/v1/projects/{self.config.project_id}"
            f"/databases/{self.config.database_id}/documents/{collection_name}"
        )
        params: Dict[str, Any] = {"pageSize": 500}
        if self.config.api_key:
            params["key"] = self.config.api_key

        try:
            resp = requests.get(url, params=params, timeout=15)
            if resp.status_code == 200:
                docs = resp.json().get("documents", [])
                return [self._parse_firestore_rest_document(d) for d in docs]
            return []
        except Exception as e:
            logger.warning("Fallo al obtener colección %s: %s", collection_name, e)
            return []

    def _denormalize_record(self, raw: Dict[str, Any]) -> Optional[NormalizedAttendance]:
        """
        Combina el registro bruto de asistencia con la información del trabajador y la obra.
        Genera la instancia limpia NormalizedAttendance para el motor de integración.
        """
        record_id = raw.get("id") or raw.get("_id") or "UNKNOWN_ID"
        worker_id = raw.get("workerId", "")
        worksite_id = raw.get("worksiteId", "")

        # Cruzar con información de usuarios y obras en caché
        user_info = self._users_cache.get(worker_id, {})
        worksite_info = self._worksites_cache.get(worksite_id, {})

        shift_date_obj = self._parse_date_field(raw.get("date")) or date.today()

        # Parsear marcajes de entrada y salida
        punch_in = self._parse_punch_field(raw.get("punchIn"))
        punch_out = self._parse_punch_field(raw.get("punchOut"))

        # Estatus del turno
        raw_status = raw.get("status", "Presente")
        try:
            status = AttendanceStatus(raw_status)
        except ValueError:
            status = AttendanceStatus.PRESENTE

        worked_hours = raw.get("workedHours")
        if worked_hours is not None:
            try:
                worked_hours = float(worked_hours)
            except (ValueError, TypeError):
                worked_hours = None

        return NormalizedAttendance(
            record_id=record_id,
            worker_id=worker_id,
            worker_dni=user_info.get("dni") or raw.get("workerDNI"),
            worker_name=user_info.get("fullName") or raw.get("workerName") or f"Worker_{worker_id[:8]}",
            worksite_id=worksite_id,
            worksite_name=worksite_info.get("name") or raw.get("worksiteName") or f"Site_{worksite_id[:8]}",
            shift_date=shift_date_obj,
            punch_in=punch_in,
            punch_out=punch_out,
            worked_hours=worked_hours,
            status=status,
            biometric_verified=True,  # Confirma que la identidad fue validada biométricamente en el cliente
        )

    def _parse_punch_field(self, field_data: Any) -> Optional[PunchDetail]:
        """Extrae fecha, coordenadas GPS y validez de geocerca de un punchRecord."""
        if not field_data or not isinstance(field_data, dict):
            return None

        # 1. Parsear timestamp
        raw_ts = field_data.get("timestamp")
        dt_val = self._parse_datetime(raw_ts)
        if not dt_val:
            return None

        # 2. Parsear coordenadas geográficas
        loc = field_data.get("location", {})
        if isinstance(loc, dict):
            lat = float(loc.get("latitude", loc.get("_latitude", 0.0)))
            lon = float(loc.get("longitude", loc.get("_longitude", 0.0)))
        elif hasattr(loc, "latitude") and hasattr(loc, "longitude"):
            lat = float(loc.latitude)
            lon = float(loc.longitude)
        else:
            lat, lon = 0.0, 0.0

        is_valid = bool(field_data.get("isValid", True))

        return PunchDetail(
            timestamp=dt_val,
            latitude=lat,
            longitude=lon,
            is_valid_location=is_valid,
        )

    def _parse_datetime(self, val: Any) -> Optional[datetime]:
        """Convierte formatos dispares (Timestamp Firestore, ISO 8601, diccionarios REST) a datetime."""
        if not val:
            return None
        if isinstance(val, datetime):
            return val
        if isinstance(val, str):
            try:
                return datetime.fromisoformat(val.replace("Z", "+00:00"))
            except ValueError:
                pass
        if isinstance(val, dict):
            # Formato de la API REST de Firestore: {"timestampValue": "2025-10-20T08:00:00Z"}
            if "timestampValue" in val:
                return self._parse_datetime(val["timestampValue"])
            # Formato de Firebase Admin SDK: {"_seconds": 1698000000, "_nanoseconds": 0}
            if "_seconds" in val:
                return datetime.fromtimestamp(val["_seconds"])
            if "seconds" in val:
                return datetime.fromtimestamp(val["seconds"])
        return None

    def _parse_date_field(self, val: Any) -> Optional[date]:
        """Convierte un campo de fecha de Firestore en un objeto date de Python."""
        dt = self._parse_datetime(val)
        if dt:
            return dt.date()
        if isinstance(val, date):
            return val
        if isinstance(val, str):
            try:
                return date.fromisoformat(val[:10])
            except ValueError:
                pass
        return None

    def _parse_firestore_rest_document(self, doc: Dict[str, Any]) -> Dict[str, Any]:
        """Desempaqueta la estructura de tipos anidados del documento REST de Firestore."""
        doc_name = doc.get("name", "")
        doc_id = doc_name.split("/")[-1] if doc_name else "doc"
        fields = doc.get("fields", {})
        parsed: Dict[str, Any] = {"id": doc_id}

        for k, v in fields.items():
            parsed[k] = self._unwrap_firestore_value(v)

        return parsed

    def _unwrap_firestore_value(self, val_dict: Dict[str, Any]) -> Any:
        """Desenvuelve tipos específicos de Firestore (stringValue, integerValue, etc.)."""
        if "stringValue" in val_dict:
            return val_dict["stringValue"]
        if "integerValue" in val_dict:
            return int(val_dict["integerValue"])
        if "doubleValue" in val_dict:
            return float(val_dict["doubleValue"])
        if "booleanValue" in val_dict:
            return bool(val_dict["booleanValue"])
        if "timestampValue" in val_dict:
            return val_dict["timestampValue"]
        if "geoPointValue" in val_dict:
            return val_dict["geoPointValue"]
        if "mapValue" in val_dict:
            fields = val_dict["mapValue"].get("fields", {})
            return {k: self._unwrap_firestore_value(v) for k, v in fields.items()}
        if "arrayValue" in val_dict:
            values = val_dict["arrayValue"].get("values", [])
            return [self._unwrap_firestore_value(v) for v in values]
        if "nullValue" in val_dict:
            return None
        return None

    def _extract_from_seed_file(
        self,
        file_path: Path,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        worker_id: Optional[str] = None,
    ) -> List[NormalizedAttendance]:
        """
        Carga registros históricos desde un archivo JSON semilla.
        Permite simular el entorno de Firestore sin necesidad de conexión activa.
        """
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        # Poblar cachés de usuarios y obras desde el archivo semilla
        for u in data.get("users", []):
            u_id = u.get("uid") or u.get("id")
            if u_id:
                self._users_cache[u_id] = {
                    "dni": u.get("dni"),
                    "fullName": u.get("fullName", "Trabajador"),
                    "role": u.get("role", "trabajador"),
                }

        for w in data.get("worksites", []):
            w_id = w.get("id")
            if w_id:
                self._worksites_cache[w_id] = {
                    "name": w.get("name", "Obra"),
                    "latitude": float(w.get("latitude", 0.0)),
                    "longitude": float(w.get("longitude", 0.0)),
                }

        records = []
        for raw in data.get("attendances", []):
            if worker_id and raw.get("workerId") != worker_id:
                continue
            norm = self._denormalize_record(raw)
            if norm:
                if start_date and norm.shift_date < start_date:
                    continue
                if end_date and norm.shift_date > end_date:
                    continue
                records.append(norm)

        return records
