
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import ProtectedRoute from './components/ProtectedRoute';
import PublicRoute from './components/PublicRoute';
import MainLayout from './layouts/MainLayout';

import LoginPage from './pages/LoginPage';
import NotFoundPage from './pages/NotFoundPage';
import UsersPage from './pages/UsersPage';
import AdminWorkers from './pages/AdminWorker';

export const AppRouter = () => {
    return (
        <Router>
        <Routes>
          {/* Rutas públicas - Solo accesibles si NO está autenticado */}
          <Route
            path="/login"
            element={
              <PublicRoute>
                <LoginPage />
              </PublicRoute>
            }
          />

          {/* Rutas protegidas - Solo accesibles si está autenticado como admin */}
          <Route
            path="/"
            element={
              <ProtectedRoute>
                <MainLayout />
              </ProtectedRoute>
            }
          >
            {/* Rutas anidadas dentro del layout */}
            <Route index element={<AdminWorkers />} />
            <Route path="gestion-trabajadores" element={<AdminWorkers />} />
            <Route path="users" element={<UsersPage />} />
          </Route>

          {/* Ruta 404 */}
          <Route path="*" element={<NotFoundPage />} />
        </Routes>
      </Router>
    )
};