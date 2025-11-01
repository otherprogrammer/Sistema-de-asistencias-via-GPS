"""
Motor de Validación y Deduplicación de Asistencias para SAP HR.

Reglas aplicadas:
1. Unicidad de ID de documento en Firestore.
2. Presencia de DNI (requerido para mapeo contra personIdExternal/PERNR de SAP).
3. Presencia obligatoria de marcaje de entrada (punchIn).
4. Coordenadas GPS válidas (rango geográfico plausibles y no 0.0, 0.0).
5. Coherencia cronológica: punchIn <= punchOut.
6. Duración máxima del turno (ej. no más de 16 horas continuas).
7. Deduplicación por firma temporal y trabajador (rechazo de dobles marcajes accidentales dentro de la ventana configurada).
"""

import logging
from datetime import timedelta
from typing import List, Tuple, Set, Dict, Any, Optional

from .config import settings, ValidationConfig
from .models import (
    NormalizedAttendance,
    ValidationResult,
    ValidationCode,
    ProcessingReport,
)

logger = logging.getLogger(__name__)


class AttendanceValidator:
    """
    Validador integral y detector de duplicados.
    Produce un conjunto de registros limpios y un informe exhaustivo con métricas.
    """

    def __init__(self, config: Optional[ValidationConfig] = None):
        self.config = config or settings.validation
        self.seen_signatures: Set[str] = set()
        self.seen_record_ids: Set[str] = set()

    def validate_batch(
        self, records: List[NormalizedAttendance]
    ) -> Tuple[List[NormalizedAttendance], ProcessingReport]:
        """
        Valida un lote completo de registros de asistencia.
        Retorna una tupla: (registros_validos, informe_de_procesamiento).
        """
        report = ProcessingReport(total_extracted=len(records))
        valid_records: List[NormalizedAttendance] = []

        # Ordenar cronológicamente para garantizar deduplicación determinista
        sorted_records = sorted(
            records,
            key=lambda r: (
                r.shift_date,
                r.punch_in.timestamp if r.punch_in else r.shift_date,
            ),
        )

        for record in sorted_records:
            result = self.validate_record(record)

            if result.is_valid:
                valid_records.append(record)
                report.total_valid += 1
            else:
                report.total_rejected += 1
                if result.code == ValidationCode.DUPLICATE:
                    report.total_duplicates += 1

                report.validation_issues.append({
                    "record_id": record.record_id,
                    "worker_id": record.worker_id,
                    "worker_name": record.worker_name,
                    "shift_date": record.shift_date.isoformat(),
                    "code": result.code.value,
                    "message": result.message,
                })

        report.finish()
        logger.info(
            "Validación de lote finalizada: %d válidos, %d rechazados (%d duplicados)",
            report.total_valid,
            report.total_rejected,
            report.total_duplicates,
        )
        return valid_records, report

    def validate_record(self, record: NormalizedAttendance) -> ValidationResult:
        """
        Aplica las 7 reglas de validación sobre un registro individual.
        """
        # Regla 1: Unicidad de ID de documento en Firestore
        if record.record_id in self.seen_record_ids:
            return ValidationResult(
                record_id=record.record_id,
                is_valid=False,
                code=ValidationCode.DUPLICATE,
                message=f"ID de documento Firestore duplicado: {record.record_id}",
            )
        self.seen_record_ids.add(record.record_id)

        # Regla 2: El trabajador debe tener DNI para ser indexable en SAP SuccessFactors
        if not record.worker_dni or not record.worker_dni.strip():
            return ValidationResult(
                record_id=record.record_id,
                is_valid=False,
                code=ValidationCode.MISSING_WORKER_DNI,
                message=f"El trabajador {record.worker_name} ({record.worker_id}) no tiene DNI registrado",
            )

        # Regla 3: Debe contar con evento de entrada
        if not record.punch_in:
            return ValidationResult(
                record_id=record.record_id,
                is_valid=False,
                code=ValidationCode.MISSING_PUNCH_IN,
                message="El registro carece de marcaje de entrada (punchIn)",
            )

        # Regla 4: Coordenadas GPS válidas de entrada (evita lat/lon 0.0, 0.0 por falla de sensor)
        lat, lon = record.punch_in.latitude, record.punch_in.longitude
        if not self._is_valid_geo(lat, lon):
            return ValidationResult(
                record_id=record.record_id,
                is_valid=False,
                code=ValidationCode.INVALID_COORDINATES,
                message=f"Coordenadas GPS de entrada inválidas: ({lat}, {lon})",
            )

        # Regla 5: Verificación de perímetro / geocerca de la obra (si está activada en la config)
        if self.config.require_valid_geofence and not record.punch_in.is_valid_location:
            return ValidationResult(
                record_id=record.record_id,
                is_valid=False,
                code=ValidationCode.GEOFENCE_VIOLATION,
                message=f"La entrada del trabajador {record.worker_name} fue marcada fuera de la geocerca permitida",
            )

        # Regla 6: Detección de duplicados por ventana temporal (evita doble clic o sincronizaciones múltiples)
        duplicate_sig = self._generate_dedup_signature(record)
        if duplicate_sig in self.seen_signatures:
            return ValidationResult(
                record_id=record.record_id,
                is_valid=False,
                code=ValidationCode.DUPLICATE,
                message=f"Marcaje duplicado dentro de la ventana de tiempo para {record.worker_name} en fecha {record.shift_date}",
            )
        self.seen_signatures.add(duplicate_sig)

        # Regla 7: Consistencia cronológica de la salida y cálculo de horas
        if record.punch_out:
            out_lat, out_lon = record.punch_out.latitude, record.punch_out.longitude
            if not self._is_valid_geo(out_lat, out_lon):
                return ValidationResult(
                    record_id=record.record_id,
                    is_valid=False,
                    code=ValidationCode.INVALID_COORDINATES,
                    message=f"Coordenadas GPS de salida inválidas: ({out_lat}, {out_lon})",
                )

            if record.punch_out.timestamp < record.punch_in.timestamp:
                return ValidationResult(
                    record_id=record.record_id,
                    is_valid=False,
                    code=ValidationCode.INVALID_HOURS,
                    message=f"Hora de salida ({record.punch_out.timestamp}) es anterior a la entrada ({record.punch_in.timestamp})",
                )

            hours = record.calculate_hours()
            if hours is not None and hours > self.config.max_shift_hours:
                return ValidationResult(
                    record_id=record.record_id,
                    is_valid=False,
                    code=ValidationCode.INVALID_HOURS,
                    message=f"Duración de jornada ({hours}h) excede el máximo permitido ({self.config.max_shift_hours}h)",
                )

        return ValidationResult(
            record_id=record.record_id,
            is_valid=True,
            code=ValidationCode.VALID,
            message="El registro cumple con todos los criterios de validación",
            normalized_record=record,
        )

    def _is_valid_geo(self, lat: float, lon: float) -> bool:
        """Verifica que las coordenadas geográficas sean plausibles y no el punto nulo (0.0, 0.0)."""
        if lat == 0.0 and lon == 0.0:
            return False
        if not (-90.0 <= lat <= 90.0):
            return False
        if not (-180.0 <= lon <= 180.0):
            return False
        return True

    def _generate_dedup_signature(self, record: NormalizedAttendance) -> str:
        """
        Genera una firma única para detectar duplicados dentro de la ventana configurada (ej. 5 minutos).
        Agrupa los minutos dentro del bloque de tolerancia.
        """
        if not record.punch_in:
            return f"{record.worker_id}:{record.shift_date}:no_punch"

        ts = record.punch_in.timestamp
        window_minutes = max(1, self.config.duplicate_window_minutes)
        rounded_minute = (ts.minute // window_minutes) * window_minutes
        rounded_ts_str = f"{ts.year:04d}-{ts.month:02d}-{ts.day:02d}_{ts.hour:02d}:{rounded_minute:02d}"

        return f"{record.worker_id}:{rounded_ts_str}"
