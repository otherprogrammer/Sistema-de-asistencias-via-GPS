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
      navigate('/login');
    } catch (error) {
      console.error('Error al cerrar sesión:', error);
    }
  };

  const menuItems = [
    { path: '/gestion-trabajadores', label: 'Gestión de trabajadores', icon: '📊' },
    { path: '/gestion-obras', label: 'Gestión de Obras', icon: '🏗️' },
  ];

  return (
    <div style={{ display: 'flex', height: '100vh' }}>
      {/* Sidebar */}
      <div
        style={{
          width: sidebarOpen ? '250px' : '60px',
          backgroundColor: '#2c3e50',
          color: 'white',
          transition: 'width 0.3s ease',
          flexShrink: 0,
        }}
      >
        {/* Header del sidebar */}
        <div
          style={{
            padding: '16px',
            borderBottom: '1px solid #34495e',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
          }}
        >
          {sidebarOpen && <h3 style={{ margin: 0, fontSize: '18px' }}>Panel de Administración</h3>}
          <button
            onClick={() => setSidebarOpen(!sidebarOpen)}
            style={{
              background: 'none',
              border: 'none',
              color: 'white',
              fontSize: '20px',
              cursor: 'pointer',
            }}
          >
            {sidebarOpen ? '◀' : '▶'}
          </button>
        </div>

        {/* Menú de navegación */}
        <nav style={{ padding: '20px 0' }}>
          {menuItems.map((item) => (
            <Link
              key={item.path}
              to={item.path}
              style={{
                display: 'flex',
                alignItems: 'center',
                padding: '12px 20px',
                color: location.pathname === item.path ? '#3498db' : 'white',
                textDecoration: 'none',
                backgroundColor:
                  location.pathname === item.path ? 'rgba(52, 152, 219, 0.1)' : 'transparent',
                borderLeft:
                  location.pathname === item.path ? '3px solid #3498db' : '3px solid transparent',
              }}
            >
              <span style={{ marginRight: sidebarOpen ? '10px' : '0', fontSize: '18px' }}>
                {item.icon}
              </span>
              {sidebarOpen && <span>{item.label}</span>}
            </Link>
          ))}
        </nav>
      </div>

      {/* Contenido principal */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
        {/* Header */}
        <header
          style={{
            backgroundColor: 'white',
            padding: '15px 30px',
            borderBottom: '1px solid #e0e0e0',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
          }}
        >
          <h1 style={{ margin: 0, fontSize: '24px', color: '#2c3e50' }}>
            {menuItems.find((item) => item.path === location.pathname)?.label ||
              'Gestión de Trabajadores'}
          </h1>

          <div style={{ display: 'flex', alignItems: 'center', gap: '15px' }}>
            <span style={{ color: '#666' }}>{userData?.fullName || user?.email}</span>
            <button
              onClick={handleLogout}
              style={{
                padding: '8px 16px',
                backgroundColor: '#e74c3c',
                color: 'white',
                border: 'none',
                borderRadius: '4px',
                cursor: 'pointer',
              }}
            >
              Cerrar Sesión
            </button>
          </div>
        </header>

        {/* Contenido de la página */}
        <main
          style={{
            flex: 1,
            padding: '30px',
            backgroundColor: '#f8f9fa',
            overflow: 'auto',
          }}
        >
          <Outlet />
        </main>
      </div>
    </div>
  );
};

export default MainLayout;
