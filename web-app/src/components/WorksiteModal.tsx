import { useState, useEffect, useRef } from 'react';
import type { Worksite, CreateWorksiteData } from '../types';
import { worksitesService } from '../services/worksitesService';

interface WorksiteModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSave: (worksite: Worksite) => void;
  worksite?: Worksite | null;
  mode: 'create' | 'edit' | 'view';
}

const WorksiteModal: React.FC<WorksiteModalProps> = ({
  isOpen,
  onClose,
  onSave,
  worksite,
  mode,
}) => {
  const [formData, setFormData] = useState({
    name: '',
    latitude: 0,
    longitude: 0,
    radius: 100,
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [isClosing, setIsClosing] = useState(false);
  const [mapInitialized, setMapInitialized] = useState(false);
  const mapRef = useRef<HTMLDivElement>(null);

  const handleClose = () => {
    setIsClosing(true);
    setTimeout(() => {
      setIsClosing(false);
      onClose();
    }, 200);
  };

  useEffect(() => {
    if (worksite && (mode === 'edit' || mode === 'view')) {
      setFormData({
        name: worksite.name,
        latitude: worksite.latitude,
        longitude: worksite.longitude,
        radius: worksite.radius,
      });
    } else {
      // Coordenadas por defecto (puedes cambiarlas por tu ciudad)
      setFormData({
        name: '',
        latitude: -16.409, // Arequipa, Perú
        longitude: -71.5375,
        radius: 100,
      });
    }
    setError('');
    setMapInitialized(false);
  }, [worksite, mode, isOpen]);

  // Inicializar mapa simple (sin librerías externas por ahora)
  useEffect(() => {
    if (isOpen && mapRef.current && !mapInitialized) {
      initializeMap();
      setMapInitialized(true);
    }
  }, [isOpen, mapInitialized]);

  const initializeMap = () => {
    if (!mapRef.current) return;

    const radiusPixels = Math.max(60, Math.min(150, formData.radius / 3));

    // Crear un mapa simple con HTML/CSS
    mapRef.current.innerHTML = `
      <div class="w-full h-full bg-gradient-to-br from-blue-500 via-primary-500 to-blue-700 flex flex-col items-center justify-center text-white text-center rounded-lg relative overflow-hidden">
        <!-- Efecto de ondas -->
        <div class="absolute inset-0 opacity-20">
          <div class="absolute w-32 h-32 border-2 border-white border-opacity-30 rounded-full animate-ping" style="top: 50%; left: 50%; transform: translate(-50%, -50%); animation-duration: 3s;"></div>
          <div class="absolute w-24 h-24 border border-white border-opacity-20 rounded-full animate-ping" style="top: 50%; left: 50%; transform: translate(-50%, -50%); animation-delay: 1s; animation-duration: 3s;"></div>
        </div>

        <!-- Pin principal -->
        <div class="text-6xl mb-3 animate-bounce" style="animation-duration: 2s;">📍</div>

        <!-- Información -->
        <div class="relative z-10 space-y-2">
          <div class="text-lg font-bold tracking-wide">
            ${formData.name || 'Nueva Obra'}
          </div>
          <div class="text-sm opacity-90 font-mono bg-black bg-opacity-20 px-3 py-1 rounded-full">
            ${formData.latitude.toFixed(6)}, ${formData.longitude.toFixed(6)}
          </div>
        </div>

        <!-- Radio indicator -->
        <div class="absolute bottom-3 right-3 bg-black bg-opacity-50 text-xs px-3 py-1 rounded-full font-semibold backdrop-blur-sm">
          📏 ${formData.radius}m
        </div>

        <!-- Geofence circle -->
        <div class="absolute border-2 border-dashed border-white border-opacity-60 rounded-full pointer-events-none"
             style="width: ${radiusPixels}px; height: ${radiusPixels}px; top: 50%; left: 50%; transform: translate(-50%, -50%); animation: pulse 2s infinite;"></div>
      </div>
    `;
  };

  const handleCoordinateChange = (field: 'latitude' | 'longitude', value: string) => {
    const numValue = parseFloat(value);
    if (!isNaN(numValue)) {
      setFormData((prev) => ({ ...prev, [field]: numValue }));
      // Actualizar mapa cuando cambien las coordenadas
      setTimeout(() => initializeMap(), 100);
    }
  };

  const handleRadiusChange = (value: string) => {
    const numValue = parseInt(value);
    if (!isNaN(numValue) && numValue > 0) {
      setFormData((prev) => ({ ...prev, radius: numValue }));
      setTimeout(() => initializeMap(), 100);
    }
  };

  const handleGetCurrentLocation = () => {
    if (navigator.geolocation) {
      setLoading(true);
      navigator.geolocation.getCurrentPosition(
        (position) => {
          setFormData((prev) => ({
            ...prev,
            latitude: position.coords.latitude,
            longitude: position.coords.longitude,
          }));
          setTimeout(() => initializeMap(), 100);
          setLoading(false);
        },
        (error) => {
          setError('Error obteniendo ubicación: ' + error.message);
          setLoading(false);
        },
      );
    } else {
      setError('Geolocalización no disponible en este navegador');
    }
  };

  const validateForm = (): boolean => {
    if (!formData.name.trim()) {
      setError('El nombre es obligatorio');
      return false;
    }

    if (formData.latitude < -90 || formData.latitude > 90) {
      setError('Latitud debe estar entre -90 y 90');
      return false;
    }

    if (formData.longitude < -180 || formData.longitude > 180) {
      setError('Longitud debe estar entre -180 y 180');
      return false;
    }

    if (formData.radius < 10 || formData.radius > 10000) {
      setError('Radio debe estar entre 10 y 10,000 metros');
      return false;
    }

    return true;
  };

  const handleSubmit = async () => {
    if (!validateForm()) return;

    setError('');
    setLoading(true);

    try {
      // Verificar nombre único
      const nameExists = await worksitesService.isNameExists(
        formData.name,
        mode === 'edit' ? worksite?.worksiteId : undefined,
      );

      if (nameExists) {
        throw new Error('Ya existe una obra con este nombre');
      }

      let savedWorksite: Worksite;

      if (mode === 'create') {
        savedWorksite = await worksitesService.createWorksite(formData as CreateWorksiteData);
      } else if (mode === 'edit' && worksite) {
        await worksitesService.updateWorksite(worksite.worksiteId, formData);
        savedWorksite = { ...worksite, ...formData };
      } else {
        return;
      }

      onSave(savedWorksite);
      onClose();
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
    // Overlay
    <div
      className={`fixed inset-0 bg-black bg-opacity-60 backdrop-blur-sm flex items-center justify-center z-50 p-4 transition-all duration-200 ${
        isClosing ? 'animate-fade-out' : 'animate-fade-in'
      }`}
      onClick={handleClose}
    >
      {/* Modal Container - Más grande para obras */}
      <div
        className={`bg-white rounded-2xl shadow-2xl w-full max-w-3xl max-h-[95vh] overflow-hidden transition-all duration-300 ${
          isClosing
            ? 'animate-scale-out animate-slide-out-bottom'
            : 'animate-scale-in animate-slide-in-bottom'
        }`}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-200 bg-gradient-to-r from-primary-500 to-primary-600 relative overflow-hidden">
          <div className="flex items-center space-x-4 relative z-10">
            <div className="w-12 h-12 bg-white bg-opacity-20 rounded-full flex items-center justify-center backdrop-blur-sm border border-white border-opacity-20 transition-transform duration-200 hover:scale-105">
              <span className="text-2xl">
                {mode === 'create' ? '🏗️' : mode === 'edit' ? '✏️' : '👁️'}
              </span>
            </div>
            <div>
              <h2 className="text-2xl font-bold text-white">
                {mode === 'create' ? 'Nueva Obra' : mode === 'edit' ? 'Editar Obra' : 'Ver Obra'}
              </h2>
              <p className="text-primary-100 text-sm opacity-90">
                {mode === 'create'
                  ? 'Crear geofence para nueva ubicación'
                  : mode === 'edit'
                    ? 'Modificar configuración del geofence'
                    : 'Detalles del geofence y ubicación'}
              </p>
            </div>
          </div>

          <button
            onClick={handleClose}
            disabled={loading}
            className="text-white hover:text-gray-200 transition-all duration-200 p-2 rounded-full hover:bg-white hover:bg-opacity-10 transform hover:scale-105 disabled:opacity-50 relative z-10"
          >
            <svg className="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
        <div className="flex max-h-[calc(95vh-190px)]">
          {/* Formulario - Panel izquierdo */}
          <div className="w-full p-6 overflow-y-auto scrollbar-thin scrollbar-thumb-gray-300">
            {/* Error Message */}
            {error && (
              <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg flex items-start space-x-3 animate-slide-in-top">
                <svg
                  className="w-5 h-5 text-red-500 mt-0.5 flex-shrink-0"
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
                <div>
                  <h3 className="text-sm font-medium text-red-800">Error de validación</h3>
                  <p className="text-sm text-red-700 mt-1">{error}</p>
                </div>
              </div>
            )}

            {/* Form Fields */}
            <div className="space-y-6">
              {/* Nombre de la Obra */}
              <div
                className="animate-slide-in-right"
                style={{ animationDelay: '0.1s', animationFillMode: 'backwards' }}
              >
                <label className="text-sm font-bold text-gray-700 mb-3 flex items-center space-x-2">
                  <span>Nombre de la Obra *</span>
                </label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  disabled={isReadOnly || loading}
                  placeholder="Ej: Torre Principal, Edificio Norte, Obra Centro..."
                  className={`w-full px-4 py-3 text-lg border-2 rounded-xl transition-all duration-200 transform focus:scale-[1.02] ${
                    isReadOnly || loading
                      ? 'bg-gray-50 border-gray-200 text-gray-500 cursor-not-allowed'
                      : 'border-gray-300 focus:border-primary-500 focus:ring-2 focus:ring-primary-500 focus:ring-opacity-20 hover:border-gray-400'
                  }`}
                />
              </div>

              {/* Coordenadas */}
              <div
                className="grid grid-cols-1 md:grid-cols-2 gap-4 animate-slide-in-right"
                style={{ animationDelay: '0.2s', animationFillMode: 'backwards' }}
              >
                <div>
                  <label className="text-sm font-bold text-gray-700 mb-3 flex items-center space-x-2">
                    <span>Latitud *</span>
                  </label>
                  <input
                    type="number"
                    step="any"
                    value={formData.latitude}
                    onChange={(e) => handleCoordinateChange('latitude', e.target.value)}
                    disabled={isReadOnly || loading}
                    placeholder="-16.4090"
                    className={`w-full px-4 py-3 border-2 rounded-xl font-mono transition-all duration-200 transform focus:scale-[1.02] ${
                      isReadOnly || loading
                        ? 'bg-gray-50 border-gray-200 text-gray-500 cursor-not-allowed'
                        : 'border-gray-300 focus:border-primary-500 focus:ring-2 focus:ring-primary-500 focus:ring-opacity-20 hover:border-gray-400'
                    }`}
                  />
                </div>

                <div>
                  <label className="text-sm font-bold text-gray-700 mb-3 flex items-center space-x-2">
                    <span>Longitud *</span>
                  </label>
                  <input
                    type="number"
                    step="any"
                    value={formData.longitude}
                    onChange={(e) => handleCoordinateChange('longitude', e.target.value)}
                    disabled={isReadOnly || loading}
                    placeholder="-71.5375"
                    className={`w-full px-4 py-3 border-2 rounded-xl font-mono transition-all duration-200 transform focus:scale-[1.02] ${
                      isReadOnly || loading
                        ? 'bg-gray-50 border-gray-200 text-gray-500 cursor-not-allowed'
                        : 'border-gray-300 focus:border-primary-500 focus:ring-2 focus:ring-primary-500 focus:ring-opacity-20 hover:border-gray-400'
                    }`}
                  />
                </div>
              </div>

              {/* Radio del Geofence */}
              <div
                className="animate-slide-in-right"
                style={{ animationDelay: '0.3s', animationFillMode: 'backwards' }}
              >
                <label className="text-sm font-bold text-gray-700 mb-3 flex items-center space-x-2">
                  <span>Radio de la geocerca (metros) *</span>
                </label>
                <div className="relative">
                  <input
                    type="number"
                    min="10"
                    max="500"
                    step="10"
                    value={formData.radius}
                    onChange={(e) => handleRadiusChange(e.target.value)}
                    disabled={isReadOnly || loading}
                    placeholder="100"
                    className={`w-full px-4 py-3 pr-16 text-lg border-2 rounded-xl transition-all duration-200 transform focus:scale-[1.02] ${
                      isReadOnly || loading
                        ? 'bg-gray-50 border-gray-200 text-gray-500 cursor-not-allowed'
                        : 'border-gray-300 focus:border-primary-500 focus:ring-2 focus:ring-primary-500 focus:ring-opacity-20 hover:border-gray-400'
                    }`}
                  />
                  <span className="absolute right-4 top-1/2 transform -translate-y-1/2 text-gray-500 font-medium">
                    m
                  </span>
                </div>
                <div className="mt-2 flex items-center space-x-4 text-sm text-gray-600">
                  <div className="flex items-center space-x-1">
                    <span className="w-3 h-3 bg-green-400 rounded-full"></span>
                    <span>Recomendado: 50-300m</span>
                  </div>
                  <div className="flex items-center space-x-1">
                    <span className="w-3 h-3 bg-yellow-400 rounded-full"></span>
                    <span>Máximo: 500m</span>
                  </div>
                </div>
              </div>

              {/* Botón de geolocalización */}
              {!isReadOnly && (
                <div
                  className="animate-slide-in-right"
                  style={{ animationDelay: '0.4s', animationFillMode: 'backwards' }}
                >
                  <button
                    type="button"
                    onClick={handleGetCurrentLocation}
                    disabled={loading}
                    className={`w-full py-3 px-4 rounded-xl font-medium transition-all duration-200 flex items-center justify-center space-x-2 transform hover:scale-105 ${
                      loading
                        ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
                        : 'bg-green-500 text-white hover:bg-green-600 focus:ring-2 focus:ring-green-500 focus:ring-opacity-20 shadow-lg hover:shadow-xl'
                    }`}
                  >
                    {loading ? (
                      <svg className="animate-spin h-5 w-5" fill="none" viewBox="0 0 24 24">
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
                    ) : null}
                    <span>{loading ? 'Obteniendo ubicación...' : 'Usar mi ubicación actual'}</span>
                  </button>
                </div>
              )}

              {/* Información del sistema */}
              {worksite && (
                <div
                  className="bg-gradient-to-br from-gray-50 to-gray-100 border-2 border-gray-200 rounded-xl p-5 space-y-4 animate-scale-in"
                  style={{ animationDelay: '0.5s', animationFillMode: 'backwards' }}
                >
                  <h4 className="text-sm font-bold text-gray-700 flex items-center space-x-2">
                    <span className="text-lg">📋</span>
                    <span>Información del Sistema</span>
                  </h4>

                  <div className="grid grid-cols-1 gap-3">
                    <div className="flex items-center justify-between p-3 bg-white rounded-lg border shadow-sm">
                      <span className="text-sm text-gray-600 flex items-center space-x-2 font-medium">
                        <span>🔄</span>
                        <span>Estado:</span>
                      </span>
                      <span
                        className={`inline-flex items-center px-3 py-1 rounded-full text-xs font-bold transition-all duration-200 ${
                          worksite.isActive
                            ? 'bg-green-100 text-green-800 border border-green-200'
                            : 'bg-red-100 text-red-800 border border-red-200'
                        }`}
                      >
                        {worksite.isActive ? '✅ Activa' : '❌ Inactiva'}
                      </span>
                    </div>

                    <div className="flex items-center justify-between p-3 bg-white rounded-lg border shadow-sm">
                      <span className="text-sm text-gray-600 flex items-center space-x-2 font-medium">
                        <span>🆔</span>
                        <span>ID:</span>
                      </span>
                      <span className="text-xs text-gray-500 font-mono bg-gray-100 px-3 py-1 rounded-lg border">
                        {worksite.worksiteId}
                      </span>
                    </div>

                    {worksite.createdAt && (
                      <div className="flex items-center justify-between p-3 bg-white rounded-lg border shadow-sm">
                        <span className="text-sm text-gray-600 flex items-center space-x-2 font-medium">
                          <span>📅</span>
                          <span>Creada:</span>
                        </span>
                        <span className="text-sm text-gray-900 font-medium">
                          {worksite.createdAt.toDate().toLocaleDateString('es-ES', {
                            year: 'numeric',
                            month: 'short',
                            day: 'numeric',
                            hour: '2-digit',
                            minute: '2-digit',
                          })}
                        </span>
                      </div>
                    )}
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Mapa - Panel derecho */}
          {/* <div className="w-1/2 p-6 bg-gray-50 border-l border-gray-200 flex flex-col">
            <label className="text-sm font-bold text-gray-700 mb-4 flex items-center space-x-2">
              <span>Previsualización del Geofence</span>
            </label>

            <div className="flex-1 min-h-0">
              <div
                ref={mapRef}
                className="w-full h-full border-2 border-gray-300 rounded-xl overflow-hidden shadow-inner"
              />
            </div>

            <div className="mt-4 p-3 bg-white rounded-lg border border-gray-200 shadow-sm">
              <div className="text-sm text-gray-600 text-center space-y-1">
                <div className="flex items-center justify-center space-x-2">
                  <span className="w-3 h-3 border-2 border-dashed border-gray-400 rounded-full"></span>
                  <span className="font-medium">El círculo representa el área del geofence</span>
                </div>
                <div className="text-xs text-gray-500">
                  Los trabajadores deben estar dentro de este radio para marcar asistencia
                </div>
              </div>
            </div>
          </div> */}
        </div>

        {/* Footer */}
        {!isReadOnly && (
          <div className="flex items-center justify-end space-x-4 p-6 bg-gradient-to-r from-gray-50 to-gray-100 border-t border-gray-200">
            <button
              onClick={handleClose}
              disabled={loading}
              className="px-8 py-3 text-gray-700 bg-white border-2 border-gray-300 rounded-xl hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-opacity-20 transition-all duration-200 font-medium disabled:opacity-50 disabled:cursor-not-allowed transform hover:scale-105"
            >
              Cancelar
            </button>

            <button
              onClick={() => { void handleSubmit() }}
              disabled={loading}
              className={`px-8 py-3 text-white rounded-xl font-medium transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:ring-opacity-20 disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2 transform hover:scale-105 ${
                loading
                  ? 'bg-gray-400 cursor-not-allowed'
                  : 'bg-primary-500 hover:bg-primary-600 active:bg-primary-700 shadow-lg hover:shadow-xl'
              }`}
            >
              {loading && (
                <svg className="animate-spin h-5 w-5" fill="none" viewBox="0 0 24 24">
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
              <span>{loading ? 'Guardando...' : isCreate ? 'Crear Obra' : 'Guardar Cambios'}</span>
            </button>
          </div>
        )}

        {/* Footer para modo View */}
        {isReadOnly && (
          <div className="flex justify-end p-6 bg-gradient-to-r from-gray-50 to-gray-100 border-t border-gray-200">
            <button
              onClick={handleClose}
              className="px-8 py-3 text-white bg-primary-500 rounded-xl hover:bg-primary-600 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:ring-opacity-20 transition-all duration-200 font-medium transform hover:scale-105 shadow-lg hover:shadow-xl"
            >
              Cerrar
            </button>
          </div>
        )}
      </div>
    </div>
  );
};

export default WorksiteModal;
