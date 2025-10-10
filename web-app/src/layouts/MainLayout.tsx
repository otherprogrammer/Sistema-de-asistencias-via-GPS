import { useState } from 'react';
import { Outlet, Link, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

const MainLayout: React.FC = () => {
  const { user, userData, logout } = useAuth();
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const location = useLocation();
  const navigate = useNavigate();

  const handleLogout = async () => {
    try {
      await logout();
      await navigate('/login');
    } catch (error) {
      console.error('Error al cerrar sesión:', error);
    }
  };

  const menuItems = [
    { path: '/gestion-trabajadores', label: 'Gestión de Trabajadores', icon: '📊' },
    { path: '/gestion-obras', label: 'Gestión de Obras', icon: '🏗️' },
    { path: '/registro-asistencias', label: 'Registro de Asistencias', icon: '📅' },
    { path: '/justificacion-asistencias', label: 'Justificación de Asistencias', icon: '✍️' },
  ];

  return (
    <div className="flex h-screen">
      {/* Sidebar */}
      <div
        className={`${
          sidebarOpen ? 'w-64' : 'w-16'
        } bg-[#2D6EA4] text-white transition-width duration-300 ease-in-out flex-shrink-0`}
      >
        {/* Header del sidebar */}
        <div className="flex flex-col items-center border-b border-[#245d8c]">
          {/* Logo siempre visible */}
          <div className="w-full flex items-center justify-center p-2">
            <img
              src="/logo-blanco.svg"
              alt="Logo"
              className={`${sidebarOpen ? 'h-24 w-auto' : 'h-12 w-auto'} transition-all duration-300`}
            />
          </div>

          {/* Título y botón de colapso */}
          <div className="w-full flex items-center justify-between px-4 pb-4">
            {sidebarOpen && (
              <h3 className="text-lg font-semibold">Panel Administración</h3>
            )}
            <button
              onClick={() => setSidebarOpen(!sidebarOpen)}
              className="text-white hover:bg-[#245d8c] p-2 rounded-lg transition-colors duration-200"
            >
              {sidebarOpen ? '◀' : '▶'}
            </button>
          </div>
        </div>

        {/* Menú de navegación */}
        <nav className="py-4">
          {menuItems.map((item) => (
            <Link
              key={item.path}
              to={item.path}
              className={`flex items-center px-4 py-3 text-sm ${
                sidebarOpen ? 'mx-2' : 'mx-1'
              } rounded-lg transition-colors duration-200 ${
                location.pathname === item.path
                  ? 'bg-white/10 text-white'
                  : 'text-white/80 hover:bg-white/5'
              }`}
            >
              <span className={`text-xl ${sidebarOpen ? 'mr-3' : 'mx-auto'}`}>
                {item.icon}
              </span>
              {sidebarOpen && <span className="font-medium">{item.label}</span>}
            </Link>
          ))}
        </nav>
      </div>

      {/* Contenido principal */}
      <div className="flex flex-col flex-1">
        {/* Header */}
        <header className="bg-white px-6 py-4 border-b border-gray-200 flex justify-end items-center shadow-sm">
          <div className="flex items-center space-x-4">
            <span className="text-gray-600">{userData?.fullName || user?.email}</span>
            <button
              onClick={() => void handleLogout()}
              className="px-4 py-2 bg-red-500 text-white rounded-lg hover:bg-red-600 transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2"
            >
              Cerrar Sesión
            </button>
          </div>
        </header>

        {/* Contenido de la página */}
        <main className="flex-1 p-6 bg-gray-50 overflow-auto">
          <Outlet />
        </main>
      </div>
    </div>
  );
};

export default MainLayout;
