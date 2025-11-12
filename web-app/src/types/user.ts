export interface UserData {
  uid: string;
  role: string;
  email: string;
  dni: string;
  fullName: string;
  assignedWorksiteId: string | null;
  isActive: boolean;
  /* createdAt: FieldValue;
  updatedAt: FieldValue; */
}

export interface CreateWorkerData {
  email?: string;
  password: string;
  dni: string;
  fullName: string;
  role?: string;
}
