import { collection, doc, runTransaction, serverTimestamp, setDoc } from 'firebase/firestore';
import { db } from '../lib/firebase.config';
import type { AttendanceEdit } from '../types/attendanceEdit';

const ATTENDANCE_COLLECTION = 'attendances';
const AUDIT_COLLECTION = 'attendance_edits';

/**
 * Guarda un registro de auditoría en la colección `attendance_edits`.
 */
export const saveAttendanceEdit = async (edit: AttendanceEdit) => {
  const editRef = doc(collection(db, AUDIT_COLLECTION));
  const payload = {
    attendanceId: edit.attendanceId,
    editedBy: edit.editedBy,
    timestamp: edit.timestamp instanceof Date ? edit.timestamp : serverTimestamp(),
    justification: edit.justification,
    previousData: edit.previousData,
  };

  await setDoc(editRef, payload);
  return editRef.id;
};

/**
 * Aplica un cambio en el documento de asistencia y registra la auditoría en una transacción.
 * updates: campos a actualizar en el documento de asistencia (por ejemplo { checkInTime: new Date(...) })
 */
export const applyAttendanceEdit = async (
  attendanceId: string,
  updates: Record<string, unknown>,
  adminUid: string,
  justification: string,
) => {
  const attendanceRef = doc(db, ATTENDANCE_COLLECTION, attendanceId);
  const editRef = doc(collection(db, AUDIT_COLLECTION));

  await runTransaction(db, async (transaction) => {
    const attendanceSnap = await transaction.get(attendanceRef);
    if (!attendanceSnap.exists()) {
      throw new Error('Registro de asistencia no encontrado');
    }

    const previousData = attendanceSnap.data();

    // Aplicar cambios
    transaction.update(attendanceRef, updates);

    // Guardar auditoría
    const auditPayload = {
      attendanceId,
      editedBy: adminUid,
      timestamp: serverTimestamp(),
      justification,
      previousData,
    };

    transaction.set(editRef, auditPayload);
  });
};

export default {
  saveAttendanceEdit,
  applyAttendanceEdit,
};
