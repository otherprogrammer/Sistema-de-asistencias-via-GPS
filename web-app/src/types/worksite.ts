export interface Worksite {
  worksiteId: string;
  name: string;
  latitude: number;
  longitude: number;
  radius: number;
  createdAt?: any;
  updatedAt?: any;
  isActive?: boolean;
}

export interface CreateWorksiteData {
  name: string;
  latitude: number;
  longitude: number;
  radius: number;
}
