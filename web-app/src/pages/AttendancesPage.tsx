import { useState, useEffect } from 'react';
import type { WorkerAttendanceStatus, AttendanceRecord, UserData, Worksite} from '../types';
import { attendanceService } from '../services/attendanceService';
import { worksitesService } from '../services/worksitesService';
import { workersService } from '../services/workersService';
import Loading from '../components/Loading';
import AttendanceEditModal from '../components/AttendanceEditModal';

const AttendancePage: React.FC = () => {
  // Estados principales
  const [viewMode, setViewMode] = useState<'dashboard' | 'reports'>('dashboard');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Estados para Dashboard
  const [workerStatuses, setWorkerStatuses] = useState<WorkerAttendanceStatus[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');

  // Estados para Reportes
  const [attendanceRecords, setAttendanceRecords] = useState<AttendanceRecord[]>([]);
  const [worksites, setWorksites] = useState<Worksite[]>([]);
  const [workers, setWorkers] = useState<UserData[]>([]);

  // Estados para edición de asistencias
  const [editingRecord, setEditingRecord] = useState<AttendanceRecord | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);

  // Filtros de reportes
  const [filters, setFilters] = useState({
    worksiteId: '',
    workerId: '',
    startDate: new Date(new Date().setHours(0,0,0,0)), // Hoy 00:00
    endDate: new Date(new Date().setHours(23,59,59,999)) // Hoy 23:59
  });

  // Cargar datos iniciales
  useEffect(() => {
    void loadDashboardData();
    void loadFilterOptions();
  }, []);

  // Actualización en tiempo real
  useEffect(() => {
    if (viewMode === 'dashboard') {
      const unsubscribe = attendanceService.subscribeToRealtimeUpdates((statuses) => {
        setWorkerStatuses(statuses);
      });

      return () => unsubscribe();
    }
  }, [viewMode]);

  const loadDashboardData = async () => {
    try {
      setLoading(true);
      const statuses = await attendanceService.getRealtimeWorkerStatus();
      setWorkerStatuses(statuses);
      setError('');
    } catch (error) {
      setError('Error cargando datos: ' + (error as Error).message);
    } finally {
      setLoading(false);
    }
  };

  const loadFilterOptions = async () => {
    try {
      const [worksitesData, workersData] = await Promise.all([
        worksitesService.getAllWorksites(),
        workersService.getAllWorkers()
      ]);
      setWorksites(worksitesData);
      setWorkers(workersData.filter(w => w.role === 'trabajador'));
    } catch (error) {
      console.error('Error cargando opciones de filtro:', error);
    }
  };

  const loadReports = async () => {
    try {
      setLoading(true);
      const records = await attendanceService.getAttendanceRecords({
        worksiteId: filters.worksiteId || undefined,
        workerId: filters.workerId || undefined,
        startDate: filters.startDate ? new Date(filters.startDate) : undefined,
        endDate: filters.endDate ? new Date(filters.endDate) : undefined
      });
      setAttendanceRecords(records);
      setError('');
    } catch (error) {
      setError('Error cargando reportes: ' + (error as Error).message);
    } finally {
      setLoading(false);
    }
  };

  const openEditModal = (record: AttendanceRecord) => {
    setEditingRecord(record);
    setIsModalOpen(true);
  };

  const closeEditModal = () => {
    setEditingRecord(null);
    setIsModalOpen(false);
  };

  const handleSaved = async () => {
    // refrescar los reportes
    await loadReports();
  };

  // Cambiar entre vistas
  const switchToReports = async () => {
    setViewMode('reports');
    await loadReports();
  };

  // Filtrar trabajadores en Dashboard
  const filteredWorkers = workerStatuses.filter(worker => {
    const matchesSearch =
      worker.workerName.toLowerCase().includes(searchTerm.toLowerCase()) ||
      worker.workerDNI.includes(searchTerm);

    const matchesStatus =
      statusFilter === 'all' || worker.status === statusFilter;

    return matchesSearch && matchesStatus;
  });

  // Estadísticas del dashboard
  const dashboardStats = {
    total: workerStatuses.length,
    present: workerStatuses.filter(w => w.status === 'Presente').length,
    absent: workerStatuses.filter(w => w.status === 'Ausente').length,
    outside: workerStatuses.filter(w => w.status === 'Fuera de obra').length
  };

  // Estadísticas de reportes
  const reportStats = attendanceService.calculateStats(attendanceRecords);

  // Ordenar registros localmente por nombre de obra para evitar crear índices en Firestore
  const sortedRecords = attendanceRecords.slice().sort((a, b) => {
    const aName = worksites.find(w => w.worksiteId === a.worksiteId)?.name || '';
    const bName = worksites.find(w => w.worksiteId === b.worksiteId)?.name || '';
    return aName.localeCompare(bName, 'es', { sensitivity: 'base' });
  });

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'Presente':
        return 'bg-green-100 text-green-800 border-green-200';
      case 'Intento Fallido':
        return 'bg-yellow-100 text-yellow-800 border-yellow-200';
      case 'Tarde':
        return 'bg-orange-100 text-orange-800 border-orange-200';
      default:
        return 'bg-red-100 text-red-800 border-red-200';
    }
  };

  const getStatusLabel = (status: string) => {
    switch (status) {
      case 'Presente':
        return '✅ Presente';
      case 'Intento Fallido':
        return '🚪 Fuera de obra';
      case 'Tarde':
        return '⏰ Tarde';
      default:
        return '❌ Ausente';
    }
  };

  if (loading && workerStatuses.length === 0) {
    return (
      <Loading title="Cargando datos de asistencias..." />
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-7xl mx-auto space-y-6">
        {/* Header */}
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200">
          <div className="border-b border-gray-200">
            <div className="p-6">
              <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between space-y-4 lg:space-y-0">
                <div className="flex items-center space-x-4">
                  <div>
                    <h1 className="text-2xl font-bold text-gray-900 mb-2">
                      {viewMode === 'dashboard' ? 'Asistencia en Tiempo Real' : 'Reportes de Asistencia'}
                    </h1>
                    <p className="text-gray-600">
                      {viewMode === 'dashboard'
                        ? 'Monitoreo del estado actual de los trabajadores'
                        : 'Análisis detallado con filtros avanzados'
                      }
                    </p>
                  </div>
                </div>

                {/* Toggle View Button */}
                <button
                  onClick={() => viewMode === 'dashboard' ? void switchToReports() : setViewMode('dashboard')}
                  className="bg-gradient-to-r from-primary-500 to-primary-600 text-white px-6 py-3 rounded-xl font-bold shadow-lg hover:shadow-xl transform hover:scale-105 transition-all duration-200 flex items-center space-x-2"
                >
                  <span>{viewMode === 'dashboard' ? 'Ver Reportes Completos' : 'Volver al Dashboard'}</span>
                </button>
              </div>
            </div>

          {/* Status indicators */}
          <div className="p-6 border-t border-gray-100">
            {viewMode === 'dashboard' && (
              <div className="flex items-center space-x-2 text-sm text-gray-600 bg-green-50 px-4 py-2 rounded-lg border border-green-200">
                <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
                <span className="font-medium">Actualización automática en tiempo real</span>
              </div>
            )}
            {viewMode === 'reports' && (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                <div className="col-span-2">
                  <label className="block text-sm font-medium text-gray-700 mb-2">Rango de Fechas</label>
                  <div className="flex space-x-4">
                    <input
                      type="date"
                      value={filters.startDate instanceof Date && !isNaN(filters.startDate.getTime())
                        ? filters.startDate.toISOString().split('T')[0]
                        : ''}
                      onChange={(e) => {
                        const date = new Date(e.target.value);
                        if (!isNaN(date.getTime())) {
                          setFilters({...filters, startDate: date});
                        }
                      }}
                      className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-primary-500 focus:border-primary-500"
                    />
                    <input
                      type="date"
                      value={filters.endDate instanceof Date && !isNaN(filters.endDate.getTime())
                        ? filters.endDate.toISOString().split('T')[0]
                        : ''}
                      onChange={(e) => {
                        const date = new Date(e.target.value);
                        if (!isNaN(date.getTime())) {
                          setFilters({...filters, endDate: date});
                        }
                      }}
                      className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Obra</label>
                  <select
                    value={filters.worksiteId}
                    onChange={(e) => setFilters({...filters, worksiteId: e.target.value})}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-primary-500 focus:border-primary-500"
                  >
                    <option value="">Todas las obras</option>
                    {worksites.map((worksite) => (
                      <option key={worksite.worksiteId} value={worksite.worksiteId}>{worksite.name}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Trabajador</label>
                  <select
                    value={filters.workerId}
                    onChange={(e) => setFilters({...filters, workerId: e.target.value})}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-primary-500 focus:border-primary-500"
                  >
                    <option value="">Todos los trabajadores</option>
                    {workers.map((worker) => (
                      <option key={worker.uid} value={worker.uid}>{worker.fullName}</option>
                    ))}
                  </select>
                </div>
              </div>
            )}
            {viewMode === 'reports' && (
              <div className="mt-6 flex justify-end">
                <button
                  onClick={() =>  void loadReports()}
                  className="bg-gradient-to-r from-primary-500 to-primary-600 text-white px-6 py-3 rounded-xl font-bold shadow-lg hover:shadow-xl transform hover:scale-105 transition-all duration-200 flex items-center space-x-2"
                >
                  <span>Aplicar Filtros</span>
                </button>
              </div>
            )}
          </div>
          </div>
        </div>

        {error && (
          <div className="bg-red-50 border-2 border-red-200 rounded-xl p-4 flex items-start space-x-3">
            <svg className="w-5 h-5 text-red-500 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
            </svg>
            <div>
              <h3 className="text-sm font-bold text-red-800">Error</h3>
              <p className="text-sm text-red-700">{error}</p>
            </div>
          </div>
        )}

        {/* VISTA DASHBOARD */}
        {viewMode === 'dashboard' && (
          <>
            {/* Estadísticas */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
              <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 transform hover:scale-105 transition-all duration-200">
                <div className="flex items-center justify-between mb-3">
                  <div className="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center">
                    <span className="text-2xl">👥</span>
                  </div>
                  <span className="text-3xl font-bold text-blue-600">{dashboardStats.total}</span>
                </div>
                <div className="text-sm font-medium text-gray-600">Total Trabajadores</div>
              </div>

              <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 transform hover:scale-105 transition-all duration-200">
                <div className="flex items-center justify-between mb-3">
                  <div className="w-12 h-12 bg-green-100 rounded-xl flex items-center justify-center">
                    <span className="text-2xl">✅</span>
                  </div>
                  <span className="text-3xl font-bold text-green-600">{dashboardStats.present}</span>
                </div>
                <div className="text-sm font-medium text-gray-600">Presentes</div>
              </div>

              <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 transform hover:scale-105 transition-all duration-200">
                <div className="flex items-center justify-between mb-3">
                  <div className="w-12 h-12 bg-red-100 rounded-xl flex items-center justify-center">
                    <span className="text-2xl">❌</span>
                  </div>
                  <span className="text-3xl font-bold text-red-600">{dashboardStats.absent}</span>
                </div>
                <div className="text-sm font-medium text-gray-600">Ausentes</div>
              </div>

              <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 transform hover:scale-105 transition-all duration-200">
                <div className="flex items-center justify-between mb-3">
                  <div className="w-12 h-12 bg-yellow-100 rounded-xl flex items-center justify-center">
                    <span className="text-2xl">🚪</span>
                  </div>
                  <span className="text-3xl font-bold text-yellow-600">{dashboardStats.outside}</span>
                </div>
                <div className="text-sm font-medium text-gray-600">Fuera de Obra</div>
              </div>
            </div>

            {/* Filtros del Dashboard */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                <div>
                  <label className="text-sm font-bold text-gray-700 mb-2 flex items-center space-x-2">
                    <span>Buscar Trabajador</span>
                  </label>
                  <input
                    type="text"
                    placeholder="Nombre o DNI..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:border-primary-500 focus:ring-2 focus:ring-primary-500 focus:ring-opacity-20 transition-all duration-200"
                  />
                </div>

                <div>
                  <label className="text-sm font-bold text-gray-700 mb-2 flex items-center space-x-2">
                    <span>Filtrar por Estado</span>
                  </label>
                  <select
                    value={statusFilter}
                    onChange={(e) => setStatusFilter(e.target.value)}
                    className="w-full px-4 py-3 border-2 border-gray-300 rounded-xl focus:border-primary-500 focus:ring-2 focus:ring-primary-500 focus:ring-opacity-20 transition-all duration-200 bg-white"
                  >
                    <option value="all">Todos los estados</option>
                    <option value="present">Solo presentes</option>
                    <option value="absent">Solo ausentes</option>
                    <option value="outside">Solo fuera de obra</option>
                  </select>
                </div>
              </div>
            </div>

            {/* Lista de Trabajadores */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
              {filteredWorkers.length === 0 ? (
                <div className="p-16 text-center">
                  <div className="w-24 h-24 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-6">
                    <span className="text-5xl opacity-50">👥</span>
                  </div>
                  <h3 className="text-xl font-bold text-gray-800 mb-2">
                    No se encontraron trabajadores
                  </h3>
                  <p className="text-gray-600">
                    Intenta ajustar los filtros de búsqueda
                  </p>
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full">
                    <thead className="bg-gradient-to-r from-gray-50 to-gray-100">
                      <tr>
                        <th className="px-6 py-4 text-left text-sm font-bold text-gray-700 uppercase">
                          Trabajador
                        </th>
                        <th className="px-6 py-4 text-center text-sm font-bold text-gray-700 uppercase">
                          Obra Asignada
                        </th>
                        <th className="px-6 py-4 text-center text-sm font-bold text-gray-700 uppercase">
                          Estado
                        </th>
                        <th className="px-6 py-4 text-center text-sm font-bold text-gray-700 uppercase">
                          Última Actividad
                        </th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-200">
                      {filteredWorkers.map((worker) => (
                        <tr key={worker.workerId} className="hover:bg-gray-50 transition-colors duration-150">
                          <td className="px-6 py-4">
                            <div className="flex items-center space-x-3">
                              <div>
                                <div className="font-bold text-gray-900">{worker.workerName}</div>
                                <div className="text-sm text-gray-500">DNI: {worker.workerDNI}</div>
                              </div>
                            </div>
                          </td>

                          <td className="px-6 py-4 text-center">
                            <div className="text-sm font-medium text-gray-900">
                              {worksites.find(w => w.worksiteId === worker.worksiteId)?.name || 'Sin asignar'}
                            </div>
                          </td>

                          <td className="px-6 py-4 text-center">
                            <span className={`inline-flex items-center space-x-2 px-3 py-1 rounded-full text-sm font-bold border-2 ${getStatusColor(worker.status)}`}>
                              <span>{getStatusLabel(worker.status)}</span>
                            </span>
                          </td>

                          <td className="px-6 py-4 text-center text-sm">
                            {worker.lastCheckIn ? (
                              <div className="space-y-1">
                                <div className="font-medium text-gray-900">
                                  Entrada: {worker.lastCheckIn.toLocaleTimeString('es-ES', {hour: '2-digit', minute: '2-digit'})}
                                </div>
                                {worker.lastCheckOut && (
                                  <div className="text-gray-600">
                                    Salida: {worker.lastCheckOut.toLocaleTimeString('es-ES', {hour: '2-digit', minute: '2-digit'})}
                                  </div>
                                )}
                              </div>
                            ) : (
                              <span className="text-gray-500">Sin registro hoy</span>
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          </>
        )}

        {/* VISTA REPORTES */}
        {viewMode === 'reports' && (
          <>
            {/* Estadísticas de Reportes */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
              <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
                <div className="flex items-center justify-between mb-3">
                  <div className="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center">
                    <span className="text-2xl">📊</span>
                  </div>
                  <span className="text-3xl font-bold text-blue-600">{attendanceRecords.length}</span>
                </div>
                <div className="text-sm font-medium text-gray-600">Total Registros</div>
              </div>

              <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
                <div className="flex items-center justify-between mb-3">
                  <div className="w-12 h-12 bg-green-100 rounded-xl flex items-center justify-center">
                    <span className="text-2xl">⌚</span>
                  </div>
                  <span className="text-3xl font-bold text-green-600">
                    {reportStats.avgHoursPerDay}h
                  </span>
                </div>
                <div className="text-sm font-medium text-gray-600">Promedio Horas/Día</div>
              </div>

              <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
                <div className="flex items-center justify-between mb-3">
                  <div className="w-12 h-12 bg-yellow-100 rounded-xl flex items-center justify-center">
                    <span className="text-2xl">⭐</span>
                  </div>
                  <span className="text-3xl font-bold text-yellow-600">
                    {reportStats.presentRecords ? (reportStats.presentRecords / reportStats.totalRecords * 100).toFixed(2) : 0}%
                  </span>
                </div>
                <div className="text-sm font-medium text-gray-600">Puntualidad</div>
              </div>

              <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
                <div className="flex items-center justify-between mb-3">
                  <div className="w-12 h-12 bg-red-100 rounded-xl flex items-center justify-center">
                    <span className="text-2xl">⚠️</span>
                  </div>
                  <span className="text-3xl font-bold text-red-600">
                    {reportStats.absentRecords ? (reportStats.absentRecords / reportStats.totalRecords * 100).toFixed(2) : 0}%
                  </span>
                </div>
                <div className="text-sm font-medium text-gray-600">Ausentismo</div>
              </div>
            </div>

            {/* Tabla de Registros */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-50">
                    <tr>
                      <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Trabajador
                      </th>
                      <th scope="col" className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Obra
                      </th>
                      <th scope="col" className="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Fecha
                      </th>
                      <th scope="col" className="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Estado
                      </th>
                      <th scope="col" className="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Entrada/Salida
                      </th>
                      <th scope="col" className="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Horas
                      </th>
                      <th scope="col" className="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Acciones
                      </th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {sortedRecords.map((record) => (
                      <tr key={record.id} className="hover:bg-gray-50 transition-colors duration-150">
                        <td className="px-6 py-4">
                          <div className="flex items-center space-x-3">
                            <div>
                              <div className="font-bold text-gray-900">{workers.find(worker => worker.uid === record.workerId)?.fullName}</div>
                              <div className="text-sm text-gray-500">DNI: {workers.find(worker => worker.uid === record.workerId)?.dni}</div>
                            </div>
                          </div>
                        </td>
                        <td className="px-6 py-4">
                          <div className="text-sm font-medium text-gray-900">{worksites.find(worksite => worksite.worksiteId === record.worksiteId)?.name}</div>
                        </td>
                        <td className="px-6 py-4 text-center">
                          <div className="text-sm font-medium text-gray-900">
                            {record.date.toDate().toLocaleDateString('es-ES', {
                              weekday: 'long',
                              year: 'numeric',
                              month: 'long',
                              day: 'numeric'
                            })}
                          </div>
                        </td>
                        <td className="px-6 py-4 text-center">
                          <span className={`inline-flex items-center space-x-2 px-3 py-1 rounded-full text-sm font-bold border-2 ${getStatusColor(record.status)}`}>
                            <span>{getStatusLabel(record.status)}</span>
                          </span>
                        </td>
                        <td className="px-6 py-4 text-center text-sm">
                          <div className="space-y-1">
                            <div className="font-medium text-gray-900">
                              Entrada: {record.punchIn?.timestamp.toDate().toLocaleTimeString('es-ES', {hour: '2-digit', minute: '2-digit'})}
                            </div>
                            {record.punchOut?.timestamp && (
                              <div className="text-gray-600">
                                Salida: {record.punchOut?.timestamp.toDate().toLocaleTimeString('es-ES', {hour: '2-digit', minute: '2-digit'})}
                              </div>
                            )}
                          </div>
                        </td>
                        <td className="px-6 py-4 text-center">
                          <div className="text-sm font-medium text-gray-900">
                            {record.workedHours ? `${record.workedHours.toFixed(1)}h` : '-'}
                          </div>
                        </td>
                        <td className="px-6 py-4 text-center">
                          <button
                            onClick={() => openEditModal(record)}
                            className="text-sm font-medium text-primary-600 hover:underline"
                          >
                            Editar
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              {attendanceRecords.length === 0 && (
                <div className="p-16 text-center">
                  <div className="w-24 h-24 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-6">
                    <span className="text-5xl opacity-50">📊</span>
                  </div>
                  <h3 className="text-xl font-bold text-gray-800 mb-2">
                    No hay registros para mostrar
                  </h3>
                  <p className="text-gray-600">
                    Prueba ajustando los filtros de búsqueda
                  </p>
                </div>
              )}
            </div>
          </>
        )}
  <AttendanceEditModal open={isModalOpen} record={editingRecord} onClose={closeEditModal} onSaved={() => { void handleSaved(); }} />
      </div>
    </div>
  );
};

export default AttendancePage;