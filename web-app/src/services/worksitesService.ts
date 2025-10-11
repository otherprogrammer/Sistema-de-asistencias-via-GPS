import {
  collection,
  doc,
  getDocs,
  getDoc,
  updateDoc,
  serverTimestamp,
  addDoc,
} from 'firebase/firestore';
import { db } from '../lib/firebase.config';
import type { Worksite, CreateWorksiteData } from '../types';

export class WorksitesService {
  private readonly COLLECTION_NAME = 'worksites';

  // Obtener todas las obras
  async getAllWorksites(): Promise<Worksite[]> {
    try {
      const querySnapshot = await getDocs(collection(db, this.COLLECTION_NAME));

      const worksites = querySnapshot.docs.map(
        (doc) =>
          ({
            worksiteId: doc.id,
            ...doc.data(),
          }) as Worksite,
      );
      return worksites;
    } catch (error) {
      console.error('Error obteniendo obras:', error);
      throw error;
    }
  }

  // Obtener obra por ID
  async getWorksiteById(worksiteId: string): Promise<Worksite | null> {
    try {
      const docRef = doc(db, this.COLLECTION_NAME, worksiteId);
      const docSnap = await getDoc(docRef);

      if (docSnap.exists()) {
        return {
          worksiteId: docSnap.id,
          ...docSnap.data(),
        } as Worksite;
      }
      return null;
    } catch (error) {
      console.error('Error obteniendo obra:', error);
      throw error;
    }
  }

  // Crear nueva obra
  async createWorksite(worksiteData: CreateWorksiteData): Promise<Worksite> {
    try {
      const newWorksite = {
        name: worksiteData.name,
        latitude: worksiteData.latitude,
        longitude: worksiteData.longitude,
        radius: worksiteData.radius,
        isActive: true,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      };

      // Usar addDoc para generar ID automáticamente
      const docRef = await addDoc(collection(db, this.COLLECTION_NAME), newWorksite);

      return {
        worksiteId: docRef.id,
        ...newWorksite,
      } as Worksite;
    } catch (error) {
      console.error('Error creando obra:', error);
      throw error;
    }
  }

  // Actualizar obra
  async updateWorksite(worksiteId: string, updates: Partial<Worksite>): Promise<void> {
    try {
      const docRef = doc(db, this.COLLECTION_NAME, worksiteId);
      await updateDoc(docRef, {
        ...updates,
        updatedAt: serverTimestamp(),
      });
    } catch (error) {
      console.error('Error actualizando obra:', error);
      throw error;
    }
  }

  // Desactivar obra
  async deactivateWorksite(worksiteId: string): Promise<void> {
    try {
      await this.updateWorksite(worksiteId, { isActive: false });
    } catch (error) {
      console.error('Error desactivando obra:', error);
      throw error;
    }
  }

  // Activar obra
  async activateWorksite(worksiteId: string): Promise<void> {
    try {
      await this.updateWorksite(worksiteId, { isActive: true });
    } catch (error) {
      console.error('Error activando obra:', error);
      throw error;
    }
  }

  // Verificar si el nombre ya existe
  async isNameExists(name: string, excludeId?: string): Promise<boolean> {
    try {
      const querySnapshot = await getDocs(collection(db, this.COLLECTION_NAME));

      const existingWorksite = querySnapshot.docs.find((doc) => {
        const data = doc.data() as Worksite;
        return data.name.toLowerCase() === name.toLowerCase() && doc.id !== excludeId;
      });

      return !!existingWorksite;
    } catch (error) {
      console.error('Error verificando nombre:', error);
      return false;
    }
  }

  // Calcular distancia entre dos puntos (útil para validaciones)
  calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371e3; // Radio de la Tierra en metros
    const φ1 = (lat1 * Math.PI) / 180;
    const φ2 = (lat2 * Math.PI) / 180;
    const Δφ = ((lat2 - lat1) * Math.PI) / 180;
    const Δλ = ((lon2 - lon1) * Math.PI) / 180;

    const a =
      Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
      Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c; // Distancia en metros
  }
}

export const worksitesService = new WorksitesService();
