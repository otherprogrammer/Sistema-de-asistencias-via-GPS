export interface UserData {
  uid: string;
  role: string;
  email: string;
  dni: string;
  fullName: string;
  assignedWorksiteId: string | null;
  isActive: boolean;
}