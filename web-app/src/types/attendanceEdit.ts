import type { Timestamp } from 'firebase/firestore';

export interface AttendanceEdit {
  editId?: string; // optional when creating, Firestore will generate
  attendanceId: string;
  editedBy: string;
  timestamp: Timestamp | Date;
  justification: string;
  previousData: Record<string, unknown>;
}
