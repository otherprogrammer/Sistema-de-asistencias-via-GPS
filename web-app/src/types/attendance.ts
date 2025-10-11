import type { GeoPoint, Timestamp } from "firebase/firestore";

export interface AttendanceRecord {
  id: string;
  workerId: string;
  workerName: string;
  workerDNI: string;
  worksiteId: string;
  worksiteName: string;
  punchIn: {
    timestamp: Timestamp;
    location: GeoPoint;
  };
  punchOut: {
    timestamp: Timestamp;
    location: GeoPoint;
  };
  status: 'Presente' | 'Ausente' | 'Intento Fallido' | 'Tarde';
  workedHours?: number;
  date: Timestamp;
}

export interface WorkerAttendanceStatus {
  workerId: string;
  workerName: string;
  workerDNI: string;
  worksiteId: string;
  status: 'Presente' | 'Ausente' | 'Intento Fallido' | 'Fuera de obra' | 'Tarde';
  lastCheckIn?: Date;
  lastCheckOut?: Date;
  isInsideGeofence: boolean;
}