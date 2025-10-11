import type { Timestamp } from "firebase/firestore";

export interface Worksite {
  worksiteId: string;
  name: string;
  latitude: number;
  longitude: number;
  radius: number;
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
  isActive?: boolean;
}

export interface CreateWorksiteData {
  name: string;
  latitude: number;
  longitude: number;
  radius: number;
}
