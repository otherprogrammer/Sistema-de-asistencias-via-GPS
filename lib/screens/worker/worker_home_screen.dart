import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../constants/app_colors.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  final LocationService _locationService = LocationService();
  bool _isProcessingLocation = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control Asistencia'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthService>().signOut();
            },
          ),
        ],
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, _) {
          final user = authService.currentUser!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // User info card
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: AppColors.textOnPrimary,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.fullName,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('DNI: ${user.dni}'),
                              Text(
                                'Trabajador',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Location status indicator
                Card(
                  color: AppColors.background,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Ubicación GPS requerida para marcar asistencia',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Check-in/out buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessingLocation 
                            ? null 
                            : () => _handleMarkAttendance(context, 'entrada'),
                        icon: _isProcessingLocation 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login),
                        label: const Text('Marcar\nEntrada'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(24),
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessingLocation 
                            ? null 
                            : () => _handleMarkAttendance(context, 'salida'),
                        icon: _isProcessingLocation 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.logout),
                        label: const Text('Marcar\nSalida'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(24),
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Additional options
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.history,
                          color: AppColors.primary,
                        ),
                        title: const Text('Ver Historial'),
                        subtitle: const Text('Consulta tus registros de asistencia'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Historial - Próximamente'),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.location_searching,
                          color: AppColors.primary,
                        ),
                        title: const Text('Probar Ubicación'),
                        subtitle: const Text('Verificar GPS y permisos'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => _testLocation(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Manejar marcado de asistencia (entrada o salida)
  Future<void> _handleMarkAttendance(BuildContext context, String type) async {
    if (_isProcessingLocation) return;

    setState(() {
      _isProcessingLocation = true;
    });

    try {
      // Mostrar dialog de progreso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Obteniendo ubicación GPS...'),
            ],
          ),
        ),
      );

      // Obtener ubicación actual
      Position? position = await _locationService.getCurrentLocation();
      
      // Cerrar dialog de progreso
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (position != null) {
        // TODO: Aquí validar geofencing con datos de la obra
        // Por ahora solo mostramos la ubicación obtenida
        
        if (context.mounted) {
          _showLocationResult(context, type, position);
        }
      } else {
        if (context.mounted) {
          _showErrorDialog(context, 'No se pudo obtener la ubicación GPS');
        }
      }
    } catch (e) {
      // Cerrar dialog si está abierto
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        String errorMsg = _locationService.getLocationErrorMessage(e);
        _showErrorDialog(context, errorMsg);
      }
    } finally {
      setState(() {
        _isProcessingLocation = false;
      });
    }
  }

  /// Mostrar resultado de la ubicación obtenida
  void _showLocationResult(BuildContext context, String type, Position position) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${type.toUpperCase()} registrada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ubicación GPS capturada:'),
            const SizedBox(height: 8),
            Text('Latitud: ${position.latitude.toStringAsFixed(6)}'),
            Text('Longitud: ${position.longitude.toStringAsFixed(6)}'),
            Text('Precisión: ${position.accuracy.toStringAsFixed(1)}m'),
            Text('Timestamp: ${DateTime.now().toString()}'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'GPS capturado correctamente. Próximo: validar geofencing.',
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Mostrar dialog de error
  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error de Ubicación'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Abrir configuración de la app
              Geolocator.openAppSettings();
            },
            child: const Text('Configuración'),
          ),
        ],
      ),
    );
  }

  /// Probar funcionalidad de ubicación
  Future<void> _testLocation(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Probando ubicación GPS...'),
            ],
          ),
        ),
      );

      Position? position = await _locationService.getCurrentLocation();
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Cerrar dialog de carga
        
        if (position != null) {
          _showLocationResult(context, 'prueba', position);
        } else {
          _showErrorDialog(context, 'No se pudo obtener ubicación');
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Cerrar dialog de carga
        String errorMsg = _locationService.getLocationErrorMessage(e);
        _showErrorDialog(context, errorMsg);
      }
    }
  }
}