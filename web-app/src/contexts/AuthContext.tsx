import { createContext, useContext, useEffect, useState } from 'react';
import { type User, onAuthStateChanged, signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../lib/firebase.config';
import type { UserData } from '../types';

interface AuthContextType {
  user: User | null;
  userData: UserData | null;
  isAdmin: boolean;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

interface AuthProviderProps {
  children: React.ReactNode;
}

export const AuthProvider: React.FC<AuthProviderProps> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [userData, setUserData] = useState<UserData | null>(null);
  const [isAdmin, setIsAdmin] = useState<boolean>(false);
  const [loading, setLoading] = useState<boolean>(true);

  // Verificar rol de administrador
  const checkAdminRole = async (
    uid: string,
  ): Promise<{ isAdmin: boolean; userData: UserData | null }> => {
    try {
      const userDoc = await getDoc(doc(db, 'users', uid));

      if (userDoc.exists()) {
        const data = userDoc.data() as UserData;
        const isAdminUser = data.role === 'admin';

        return {
          isAdmin: isAdminUser,
          userData: data,
        };
      } else {
        return {
          isAdmin: false,
          userData: null,
        };
      }
    } catch (error) {
      console.error('Error verificando rol:', error);
      return {
        isAdmin: false,
        userData: null,
      };
    }
  };

  // Función de login
  const login = async (email: string, password: string): Promise<void> => {
    try {
      const result = await signInWithEmailAndPassword(auth, email, password);
      const { isAdmin: adminStatus } = await checkAdminRole(result.user.uid);

      if (!adminStatus) {
        await signOut(auth);
        throw new Error('Acceso denegado. Solo administradores pueden acceder.');
      }
    } catch (error) {
      console.error('Error en login:', error);
      throw error;
    }
  };

  // Función de logout
  const logout = async (): Promise<void> => {
    await signOut(auth);
    setUser(null);
    setUserData(null);
    setIsAdmin(false);
  };

  // Listener de cambios de autenticación
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (firebaseUser) => {
      if (firebaseUser) {
        // Usuario está autenticado, verificar rol
        checkAdminRole(firebaseUser.uid)
          .then(({ isAdmin, userData }) => {
            if (isAdmin && userData) {
              setUser(firebaseUser);
              setUserData(userData);
              setIsAdmin(true);
            } else {
              setUser(null);
              setUserData(null);
              setIsAdmin(false);
              // NO hacer signOut aquí porque crearía un bucle
            }
          })
          .catch((error) => {
            console.error('Error en onAuthStateChanged:', error);
            setUser(null);
            setUserData(null);
            setIsAdmin(false);
          });
      }
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const value: AuthContextType = {
    user,
    userData,
    isAdmin,
    loading,
    login,
    logout,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export const useAuth = (): AuthContextType => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
