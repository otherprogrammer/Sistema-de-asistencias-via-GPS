import { useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

const LoginPage: React.FC = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const { login } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  // Obtener la página desde donde vino (si fue redirigido)
  const from = location.pathname || '/dashboard';

  const handleLogin = async () => {
    if (!email || !password) {
      setError('Por favor, ingrese email y contraseña');
      return;
    }

    setError('');
    setLoading(true);

    try {
      await login(email, password);
      void navigate(from, { replace: true });
    } catch (error) {
      setError((error as Error).message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-gray-50 px-4 py-12 sm:px-6 lg:px-8">
      <div className="w-full max-w-md space-y-8">
        <div>
          <img
            className="mx-auto h-52 w-auto"
            src="/logo.svg"
            alt="Logo de la empresa"
          />
          <h2 className="mt-6 text-center text-3xl font-bold tracking-tight text-gray-900">
            Iniciar Sesión
          </h2>
        </div>

        {error && (
          <div className="rounded-md bg-red-50 p-4">
            <div className="text-center text-sm font-medium text-red-800">
              {error}
            </div>
          </div>
        )}

        <div className="mt-8 space-y-6">
          <div className="space-y-4 rounded-md shadow-sm">
            <div>
              <input
                type="email"
                placeholder="Email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="relative block w-full appearance-none rounded-md border border-gray-300 px-3 py-2 text-gray-900 placeholder-gray-500 focus:z-10 focus:border-[#2D6EA4] focus:outline-none focus:ring-[#2D6EA4] sm:text-sm"
              />
            </div>
            <div>
              <input
                type="password"
                placeholder="Contraseña"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                onKeyDown={(e) => { if (e.key === 'Enter') void handleLogin(); }}
                className="relative block w-full appearance-none rounded-md border border-gray-300 px-3 py-2 text-gray-900 placeholder-gray-500 focus:z-10 focus:border-[#2D6EA4] focus:outline-none focus:ring-[#2D6EA4] sm:text-sm"
              />
            </div>
          </div>

          <div>
            <button
              onClick={() => { void handleLogin(); }}
              disabled={loading || !email || !password}
              className={`group relative flex w-full justify-center rounded-md border border-transparent py-2 px-4 text-sm font-medium text-white focus:outline-none focus:ring-2 focus:ring-[#2D6EA4] focus:ring-offset-2
                ${loading || !email || !password
                  ? 'bg-gray-400 cursor-not-allowed'
                  : 'bg-[#2D6EA4] hover:bg-[#245d8c] cursor-pointer'
                }`}
            >
              {loading ? 'Iniciando sesión...' : 'Iniciar Sesión'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default LoginPage;
