import { initializeApp } from 'firebase/app';
import { getAuth, type Auth } from 'firebase/auth';
import { getFirestore, Firestore } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: 'sistema-asistencia-gps.firebaseapp.com',
  projectId: 'sistema-asistencia-gps',
  storageBucket: 'sistema-asistencia-gps.firebasestorage.app',
  messagingSenderId: '211804314703',
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
};

const app = initializeApp(firebaseConfig);
const createUserApp = initializeApp(firebaseConfig, 'createUserApp');
export const auth: Auth = getAuth(app);
export const createAuth: Auth = getAuth(createUserApp);
export const db: Firestore = getFirestore(app);
