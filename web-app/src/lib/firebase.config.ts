import { initializeApp } from 'firebase/app';
import { getAuth, type Auth } from 'firebase/auth';
import { getFirestore, Firestore } from 'firebase/firestore';

const firebaseConfig = {
  // tu configuración
  apiKey: 'tu_apiKey',
  authDomain: 'tu_authDomain',
  projectId: 'tu_projectId',
};

const app = initializeApp(firebaseConfig);
export const auth: Auth = getAuth(app);
export const db: Firestore = getFirestore(app);
