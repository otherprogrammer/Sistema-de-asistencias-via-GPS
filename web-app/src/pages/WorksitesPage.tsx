import { useState, useEffect } from 'react';
import type { Worksite } from '../types';
import { worksitesService } from '../services/worksitesService';
import WorksiteModal from '../components/WorksiteModal';
import Loading from '../components/Loading';

const WorksitesPage: React.FC = () => {
  const [worksites, setWorksites] = useState<Worksite[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [searchTerm, setSearchTerm] = useState('');

  // Modal states
  const [modalOpen, setModalOpen] = useState(false);
  const [modalMode, setModalMode] = useState<'create' | 'edit' | 'view'>('create');
  const [selectedWorksite, setSelectedWorksite] = useState<Worksite | null>(null);

  // Cargar obras
  const loadWorksites = async () => {
    try {
      setLoading(true);
      const worksitesData = await worksitesService.getAllWorksites();
      setWorksites(worksitesData);
      setError('');
    } catch (error) {
      setError('Error cargando obras: ' + (error as Error).message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void loadWorksites();
  }, []);

  // Filtrar obras
  const filteredWorksites = worksites.filter((worksite) => {
    const matchesSearch =
      worksite.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      worksite.worksiteId.toLowerCase().includes(searchTerm.toLowerCase());

    return matchesSearch;
  });

  // Handlers de modal
  const handleCreateWorksite = () => {
    setSelectedWorksite(null);
    setModalMode('create');
    setModalOpen(true);
  };

  const handleEditWorksite = (worksite: Worksite) => {
    setSelectedWorksite(worksite);
    setModalMode('edit');
    setModalOpen(true);
  };

  const handleViewWorksite = (worksite: Worksite) => {
    setSelectedWorksite(worksite);
    setModalMode('view');
    setModalOpen(true);
  };

  const handleSaveWorksite = (worksite: Worksite) => {
    if (modalMode === 'create') {
      setWorksites((prev) => [worksite, ...prev]);
    } else {
      setWorksites((prev) =>
        prev.map((w) => (w.worksiteId === worksite.worksiteId ? worksite : w)),
      );
    }
  };

  /* const handleToggleStatus = async (worksite: Worksite) => {
    try {
      if (worksite.isActive) {
        await worksitesService.deactivateWorksite(worksite.worksiteId);
      } else {
        await worksitesService.activateWorksite(worksite.worksiteId);
      }

      setWorksites((prev) =>
        prev.map((w) =>
          w.worksiteId === worksite.worksiteId ? { ...w, isActive: !w.isActive } : w,
        ),
      );
    } catch (error: any) {
      alert('Error cambiando estado: ' + error.message);
    }
  }; */

  const copyCoordinates = (worksite: Worksite) => {
    const coordinates = `${worksite.latitude}, ${worksite.longitude}`;
    void navigator.clipboard.writeText(coordinates);
    // Puedes agregar una notificación aquí
    alert(`Coordenadas copiadas: ${coordinates}`);
  };

  const openInMaps = (worksite: Worksite) => {
    const url = `https://www.google.com/maps?q=${worksite.latitude},${worksite.longitude}`;
    window.open(url, '_blank');
  };

  if (loading) {
    return <Loading title="Cargando obras" text="Obteniendo información de las ubicaciones..." />;
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto space-y-4">
        {/* Header */}
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-8 animate-slide-in-top">
          <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between">
            <div className="flex items-center space-x-4">
              <div>
                <h1 className="text-2xl font-bold text-gray-900 mb-2">Gestión de Obras</h1>
                <p className="text-md text-gray-600">Administración de obras y geocercas</p>
              </div>
            </div>

            <button
              onClick={handleCreateWorksite}
              className="bg-gradient-to-r from-primary-500 to-primary-600 text-white px-8 py-4 rounded-xl font-bold text-md shadow-lg hover:shadow-xl transform hover:scale-105 transition-all duration-200 flex items-center space-x-3"
            >
              <span>Nueva Obra</span>
            </button>
          </div>
        </div>

        {/* Error Message */}
        {error && (
          <div className="bg-red-50 border-2 border-red-200 rounded-xl p-6 flex items-start space-x-4 animate-slide-in-top shadow-sm">
            <div className="w-8 h-8 bg-red-100 rounded-full flex items-center justify-center flex-shrink-0">
              <svg
                className="w-5 h-5 text-red-600"
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
              <h3 className="text-lg font-bold text-red-800 mb-1">Error al cargar</h3>
              <p className="text-red-700">{error}</p>
            </div>
          </div>
        )}

        {/* Filtros y Búsqueda */}
        <div
          className="bg-white rounded-2xl shadow-sm border border-gray-200 p-6 animate-slide-in-right"
          style={{ animationDelay: '0.1s' }}
        >
          {/* Búsqueda */}
          <div className="w-7/12">
            <label className="text-sm font-bold text-gray-700 mb-3 flex items-center space-x-2">
              <span>Buscar Obras</span>
            </label>
            <div className="relative">
              <input
                type="text"
                placeholder="Nombre de obra"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-12 pr-4 py-2 text-md border-2 border-gray-300 rounded-xl focus:border-primary-500 focus:ring-2 focus:ring-primary-500 focus:ring-opacity-20 transition-all duration-200"
              />
              <svg
                className="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                />
              </svg>
            </div>
          </div>
        </div>

        {/* Tabla de Obras */}
        <div
          className="bg-white rounded-2xl shadow-sm border border-gray-200 overflow-hidden animate-slide-in-bottom"
          style={{ animationDelay: '0.2s' }}
        >
          {filteredWorksites.length === 0 ? (
            // Estado vacío
            <div className="p-16 text-center">
              <h3 className="text-2xl font-bold text-gray-800 mb-4">
                {searchTerm
                  ? 'No se encontraron obras'
                  : 'No hay obras creadas'}
              </h3>

              <p className="text-gray-600 text-lg mb-8 max-w-md mx-auto">
                {searchTerm
                  ? 'Intenta cambiar los filtros de búsqueda para encontrar más resultados'
                  : 'Comienza creando tu primera obra con su respectivo geofence'}
              </p>

              {!searchTerm && (
                <button
                  onClick={handleCreateWorksite}
                  className="bg-gradient-to-r from-primary-500 to-primary-600 text-white px-8 py-4 rounded-xl font-bold text-lg shadow-lg hover:shadow-xl transform hover:scale-105 transition-all duration-200 flex items-center space-x-3 mx-auto"
                >
                  <span>Crear Primera Obra</span>
                </button>
              )}
            </div>
          ) : (
            // Tabla con datos
            <div>
              <table className="w-full">
                <thead className="bg-gradient-to-r from-gray-50 to-gray-100">
                  <tr>
                    <th className="px-6 py-6 text-left text-sm font-bold text-gray-700 uppercase tracking-wider">
                      <div className="flex items-center space-x-2">
                        <span>Obra</span>
                      </div>
                    </th>
                    <th className="px-8 py-6 text-center text-sm font-bold text-gray-700 uppercase tracking-wider">
                      <div className="flex items-center justify-center space-x-2">
                        <span>Ubicación</span>
                      </div>
                    </th>
                    <th className="px-8 py-6 text-center text-sm font-bold text-gray-700 uppercase tracking-wider">
                      <div className="flex items-center justify-center space-x-2">
                        <span>Geocerca</span>
                      </div>
                    </th>
                    <th className="px-6 py-6 text-center text-sm font-bold text-gray-700 uppercase tracking-wider">
                      <div className="flex items-center justify-center space-x-2">
                        <span>Acciones</span>
                      </div>
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {filteredWorksites.map((worksite, index) => (
                    <tr
                      key={worksite.worksiteId}
                      className="hover:bg-gray-50 transition-all duration-200 transform hover:scale-[1.01]"
                      style={{
                        animationDelay: `${index * 0.1}s`,
                        animationFillMode: 'backwards',
                      }}
                    >
                      {/* Nombre de la obra */}
                      <td className="px-6 py-6">
                        <div className="flex items-center space-x-4">
                          <div>
                            <div className="text-lg font-bold text-gray-900 mb-1">
                              {worksite.name}
                            </div>
                            <div className="text-sm text-gray-500 font-mono">
                              ID: {worksite.worksiteId.substring(0, 8)}...
                            </div>
                          </div>
                        </div>
                      </td>

                      {/* Coordenadas */}
                      <td className="px-8 py-6 text-center">
                        <div className="space-y-2">
                          <div className="font-mono text-sm text-gray-700 bg-gray-100 px-3 py-1 rounded-lg">
                            <div>{worksite.latitude.toFixed(6)}</div>
                            <div>{worksite.longitude.toFixed(6)}</div>
                          </div>
                          <div className="flex justify-center space-x-2">
                            <button
                              onClick={() => copyCoordinates(worksite)}
                              className="px-3 py-1 bg-gray-200 text-gray-700 text-xs rounded-lg hover:bg-gray-300 transition-all duration-200 transform hover:scale-105 flex items-center space-x-1"
                              title="Copiar coordenadas"
                            >
                              <span>Copiar</span>
                            </button>
                            <button
                              onClick={() => openInMaps(worksite)}
                              className="px-3 py-1 bg-blue-100 text-blue-700 text-xs rounded-lg hover:bg-blue-200 transition-all duration-200 transform hover:scale-105 flex items-center space-x-1"
                              title="Abrir en Google Maps"
                            >
                              <span>Maps</span>
                            </button>
                          </div>
                        </div>
                      </td>

                      {/* Radio */}
                      <td className="px-8 py-6 text-center">
                        <div className="inline-flex items-center space-x-2 bg-blue-100 text-blue-800 px-4 py-2 rounded-full font-bold">
                          <span>📏</span>
                          <span>{worksite.radius}m</span>
                        </div>
                      </td>

                      {/* Acciones */}
                      <td className="px-8 py-6">
                        <div className="flex justify-center space-x-2">
                          <button
                            onClick={() => handleViewWorksite(worksite)}
                            className="inline-flex items-center p-2 border border-transparent text-sm font-medium rounded-lg text-[#2D6EA4] bg-[#2D6EA4]/10 hover:bg-[#2D6EA4]/20 transition-colors duration-200"
                            title="Ver detalles"
                          >
                            <span>Ver</span>
                          </button>

                          <button
                            onClick={() => handleEditWorksite(worksite)}
                            className="inline-flex items-center p-2 border border-transparent text-sm font-medium rounded-lg text-yellow-700 bg-yellow-100 hover:bg-yellow-200 transition-colors duration-200"
                            title="Editar obra"
                          >
                            <span>Editar</span>
                          </button>

                          {/* <button
                            onClick={() => handleToggleStatus(worksite)}
                            className={`px-4 py-2 rounded-lg transition-all duration-200 transform hover:scale-105 flex items-center space-x-1 shadow-sm font-medium text-white ${
                              worksite.isActive
                                ? 'bg-red-500 hover:bg-red-600'
                                : 'bg-green-500 hover:bg-green-600'
                            }`}
                            title={worksite.isActive ? 'Desactivar obra' : 'Activar obra'}
                          >
                            <span>{worksite.isActive ? 'Desactivar' : 'Activar'}</span>
                          </button> */}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      {/* Modal */}
      <WorksiteModal
        isOpen={modalOpen}
        onClose={() => setModalOpen(false)}
        onSave={handleSaveWorksite}
        worksite={selectedWorksite}
        mode={modalMode}
      />
    </div>
  );
};

export default WorksitesPage;
