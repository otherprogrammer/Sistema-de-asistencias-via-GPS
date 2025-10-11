import { useEffect, useState } from 'react';
import type { AttendanceRecord } from '../types/attendance';
import { useAuth } from '../contexts/AuthContext';
import { applyAttendanceEdit } from '../services/auditService';

interface Props {
  open: boolean;
  record: AttendanceRecord | null;
  onClose: () => void;
  onSaved?: () => void;
}

const AttendanceEditModal: React.FC<Props> = ({ open, record, onClose, onSaved }) => {
  const { user } = useAuth();
  const [checkIn, setCheckIn] = useState<string>('');
  const [checkOut, setCheckOut] = useState<string>('');
  const [justification, setJustification] = useState<string>('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (record) {
      try {
        const inVal = record.punchIn?.timestamp ? record.punchIn.timestamp.toDate() : null;
        const outVal = record.punchOut?.timestamp ? record.punchOut.timestamp.toDate() : null;
        console.log(inVal, outVal);
        const localInVal = inVal ? new Date(inVal).toLocaleString('sv-SE').slice(0, 16) : '';
        const localOutVal = outVal ? new Date(outVal).toLocaleString('sv-SE').slice(0, 16) : '';
        console.log(localInVal, localOutVal);
        setCheckIn(localInVal);
        setCheckOut(localOutVal);
      } catch(error) {
        console.error(error);
        setCheckIn('');
        setCheckOut('');
      }
      setJustification('');
      setError('');
    }
  }, [record, open]);

  if (!open || !record) return null;

  const handleSave = async () => {
    setError('');

    if (!justification || justification.trim().length < 5) {
      setError('La justificación es obligatoria (mínimo 5 caracteres)');
      return;
    }

    const updates: Record<string, unknown> = {};

    // Parse inputs (YYYY-MM-DDTHH:mm)
    const inDate = checkIn ? new Date(checkIn) : null;
    const outDate = checkOut ? new Date(checkOut) : null;

    if (checkIn && (isNaN(inDate!.getTime()))) {
        setError('Fecha y hora de entrada inválida');
        return;
    }
    if (checkOut && (isNaN(outDate!.getTime()))) {
        setError('Fecha y hora de salida inválida');
        return;
    }

    if (inDate) updates['punchIn.timestamp'] = inDate;
    if (outDate) updates['punchOut.timestamp'] = outDate;

    try {
      setSaving(true);
      await applyAttendanceEdit(record.id, updates, user!.uid, justification.trim());
      setSaving(false);
      onSaved?.();
      onClose();
    } catch (err: unknown) {
      setSaving(false);
      const message = err instanceof Error ? err.message : 'Error guardando la edición';
      setError(message);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-40">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-2xl mx-4">
        <div className="p-6 border-b">
          <h3 className="text-lg font-bold">Editar registro de asistencia</h3>
          <p className="text-sm text-gray-600">Trabajador: {record.workerName} — {record.workerDNI}</p>
        </div>
        <div className="p-6 space-y-4">
          {error && <div className="text-sm text-red-600 font-medium">{error}</div>}

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Entrada</label>
            <input
              type="datetime-local"
              value={checkIn}
              onChange={(e) => setCheckIn(e.target.value)}
              className="w-full px-4 py-2 border rounded-lg"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Salida</label>
            <input
              type="datetime-local"
              value={checkOut}
              onChange={(e) => setCheckOut(e.target.value)}
              className="w-full px-4 py-2 border rounded-lg"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Justificación (obligatoria)</label>
            <textarea
              value={justification}
              onChange={(e) => setJustification(e.target.value)}
              rows={4}
              className="w-full px-4 py-2 border rounded-lg"
            />
          </div>
        </div>

        <div className="flex items-center justify-end space-x-3 p-6 border-t">
          <button onClick={onClose} className="px-4 py-2 rounded-lg border">Cancelar</button>
          <button
            onClick={() => void handleSave()}
            disabled={saving}
            className="bg-gradient-to-r from-primary-500 to-primary-600 text-white px-5 py-2 rounded-lg font-bold disabled:opacity-60"
          >
            {saving ? 'Guardando...' : 'Guardar cambios'}
          </button>
        </div>
      </div>
    </div>
  );
};

export default AttendanceEditModal;
