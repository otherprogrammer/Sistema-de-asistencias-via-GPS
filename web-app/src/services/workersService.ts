import {
  collection,
  doc,
  getDocs,
  getDoc,
  setDoc,
  updateDoc,
  query,
  where,
  orderBy,
  serverTimestamp,
} from 'firebase/firestore';
import { createUserWithEmailAndPassword } from 'firebase/auth';
import { db, createAuth } from '../lib/firebase.config';
import type { UserData, CreateWorkerData } from '../types';

export class WorkersService {
  private readonly COLLECTION_NAME = 'users';

  // Obtener todos los trabajadores
  async getAllWorkers(): Promise<UserData[]> {
    try {
      const workersQuery = query(
        collection(db, this.COLLECTION_NAME),
        orderBy('role'),
        orderBy('fullName'),
      );

      const querySnapshot = await getDocs(workersQuery);
      return querySnapshot.docs.map((doc) => doc.data() as UserData);
    } catch (error) {
      console.error('Error obteniendo trabajadores:', error);
      throw error;
    }
  }

  // Obtener trabajador por ID
  async getWorkerById(uid: string): Promise<UserData | null> {
    try {
      const docRef = doc(db, this.COLLECTION_NAME, uid);
      const docSnap = await getDoc(docRef);

      if (docSnap.exists()) {
        return docSnap.data() as UserData;
      }
      return null;
    } catch (error) {
      console.error('Error obteniendo trabajador:', error);
      throw error;
    }
  }

  // Crear trabajador
  async createWorker(workerData: CreateWorkerData): Promise<UserData> {
    try {
      workerData.email = workerData.email ?? `${workerData.dni}@crellat.com`;

      // 1. Crear usuario en Firebase Auth
      const userCredential = await createUserWithEmailAndPassword(
        createAuth,
        workerData.email,
        workerData.password,
      );

      // 2. Crear documento en Firestore
      const userData: UserData = {
        uid: userCredential.user.uid,
        role: workerData.role || 'trabajador',
        email: workerData.email,
        dni: workerData.dni,
        fullName: workerData.fullName,
        assignedWorksiteId: '',
        isActive: true,
        /* createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(), */
      };

      await setDoc(doc(db, this.COLLECTION_NAME, userCredential.user.uid), userData).catch((e) =>
        console.log(e),
      );

      return userData;
    } catch (error) {
      console.error('Error creando trabajador:', error);
      throw error;
    }
  }

  // Actualizar trabajador
  async updateWorker(uid: string, updates: Partial<UserData>): Promise<void> {
    try {
      const docRef = doc(db, this.COLLECTION_NAME, uid);
      await updateDoc(docRef, {
        ...updates,
        updatedAt: serverTimestamp(),
      });
    } catch (error) {
      console.error('Error actualizando trabajador:', error);
      throw error;
    }
  }

  // Desactivar trabajador (soft delete)
  async deactivateWorker(uid: string): Promise<void> {
    try {
      await this.updateWorker(uid, { isActive: false });
    } catch (error) {
      console.error('Error desactivando trabajador:', error);
      throw error;
    }
  }

  // Activar trabajador
  async activateWorker(uid: string): Promise<void> {
    try {
      await this.updateWorker(uid, { isActive: true });
    } catch (error) {
      console.error('Error activando trabajador:', error);
      throw error;
    }
  }

  // Verificar si el DNI ya existe
  async isDniExists(dni: string, excludeUid?: string): Promise<boolean> {
    try {
      const q = query(collection(db, this.COLLECTION_NAME), where('dni', '==', dni));

      const querySnapshot = await getDocs(q);

      if (excludeUid) {
        return querySnapshot.docs.some((doc) => doc.id !== excludeUid);
      }

      return !querySnapshot.empty;
    } catch (error) {
      console.error('Error verificando DNI:', error);
      return false;
    }
  }
}

export const workersService = new WorkersService();
