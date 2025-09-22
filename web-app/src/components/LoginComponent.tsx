import React, { useState, useEffect } from 'react';
import {
  /* signInWithEmailAndPassword,
  signOut,
  onAuthStateChanged, */
  type User,
} from 'firebase/auth';
import { /* doc, getDoc, */ DocumentSnapshot } from 'firebase/firestore';
import { auth } from '../lib/firebase.config';
import { type UserData } from '../types';

interface LoginComponentProps {
  onLoginSuccess?: (user: User) => void;
  onLogout?: () => void;
}

const LoginComponent: React.FC<LoginComponentProps> = ({ onLoginSuccess, onLogout }) => {
  const [email, setEmail] = useState<string>('');
  const [password, setPassword] = useState<string>('');
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string>('');
  const [isAdmin, setIsAdmin] = useState<boolean>(false);
  const [loginLoading, setLoginLoading] = useState<boolean>(false);

  // TODO: Reemplazar con importaciones reales
  const signIn = async (email: string, password: string): Promise<{ user: User }> => {
    // signInWithEmailAndPassword(auth, email, password)
    if (email === 'admin@test.com' && password === 'password') {
      const mockUser = {
        uid: 'mock-uid',
        email,
        displayName: 'Admin User',
      } as User;
      return { user: mockUser };
    }
    throw new Error('Credenciales incorrectas');
  };

  const getDoc = async (/* userRef: any */): Promise<DocumentSnapshot<UserData>> => {
    // getDoc(doc(db, 'users', uid))
    return {
      exists: () => true,
      data: (): UserData => ({ role: 'admin', email: 'admin@test.com' }),
    } as DocumentSnapshot<UserData>;
  };

  const signOut = async (): Promise<void> => {
    //signOut(auth)
    return Promise.resolve();
  };

  // Verificar si el usuario es administrador
  const checkAdminRole = async (uid: string): Promise<boolean> => {
    try {
      // const userDoc = await getDoc(doc(db, 'users', uid));
      const userDoc = await getDoc();

      if (userDoc.exists()) {
        const userData = userDoc.data();
        return userData?.role === 'admin';
      }
      return false;
    } catch (error) {
      console.error('Error verificando rol:', error);
      return false;
    }
  };

  // Manejar el estado de autenticación
  useEffect(() => {
    const unsubscribe = auth.onAuthStateChanged(async (user: User | null) => {
      if (user) {
        const adminStatus = await checkAdminRole(user.uid);
        if (adminStatus) {
          setUser(user);
          setIsAdmin(true);
          setError('');
          onLoginSuccess?.(user);
        } else {
          setError('Acceso denegado. Solo administradores pueden acceder.');
          await handleLogout();
        }
      } else {
        setUser(null);
        setIsAdmin(false);
      }
      setLoading(false);
    });

    return () => unsubscribe();
  }, [onLoginSuccess]);

  // Manejar inicio de sesión
  const handleLogin = async (): Promise<void> => {
    if (!email || !password) {
      setError('Por favor ingresa email y contraseña');
      return;
    }

    setError('');
    setLoginLoading(true);

    try {
      const result = await signIn(email, password); // signInWithEmailAndPassword(auth, email, password)
      onLoginSuccess?.(result.user);
      // La verificación de rol se hará automáticamente en el useEffect
    } catch (error) {
      setError(`Error al iniciar sesión: ${error.message || 'Error desconocido'}`);
    } finally {
      setLoginLoading(false);
    }
  };

  // Manejar cierre de sesión
  const handleLogout = async (): Promise<void> => {
    try {
      await signOut();
      setUser(null);
      setIsAdmin(false);
      setEmail('');
      setPassword('');
      onLogout?.();
    } catch (error) {
      setError('Error al cerrar sesión');
      console.error('Logout error:', error);
    }
  };

  // Manejar tecla Enter
  const handleKeyPress = (event: React.KeyboardEvent): void => {
    if (event.key === 'Enter') {
      handleLogin();
    }
  };

  // Mostrar loading
  // TODO: Reemplazar con componente de carga
  if (loading) {
    return (
      <div style={{ textAlign: 'center', padding: '20px' }}>
        <p>Cargando...</p>
      </div>
    );
  }

  // Si el usuario está autenticado y es admin, mostrar dashboard
  if (user && isAdmin) {
    return (
      <div style={{ padding: '20px' }}>
        <div style={{ marginBottom: '20px', textAlign: 'center' }}>
          <h2>Panel de Administrador</h2>
          <p>Bienvenido, {user.email}</p>
          <p style={{ fontSize: '14px', color: '#666' }}>UID: {user.uid}</p>
          <button
            onClick={handleLogout}
            style={{
              padding: '10px 20px',
              backgroundColor: '#f44336',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              cursor: 'pointer',
              fontSize: '14px',
            }}
          >
            Cerrar Sesión
          </button>
        </div>

        <div style={{ textAlign: 'center' }}>
          <h3>Dashboard del Administrador</h3>
          <p>Aquí va el contenido de tu aplicación para administradores</p>
        </div>
      </div>
    );
  }

  // Mostrar formulario de login
  return (
    <div
      style={{
        maxWidth: '400px',
        margin: '50px auto',
        padding: '20px',
        border: '1px solid #ccc',
        borderRadius: '8px',
      }}
    >
      <h2 style={{ textAlign: 'center', marginBottom: '20px' }}>Iniciar Sesión - Admin</h2>

      {error && (
        <div
          style={{
            color: '#d32f2f',
            marginBottom: '15px',
            padding: '10px',
            backgroundColor: '#ffebee',
            borderRadius: '4px',
            textAlign: 'center',
            fontSize: '14px',
            border: '1px solid #ffcdd2',
          }}
        >
          {error}
        </div>
      )}

      <div>
        <div style={{ marginBottom: '15px' }}>
          <div style={{ display: 'block', marginBottom: '5px', fontWeight: '500' }}>Email:</div>
          <input
            type="email"
            value={email}
            onChange={(e: React.ChangeEvent<HTMLInputElement>) => setEmail(e.target.value)}
            onKeyDown={handleKeyPress}
            placeholder="admin@ejemplo.com"
            style={{
              width: '100%',
              padding: '10px',
              border: '1px solid #ccc',
              borderRadius: '4px',
              fontSize: '16px',
              boxSizing: 'border-box',
            }}
          />
        </div>

        <div style={{ marginBottom: '20px' }}>
          <div style={{ display: 'block', marginBottom: '5px', fontWeight: '500' }}>
            Contraseña:
          </div>
          <input
            type="password"
            value={password}
            onChange={(e: React.ChangeEvent<HTMLInputElement>) => setPassword(e.target.value)}
            onKeyDown={handleKeyPress}
            placeholder="••••••••"
            style={{
              width: '100%',
              padding: '10px',
              border: '1px solid #ccc',
              borderRadius: '4px',
              fontSize: '16px',
              boxSizing: 'border-box',
            }}
          />
        </div>

        <button
          onClick={handleLogin}
          disabled={loginLoading || !email || !password}
          style={{
            width: '100%',
            padding: '12px',
            backgroundColor: loginLoading || !email || !password ? '#ccc' : '#4CAF50',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            fontSize: '16px',
            cursor: loginLoading || !email || !password ? 'not-allowed' : 'pointer',
            transition: 'background-color 0.2s',
          }}
        >
          {loginLoading ? 'Iniciando sesión...' : 'Iniciar Sesión'}
        </button>
      </div>

      <div
        style={{
          marginTop: '20px',
          padding: '10px',
          backgroundColor: '#f5f5f5',
          borderRadius: '4px',
          fontSize: '12px',
          color: '#666',
        }}
      >
        <strong>Demo:</strong> Use admin@test.com / password para probar
      </div>
    </div>
  );
};

export default LoginComponent;
