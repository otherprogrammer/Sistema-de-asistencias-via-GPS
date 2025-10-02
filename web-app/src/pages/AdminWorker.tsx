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
  const [filterStatus, setFilterStatus] = useState('all');

  // Modal states
  const [modalOpen, setModalOpen] = useState(false);
  const [modalMode, setModalMode] = useState<'create' | 'edit' | 'view'>('create');
  const [selectedWorker, setSelectedWorker] = useState<UserData | null>(null);

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
    const matchesSearch =
      worker.fullName.toLowerCase().includes(searchTerm.toLowerCase()) ||
      worker.dni.includes(searchTerm) ||
      worker.email.toLowerCase().includes(searchTerm.toLowerCase());

    const matchesRole = filterRole === 'all' || worker.role === filterRole;
    const matchesStatus =
      filterStatus === 'all' ||
      (filterStatus === 'active' && worker.isActive) ||
      (filterStatus === 'inactive' && !worker.isActive);

    return matchesSearch && matchesRole && matchesStatus;
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

  const handleToggleStatus = async (worker: UserData) => {
    try {
      if (worker.isActive) {
        await workersService.deactivateWorker(worker.uid);
      } else {
        await workersService.activateWorker(worker.uid);
      }

      setWorkers((prev) =>
        prev.map((w) => (w.uid === worker.uid ? { ...w, isActive: !w.isActive } : w)),
      );
    } catch (error) {
      alert('Error cambiando estado: ' + (error as Error).message);
    }
  };

  if (loading) {
    return (
      <Loading title="Cargando trabajadores" text="Obteniendo información de los trabajadores..." />
    );
  }

  return (
    <div>
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '25px',
        }}
      >
        <h1>Gestión de Trabajadores</h1>
        <button
          onClick={handleCreateWorker}
          style={{
            padding: '10px 20px',
            backgroundColor: '#28a745',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer',
            fontSize: '14px',
          }}
        >
          + Crear Trabajador
        </button>
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

      {/* Filtros */}
      <div
        style={{
          backgroundColor: 'white',
          padding: '20px',
          borderRadius: '8px',
          marginBottom: '20px',
          display: 'grid',
          gridTemplateColumns: '2fr 1fr 1fr',
          gap: '15px',
          alignItems: 'end',
        }}
      >
        <div>
          <label style={{ display: 'block', marginBottom: '5px', fontWeight: '500' }}>Buscar</label>
          <input
            type="text"
            placeholder="Nombre, DNI o email..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            style={{
              width: '100%',
              padding: '8px',
              border: '1px solid #ddd',
              borderRadius: '4px',
            }}
          />
        </div>

        <div>
          <label style={{ display: 'block', marginBottom: '5px', fontWeight: '500' }}>Rol</label>
          <select
            value={filterRole}
            onChange={(e) => setFilterRole(e.target.value)}
            style={{
              width: '100%',
              padding: '8px',
              border: '1px solid #ddd',
              borderRadius: '4px',
            }}
          >
            <option value="all">Todos</option>
            <option value="trabajador">Trabajador</option>
            <option value="admin">Administrador</option>
          </select>
        </div>

        <div>
          <label style={{ display: 'block', marginBottom: '5px', fontWeight: '500' }}>Estado</label>
          <select
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value)}
            style={{
              width: '100%',
              padding: '8px',
              border: '1px solid #ddd',
              borderRadius: '4px',
            }}
          >
            <option value="all">Todos</option>
            <option value="active">Activos</option>
            <option value="inactive">Inactivos</option>
          </select>
        </div>
      </div>

      {/* Resumen */}
      <div
        style={{
          backgroundColor: 'white',
          padding: '15px',
          borderRadius: '8px',
          marginBottom: '20px',
          display: 'flex',
          gap: '30px',
          fontSize: '14px',
        }}
      >
        <span>
          <strong>Total:</strong> {workers.length}
        </span>
        <span>
          <strong>Activos:</strong> {workers.filter((w) => w.isActive).length}
        </span>
        <span>
          <strong>Inactivos:</strong> {workers.filter((w) => !w.isActive).length}
        </span>
        <span>
          <strong>Mostrando:</strong> {filteredWorkers.length}
        </span>
      </div>

      {/* Tabla de trabajadores */}
      <div
        style={{
          backgroundColor: 'white',
          borderRadius: '8px',
          overflow: 'hidden',
        }}
      >
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead style={{ backgroundColor: '#f8f9fa' }}>
            <tr>
              <th style={{ padding: '15px', textAlign: 'left', borderBottom: '1px solid #dee2e6' }}>
                Nombre
              </th>
              <th style={{ padding: '15px', textAlign: 'left', borderBottom: '1px solid #dee2e6' }}>
                DNI
              </th>
              <th style={{ padding: '15px', textAlign: 'left', borderBottom: '1px solid #dee2e6' }}>
                Email
              </th>
              <th
                style={{ padding: '15px', textAlign: 'center', borderBottom: '1px solid #dee2e6' }}
              >
                Rol
              </th>
              <th
                style={{ padding: '15px', textAlign: 'center', borderBottom: '1px solid #dee2e6' }}
              >
                Estado
              </th>
              <th
                style={{ padding: '15px', textAlign: 'center', borderBottom: '1px solid #dee2e6' }}
              >
                Acciones
              </th>
            </tr>
          </thead>
          <tbody>
            {filteredWorkers.length === 0 ? (
              <tr>
                <td
                  colSpan={6}
                  style={{
                    padding: '30px',
                    textAlign: 'center',
                    color: '#666',
                    fontStyle: 'italic',
                  }}
                >
                  No se encontraron trabajadores
                </td>
              </tr>
            ) : (
              filteredWorkers.map((worker) => (
                <tr key={worker.uid}>
                  <td style={{ padding: '15px', borderBottom: '1px solid #dee2e6' }}>
                    <strong>{worker.fullName}</strong>
                  </td>
                  <td style={{ padding: '15px', borderBottom: '1px solid #dee2e6' }}>
                    {worker.dni}
                  </td>
                  <td style={{ padding: '15px', borderBottom: '1px solid #dee2e6' }}>
                    {worker.email}
                  </td>
                  <td
                    style={{
                      padding: '15px',
                      borderBottom: '1px solid #dee2e6',
                      textAlign: 'center',
                    }}
                  >
                    <span
                      style={{
                        padding: '4px 8px',
                        borderRadius: '4px',
                        fontSize: '12px',
                        backgroundColor:
                          worker.role === 'manager'
                            ? '#e3f2fd'
                            : worker.role === 'supervisor'
                              ? '#fff3e0'
                              : '#f3e5f5',
                        color:
                          worker.role === 'manager'
                            ? '#1976d2'
                            : worker.role === 'supervisor'
                              ? '#f57c00'
                              : '#7b1fa2',
                      }}
                    >
                      {worker.role}
                    </span>
                  </td>
                  <td
                    style={{
                      padding: '15px',
                      borderBottom: '1px solid #dee2e6',
                      textAlign: 'center',
                    }}
                  >
                    <span
                      style={{
                        padding: '4px 8px',
                        borderRadius: '4px',
                        fontSize: '12px',
                        backgroundColor: worker.isActive ? '#d4edda' : '#f8d7da',
                        color: worker.isActive ? '#155724' : '#721c24',
                      }}
                    >
                      {worker.isActive ? 'Activo' : 'Inactivo'}
                    </span>
                  </td>
                  <td
                    style={{
                      padding: '15px',
                      borderBottom: '1px solid #dee2e6',
                      textAlign: 'center',
                    }}
                  >
                    <div style={{ display: 'flex', gap: '5px', justifyContent: 'center' }}>
                      <button
                        onClick={() => handleViewWorker(worker)}
                        style={{
                          padding: '5px 10px',
                          backgroundColor: '#17a2b8',
                          color: 'white',
                          border: 'none',
                          borderRadius: '4px',
                          cursor: 'pointer',
                          fontSize: '12px',
                        }}
                      >
                        Ver
                      </button>
                      <button
                        onClick={() => handleEditWorker(worker)}
                        style={{
                          padding: '5px 10px',
                          backgroundColor: '#ffc107',
                          color: 'black',
                          border: 'none',
                          borderRadius: '4px',
                          cursor: 'pointer',
                          fontSize: '12px',
                        }}
                      >
                        Editar
                      </button>
                      <button
                        onClick={() => handleToggleStatus(worker)}
                        style={{
                          padding: '5px 10px',
                          backgroundColor: worker.isActive ? '#dc3545' : '#28a745',
                          color: 'white',
                          border: 'none',
                          borderRadius: '4px',
                          cursor: 'pointer',
                          fontSize: '12px',
                        }}
                      >
                        {worker.isActive ? 'Desactivar' : 'Activar'}
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Modal */}
      <WorkerModal
        isOpen={modalOpen}
        onClose={() => setModalOpen(false)}
        onSave={handleSaveWorker}
        worker={selectedWorker}
        mode={modalMode}
      />
    </div>
  );
};

export default WorkersPage;
