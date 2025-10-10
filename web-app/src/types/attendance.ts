export interface AttendanceRecord {
  id: string;
  workerId: string;
  workerName: string;
  workerDNI: string;
  worksiteId: string;
  worksiteName: string;
  checkInTime: Date;
  checkOutTime?: Date;
  status: 'present' | 'absent' | 'outside' | 'late';
  latitude?: number;
  longitude?: number;
  totalHours?: number;
  date: Date;
}

export interface WorkerAttendanceStatus {
  workerId: string;
  workerName: string;
  workerDNI: string;
  worksiteId: string | null;
  worksiteName: string | null;
  status: 'present' | 'absent' | 'outside';
  lastCheckIn?: Date;
  lastCheckOut?: Date;
  isInsideGeofence: boolean;
}