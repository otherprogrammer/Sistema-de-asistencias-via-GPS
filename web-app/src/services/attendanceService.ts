import {
  collection,
  query,
  where,
  getDocs,
  orderBy,
  Timestamp,
  onSnapshot
} from 'firebase/firestore';
import { db } from '../lib/firebase.config';
import type { AttendanceRecord, WorkerAttendanceStatus } from '../types';

export class AttendanceService {
  private readonly ATTENDANCE_COLLECTION = 'attendances';
  private readonly USERS_COLLECTION = 'users';

  // Obtener estado en tiempo real de todos los trabajadores
  async getRealtimeWorkerStatus(): Promise<WorkerAttendanceStatus[]> {
    try {
      // Obtener todos los trabajadores
      const workersSnapshot = await getDocs(
        query(collection(db, this.USERS_COLLECTION), where('role', '!=', 'admin'))
      );

      const workers = workersSnapshot.docs.map(doc => doc.data());

      // Obtener registros de asistencia de hoy
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      const attendanceSnapshot = await getDocs(
        query(
          collection(db, this.ATTENDANCE_COLLECTION),
          where('date', '>=', Timestamp.fromDate(today))
        )
      );

      const attendanceRecords = attendanceSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      })) as AttendanceRecord[];

      // Mapear estado de cada trabajador
      const workerStatuses: WorkerAttendanceStatus[] = workers.map(worker => {
        const todayRecords = attendanceRecords.filter(
          record => record.workerId === worker.uid
        );

        const lastRecord = todayRecords.sort(
          (a, b) => b.punchOut?.timestamp.toDate().getTime() - a.punchIn.timestamp.toDate().getTime()
        )[0];

        let status: 'Presente' | 'Ausente' | 'Fuera de obra' = 'Ausente';

        if (lastRecord) {
          if (lastRecord.punchOut?.timestamp.toDate() > new Date()) {
            status = 'Fuera de obra';
          } else {
            status = 'Presente';
          }
        }

        return {
          workerId: worker.uid,
          workerName: worker.fullName,
          workerDNI: worker.dni,
          worksiteId: worker.assignedWorksiteId,
          worksiteName: lastRecord?.worksiteName || 'Sin asignar',
          status,
          lastCheckIn: lastRecord?.punchIn.timestamp.toDate(),
          lastCheckOut: lastRecord?.punchOut?.timestamp.toDate(),
          isInsideGeofence: status === 'Presente'
        };
      });

      return workerStatuses;
    } catch (error) {
      console.error('Error obteniendo estado de trabajadores:', error);
      throw error;
    }
  }

  // Obtener registros con filtros
  async getAttendanceRecords(
    filters: {
      worksiteId?: string;
      workerId?: string;
      startDate?: Date;
      endDate?: Date;
    }
  ): Promise<AttendanceRecord[]> {
    try {
      const constraints: any[] = [];

      if (filters.worksiteId) {
        constraints.push(where('worksiteId', '==', filters.worksiteId));
      }

      if (filters.workerId) {
        constraints.push(where('workerId', '==', filters.workerId));
      }

      if (filters.startDate) {
        constraints.push(where('date', '>=', Timestamp.fromDate(filters.startDate)));
      }

      if (filters.endDate) {
        const endDate = new Date(filters.endDate);
        endDate.setHours(23, 59, 59, 999);
        constraints.push(where('date', '<=', Timestamp.fromDate(endDate)));
      }

      constraints.push(orderBy('date', 'desc'));

      const attendanceQuery = query(
        collection(db, this.ATTENDANCE_COLLECTION),
        ...constraints
      );

      const snapshot = await getDocs(attendanceQuery);

      return snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      })) as AttendanceRecord[];
    } catch (error) {
      console.error('Error obteniendo registros de asistencia:', error);
      throw error;
    }
  }

  // Calcular estadísticas
  calculateStats(records: AttendanceRecord[]) {
    const totalRecords = records.length;
    const presentRecords = records.filter(r => r.status === 'Presente').length;
    const absentRecords = records.filter(r => r.status === 'Ausente').length;
    const lateRecords = records.filter(r => r.status === 'Tarde').length;

    const totalHours = records.reduce((sum, record) => {
      return sum + (record.workedHours || 0);
    }, 0);

    const avgHoursPerDay = totalRecords > 0 ? totalHours / totalRecords : 0;

    return {
      totalRecords,
      presentRecords,
      absentRecords,
      lateRecords,
      totalHours: totalHours.toFixed(2),
      avgHoursPerDay: avgHoursPerDay.toFixed(2),
      attendanceRate: totalRecords > 0 ? ((presentRecords / totalRecords) * 100).toFixed(1) : '0'
    };
  }

  // Suscripción en tiempo real (para actualizaciones automáticas)
  subscribeToRealtimeUpdates(callback: (statuses: WorkerAttendanceStatus[]) => void) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const unsubscribe = onSnapshot(
      query(
        collection(db, this.ATTENDANCE_COLLECTION),
        where('date', '>=', Timestamp.fromDate(today))
      ),
      () => {
        this.getRealtimeWorkerStatus()
            .then(statuses => callback(statuses))
            .catch(error => console.error('Error en suscripción de estado en tiempo real:', error));
      }
    );

    return unsubscribe;
  }
}

export const attendanceService = new AttendanceService();