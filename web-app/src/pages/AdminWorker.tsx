import { useEffect, useState } from 'react';
import type { UserData } from '../types';
import { workersService } from '../services/workersService';
import WorkerModal from '../components/WorkerModal';
import Loading from '../components/Loading';

const WorkersPage: React.FC = () => {
  const [workers, setWorkers] = useState<UserData[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [searchTerm, setSearchTerm] = useState('');
  const [filterRole, setFilterRole] = useState('all');

  // Modal states
  const [modalOpen, setModalOpen] = useState(false);
  const [modalMode, setModalMode] = useState<'create' | 'edit' | 'view'>('create');
  const [selectedWorker, setSelectedWorker] = useState<UserData | null>(null);

  // Undo state
  const [undoState, setUndoState] = useState<{ worker: UserData; timeoutId: NodeJS.Timeout } | null>(null);

  // Cargar trabajadores
  const loadWorkers = async () => {
    try {
      setLoading(true);
      const workersData = await workersService.getAllWorkers();
      setWorkers(workersData);
      setError('');
    } catch (error) {
      setError('Error cargando trabajadores: ' + (error as Error).message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadWorkers().catch((err) => setError('Error inesperado: ' + (err as Error).message));
  }, []);

  // Filtrar trabajadores
  const filteredWorkers = workers.filter((worker) => {
    // Solo mostrar trabajadores activos
    if (!worker.isActive) return false;

    const matchesSearch =
      worker.fullName.toLowerCase().includes(searchTerm.toLowerCase()) ||
      worker.dni.includes(searchTerm) ||
      worker.email.toLowerCase().includes(searchTerm.toLowerCase());

    const matchesRole = filterRole === 'all' || worker.role === filterRole;
    // Ya no filtramos por estado en la UI
    return matchesSearch && matchesRole;
  });

  // Handlers de modal
  const handleCreateWorker = () => {
    setSelectedWorker(null);
    setModalMode('create');
    setModalOpen(true);
  };

  const handleEditWorker = (worker: UserData) => {
    setSelectedWorker(worker);
    setModalMode('edit');
    setModalOpen(true);
  };

  const handleViewWorker = (worker: UserData) => {
    setSelectedWorker(worker);
    setModalMode('view');
    setModalOpen(true);
  };

  const handleSaveWorker = (worker: UserData) => {
    if (modalMode === 'create') {
      setWorkers((prev) => [worker, ...prev]);
    } else {
      setWorkers((prev) => prev.map((w) => (w.uid === worker.uid ? worker : w)));
    }
  };

  const handleDeleteWorker = (worker: UserData) => {
    // Mostrar confirmación
    const confirmed = window.confirm(
      `¿Está seguro que quiere eliminar a ${worker.fullName}? Esta acción se podrá deshacer durante 10 segundos.`,
    );

    if (!confirmed) return;

    try {
      // Limpiar timeout anterior si existe
      if (undoState) {
        clearTimeout(undoState.timeoutId);
      }

      // Eliminar de la UI inmediatamente
      setWorkers((prev) => prev.filter((w) => w.uid !== worker.uid));

      // Crear timeout para la eliminación permanente
      const timeoutId = setTimeout(() => {
        workersService.deactivateWorker(worker.uid)
          .catch((error) => {
            console.error('Error al deactivar trabajador:', error);
            // Re-agregar el trabajador si hay error
            setWorkers((prev) => {
              const exists = prev.some((w) => w.uid === worker.uid);
              if (!exists) {
                return [...prev, worker];
              }
              return prev;
            });
          });
        // Limpiar el estado de undo
        setUndoState(null);
      }, 10000); // 10 segundos

      // Guardar el estado de undo
      setUndoState({ worker, timeoutId });
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Error desconocido';
      alert('Error eliminando trabajador: ' + errorMessage);
      // Re-agregar el trabajador si hay error inmediato
      setWorkers((prev) => {
        const exists = prev.some((w) => w.uid === worker.uid);
        if (!exists) {
          return [...prev, worker];
        }
        return prev;
      });
    }
  };

  const handleUndoDelete = () => {
    if (!undoState) return;

    try {
      // Cancelar el timeout
      clearTimeout(undoState.timeoutId);

      // Re-agregar el trabajador a la lista
      setWorkers((prev) => {
        const exists = prev.some((w) => w.uid === undoState.worker.uid);
        if (!exists) {
          return [...prev, undoState.worker];
        }
        return prev;
      });

      // Limpiar el estado de undo
      setUndoState(null);
    } catch (error) {
      alert('Error al deshacer: ' + (error as Error).message);
    }
  };

  if (loading) {
    return (
      <Loading title="Cargando trabajadores" text="Obteniendo información de los trabajadores..." />
    );
  }

  return (
    <div className="space-y-6">
      <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-8 animate-slide-in-top">
        <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
          <div className="flex items-center space-x-4">
            <div>
              <h1 className="text-2xl font-bold text-gray-900 mb-2">Gestión de Trabajadores</h1>
              <p className="text-md text-gray-600">Administración del personal y sus roles</p>
            </div>
          </div>

          <button
            onClick={handleCreateWorker}
            className="bg-gradient-to-r from-[#2D6EA4] to-[#245d8c] text-white px-8 py-4 rounded-xl font-bold text-md shadow-lg hover:shadow-xl transform hover:scale-105 transition-all duration-200 flex items-center space-x-3"
          >
            <span>Nuevo Trabajador</span>
          </button>
        </div>
      </div>

      {error && (
        <div
          style={{
            color: '#e74c3c',
            backgroundColor: '#fadbd8',
            padding: '15px',
            borderRadius: '4px',
            marginBottom: '20px',
          }}
        >
          {error}
        </div>
      )}

      {/* Filtros y Resumen */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Buscar</label>
                <input
                  type="text"
                  placeholder="Nombre, DNI o email..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-[#2D6EA4] focus:border-[#2D6EA4] text-sm"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Rol</label>
                <select
                  value={filterRole}
                  onChange={(e) => setFilterRole(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-[#2D6EA4] focus:border-[#2D6EA4] text-sm"
                >
                  <option value="all">Todos</option>
                  <option value="trabajador">Trabajador</option>
                  <option value="admin">Administrador</option>
                </select>
              </div>
            </div>
          </div>

          {/* Resumen */}
          <div className="bg-gray-50 rounded-lg p-4">
            <div className="grid grid-cols-2 gap-4">
              <div className="text-center">
                <div className="text-sm font-medium text-gray-500">Total</div>
                <div className="mt-1 text-xl font-semibold text-gray-900">{workers.length}</div>
              </div>
              <div className="text-center">
                <div className="text-sm font-medium text-gray-500">Activos</div>
                <div className="mt-1 text-xl font-semibold text-green-600">
                  {workers.filter((w) => w.isActive).length}
                </div>
              </div>
              <div className="text-center">
                <div className="text-sm font-medium text-gray-500">Mostrando</div>
                <div className="mt-1 text-xl font-semibold text-[#2D6EA4]">{filteredWorkers.length}</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Tabla de trabajadores */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200">
        <div className="max-w-full overflow-x-auto">
          <div className="inline-block min-w-full align-middle">
            <table className="w-full divide-y divide-gray-200 table-fixed">
              <thead className="bg-gray-50">
                <tr>
                  <th className="w-[25%] px-3 py-4 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Nombre
                  </th>
                  <th className="x-3 py-4 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    DNI
                  </th>
                  <th className="px-3 py-4 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Email
                  </th>
                  <th className="px-3 py-4 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Rol
                  </th>
                  <th className="px-3 py-4 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Acciones
                  </th>
                </tr>
              </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {filteredWorkers.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-3 py-10 text-center text-gray-500 italic">
                    No se encontraron trabajadores
                  </td>
                </tr>
              ) : (
                filteredWorkers.map((worker) => (
                  <tr key={worker.uid} className="hover:bg-gray-50">
                    <td className="px-3 py-4 truncate">
                      <div className="text-sm font-medium text-gray-900">{worker.fullName}</div>
                    </td>
                    <td className="px-3 py-4 truncate">
                      <div className="text-sm text-gray-500">{worker.dni === '' ? '-' : worker.dni}</div>
                    </td>
                    <td className="px-3 py-4 truncate">
                      <div className="text-sm text-gray-500">{worker.email === '' ? '-' : worker.email}</div>
                    </td>
                    <td className="px-3 py-4 text-center">
                      <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium
                        ${
                          worker.role === 'manager'
                            ? 'bg-blue-100 text-blue-800'
                            : worker.role === 'supervisor'
                              ? 'bg-orange-100 text-orange-800'
                              : 'bg-purple-100 text-purple-800'
                        }`}
                      >
                        {worker.role}
                      </span>
                    </td>
                    <td className="px-3 py-4 text-center">
                      <div className="flex justify-center space-x-1">
                        <button
                          onClick={() => handleViewWorker(worker)}
                          className="inline-flex items-center px-2 py-1 border border-transparent text-xs font-medium rounded-lg text-[#2D6EA4] bg-[#2D6EA4]/10 hover:bg-[#2D6EA4]/20 transition-colors duration-200"
                        >
                          Ver
                        </button>
                        <button
                          onClick={() => handleEditWorker(worker)}
                          className="inline-flex items-center px-2 py-1 border border-transparent text-xs font-medium rounded-lg text-yellow-700 bg-yellow-100 hover:bg-yellow-200 transition-colors duration-200"
                        >
                          Editar
                        </button>
                        <button
                          onClick={() => handleDeleteWorker(worker)}
                          className="inline-flex items-center px-2 py-1 border border-transparent text-xs font-medium rounded-lg text-red-700 bg-red-100 hover:bg-red-200 transition-colors duration-200"
                        >
                          Eliminar
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal */}
      <WorkerModal
        isOpen={modalOpen}
        onClose={() => setModalOpen(false)}
        onSave={handleSaveWorker}
        worker={selectedWorker}
        mode={modalMode}
      />

      {/* Notificación de Undo */}
      {undoState && (
        <div className="fixed bottom-6 right-6 bg-gray-900 text-white px-6 py-4 rounded-lg shadow-xl flex items-center justify-between space-x-4 animate-slide-in-up max-w-sm">
          <div className="flex-1">
            <p className="text-sm font-medium">
              <span className="font-semibold">{undoState.worker.fullName}</span> ha sido eliminado.
            </p>
          </div>
          <button
            onClick={handleUndoDelete}
            className="ml-4 px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded-lg text-sm font-semibold transition-colors duration-200 whitespace-nowrap"
          >
            Deshacer
          </button>
        </div>
      )}
    </div>
  </div>
  );
};

export default WorkersPage;
