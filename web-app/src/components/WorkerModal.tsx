import { useState, useEffect } from 'react';
import type { UserData, CreateWorkerData } from '../types';
import { workersService } from '../services/workersService';

interface WorkerModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSave: (worker: UserData) => void;
  worker?: UserData | null;
  mode: 'create' | 'edit' | 'view';
}

const WorkerModal: React.FC<WorkerModalProps> = ({ isOpen, onClose, onSave, worker, mode }) => {
  const [formData, setFormData] = useState({
    email: '',
    password: '',
    dni: '',
    fullName: '',
    role: 'trabajador',
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [isClosing, setIsClosing] = useState(false);

  // Manejar animaciones de cierre
  const handleClose = () => {
    setIsClosing(true);
    setTimeout(() => {
      setIsClosing(false);
      onClose();
    }, 200);
  };

  useEffect(() => {
    if (worker && (mode === 'edit' || mode === 'view')) {
      setFormData({
        email: worker.email,
        password: '', // No mostrar password existente
        dni: worker.dni,
        fullName: worker.fullName,
        role: worker.role,
      });
    } else {
      setFormData({
        email: '',
        password: '',
        dni: '',
        fullName: '',
        role: 'trabajador',
      });
    }
    setError('');
  }, [worker, mode, isOpen]);

  const handleSubmit = async () => {
    setError('');
    setLoading(true);

    try {
      // Validaciones
      console.log(formData.role !== 'trabajador' && !formData.email);
      if (
        !formData.fullName ||
        (formData.role === 'trabajador' && !formData.dni) ||
        (formData.role === 'admin' && !formData.email)
      ) {
        throw new Error('Todos los campos son obligatorios');
      }

      if (mode === 'create' && !formData.password) {
        throw new Error('La contraseña es obligatoria');
      }

      if (formData.role === 'trabajador') {
        // Verificar DNI único para trabajadores
        const dniExists = await workersService.isDniExists(
          formData.dni,
          mode === 'edit' ? worker?.uid : undefined,
        );

        if (dniExists) {
          throw new Error('Ya existe un trabajador con este DNI');
        }
      }

      let savedWorker: UserData;

      if (mode === 'create') {
        savedWorker = await workersService.createWorker(formData as CreateWorkerData);
      } else if (mode === 'edit' && worker) {
        await workersService.updateWorker(worker.uid, {
          email: formData.email,
          dni: formData.dni,
          fullName: formData.fullName,
          role: formData.role,
        });
        savedWorker = { ...worker, ...formData };
      } else {
        return;
      }

      onSave(savedWorker);
      handleClose();
    } catch (error) {
      setError((error as Error).message);
    } finally {
      setLoading(false);
    }
  };

  if (!isOpen) return null;

  const isReadOnly = mode === 'view';
  const isCreate = mode === 'create';

  return (
    <div
      className={`fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4 transition-all duration-200 ${
        isClosing ? 'animate-fade-out' : 'animate-fade-in'
      }`}
      onClick={handleClose} // Cerrar al hacer click fuera
    >
      <div
        className={`bg-white rounded-2xl shadow-2xl w-full max-w-md max-h-[95vh] overflow-hidden transition-all duration-300 ${
          isClosing
            ? 'animate-scale-out animate-slide-out-bottom'
            : 'animate-scale-in animate-slide-in-bottom'
        }`}
        onClick={(e) => e.stopPropagation()} // Evitar cerrar al hacer click en el modal
      >
        <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md max-h-[95vh] overflow-hidden animate-in slide-in-from-bottom-4 duration-300">
          {/* Header */}
          <div className="flex items-center justify-between p-6 border-b border-gray-200 bg-gradient-to-r from-primary-500 to-primary-600 relative overflow-hidden">
            <div className="flex items-center space-x-3">
              <div className="w-8 h-8 bg-white bg-opacity-20 rounded-full flex items-center justify-center">
                {mode === 'create' ? '👤' : mode === 'edit' ? '✏️' : '👁️'}
              </div>
              <h2 className="text-xl font-bold text-white">
                {mode === 'create'
                  ? 'Crear Trabajador'
                  : mode === 'edit'
                    ? 'Editar Trabajador'
                    : 'Ver Trabajador'}
              </h2>
            </div>

            <button
              onClick={handleClose}
              className="text-white hover:text-gray-200 transition-colors duration-200 p-1 rounded-full hover:bg-white hover:bg-opacity-10"
              disabled={loading}
            >
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>

          {/* Content */}
          <div className="p-6 max-h-[calc(90vh-130px)] overflow-y-auto">
            {/* Error Message */}
            {error && (
              <div className="mb-6 p-4 bg-danger-50 border border-danger-200 rounded-lg flex items-start space-x-3 animate-in slide-in-from-top-2 duration-200">
                <div className="flex-shrink-0">
                  <svg
                    className="w-5 h-5 text-danger-500 mt-0.5"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"
                    />
                  </svg>
                </div>
                <div>
                  <h3 className="text-sm font-medium text-danger-800">Error</h3>
                  <p className="text-sm text-danger-700 mt-1">{error}</p>
                </div>
              </div>
            )}

            {/* Form Fields */}
            <div className="space-y-5">
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2">
                  Nombre Completo *
                </label>
                <input
                  type="text"
                  value={formData.fullName}
                  onChange={(e) => setFormData({ ...formData, fullName: e.target.value })}
                  disabled={isReadOnly || loading}
                  placeholder="Juan Pérez García"
                  className={`w-full px-4 py-3 border rounded-lg transition-all duration-200 ${
                    isReadOnly || loading
                      ? 'bg-gray-50 border-gray-200 text-gray-500 cursor-not-allowed'
                      : 'border-gray-300 focus:border-primary-500 focus:ring-2 focus:ring-primary-500 focus:ring-opacity-20'
                  }`}
                />
              </div>

              {/* DNI */}
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2">DNI *</label>
                <input
                  type="text"
                  value={formData.dni}
                  onChange={(e) => setFormData({ ...formData, dni: e.target.value })}
                  disabled={isReadOnly || loading}
                  placeholder="12345678"
                  maxLength={8}
                  className={`w-full px-4 py-3 border rounded-lg transition-all duration-200 ${
                    isReadOnly || loading
                      ? 'bg-gray-50 border-gray-200 text-gray-500 cursor-not-allowed'
                      : 'border-gray-300 focus:border-primary-500 focus:ring-2 focus:ring-primary-500 focus:ring-opacity-20'
                  }`}
                />
              </div>

              {/* Email */}
              {(formData.role === 'admin' || mode === 'edit') && (
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">Email *</label>
                  <input
                    type="email"
                    value={formData.email}
                    onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                    disabled={isReadOnly || loading}
                    placeholder="trabajador@empresa.com"
                    className={`w-full px-4 py-3 border rounded-lg transition-all duration-200 ${
                      isReadOnly || loading
                        ? 'bg-gray-50 border-gray-200 text-gray-500 cursor-not-allowed'
                        : 'border-gray-300 focus:border-primary-500 focus:ring-2 focus:ring-primary-500 focus:ring-opacity-20'
                    }`}
                  />
                </div>
              )}

              {/* Contraseña Initial (solo en crear) */}
              {isCreate && (
                <div>
                  <label className="block text-sm font-semibold text-gray-700 mb-2">
                    Contraseña Inicial *
                  </label>
                  <input
                    type="password"
                    value={formData.password}
                    onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                    disabled={loading}
                    placeholder="••••••••"
                    className={`w-full px-4 py-3 border rounded-lg transition-all duration-200 ${
                      loading
                        ? 'bg-gray-50 border-gray-200 cursor-not-allowed'
                        : 'border-gray-300 focus:border-primary-500 focus:ring-2 focus:ring-primary-500 focus:ring-opacity-20'
                    }`}
                  />
                  <p className="text-xs text-gray-500 mt-1">
                    El trabajador deberá cambiar esta contraseña en su primer acceso
                  </p>
                </div>
              )}

              {/* Rol */}
              <div>
                <label className="block text-sm font-semibold text-gray-700 mb-2">Rol</label>
                <select
                  value={formData.role}
                  onChange={(e) => setFormData({ ...formData, role: e.target.value })}
                  disabled={isReadOnly || loading}
                  className={`w-full px-4 py-3 border rounded-lg transition-all duration-200 ${
                    isReadOnly || loading
                      ? 'bg-gray-50 border-gray-200 text-gray-500 cursor-not-allowed'
                      : 'border-gray-300 focus:border-primary-500 focus:ring-2 focus:ring-primary-500 focus:ring-opacity-20'
                  }`}
                >
                  <option value="trabajador">Trabajador</option>
                  <option value="admin">Administrador</option>
                </select>
              </div>

              {/* Información adicional (solo en edit/view) */}
              {(mode === 'edit' || mode === 'view') && worker && (
                <div className="bg-gray-50 border border-gray-200 rounded-lg p-4 space-y-2">
                  <h4 className="text-sm font-semibold text-gray-700 mb-3">
                    📋 Información del Sistema
                  </h4>

                  <div className="flex items-center justify-between">
                    <span className="text-sm text-gray-600">Estado:</span>
                    <span
                      className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium ${
                        worker.isActive
                          ? 'bg-success-100 text-success-800'
                          : 'bg-danger-100 text-danger-800'
                      }`}
                    >
                      {worker.isActive ? '✅ Activo' : '❌ Inactivo'}
                    </span>
                  </div>

                  <div className="flex items-center justify-between">
                    <span className="text-sm text-gray-600">Sitio Asignado:</span>
                    <span className="text-sm text-gray-900">
                      {worker.assignedWorksiteId || 'Sin asignar'}
                    </span>
                  </div>

                  <div className="flex items-center justify-between">
                    <span className="text-sm text-gray-600">UID:</span>
                    <span className="text-xs text-gray-500 font-mono bg-gray-100 px-2 py-1 rounded">
                      {worker.uid.substring(0, 8)}...
                    </span>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Footer/Actions */}
          {!isReadOnly && (
            <div className="flex items-center justify-end space-x-3 p-6 bg-gray-50 border-t border-gray-200">
              <button
                onClick={handleClose}
                disabled={loading}
                className="px-6 py-2.5 text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-opacity-20 transition-all duration-200 font-medium disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Cancelar
              </button>

              <button
                onClick={() => {
                  handleSubmit();
                }}
                disabled={loading}
                className={`px-6 py-2.5 text-white rounded-lg font-medium transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:ring-opacity-20 disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2 ${
                  loading
                    ? 'bg-gray-400 cursor-not-allowed'
                    : 'bg-primary-500 hover:bg-primary-600 active:bg-primary-700'
                }`}
              >
                {loading && (
                  <svg
                    className="animate-spin -ml-1 mr-2 h-4 w-4 text-white"
                    fill="none"
                    viewBox="0 0 24 24"
                  >
                    <circle
                      className="opacity-25"
                      cx="12"
                      cy="12"
                      r="10"
                      stroke="currentColor"
                      strokeWidth="4"
                    ></circle>
                    <path
                      className="opacity-75"
                      fill="currentColor"
                      d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                    ></path>
                  </svg>
                )}
                <span>{loading ? 'Guardando...' : isCreate ? 'Crear' : 'Guardar'}</span>
              </button>
            </div>
          )}

          {/* Footer para modo View */}
          {isReadOnly && (
            <div className="flex justify-end p-6 bg-gray-50 border-t border-gray-200">
              <button
                onClick={handleClose}
                className="px-6 py-2.5 text-white bg-primary-500 rounded-lg hover:bg-primary-600 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:ring-opacity-20 transition-all duration-200 font-medium"
              >
                Cerrar
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default WorkerModal;
