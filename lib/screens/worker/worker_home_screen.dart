import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/attendance_service.dart';
import '../../constants/app_colors.dart';
import 'worker_history_screen.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  final LocationService _locationService = LocationService();
  final AttendanceService _attendanceService = AttendanceService();
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
                            Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const WorkerHistoryScreen(),
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

    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    
    if (user == null || user.assignedWorksiteId == null) {
      _showErrorDialog(context, 'Usuario o obra no válidos');
      return;
    }

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
              Text('${type == 'entrada' ? 'Marcando entrada' : 'Marcando salida'}...'),
            ],
          ),
        ),
      );

      String attendanceId;
      
      if (type == 'entrada') {
        attendanceId = await _attendanceService.markCheckIn(
          workerId: user.uid,
          worksiteId: user.assignedWorksiteId!,
        );
      } else {
        attendanceId = await _attendanceService.markCheckOut(
          workerId: user.uid,
          worksiteId: user.assignedWorksiteId!,
        );
      }
      
      // Cerrar dialog de progreso
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Mostrar éxito
      if (context.mounted) {
        _showSuccessDialog(context, type, attendanceId);
      }

    } catch (e) {
      // Cerrar dialog si está abierto
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        String errorMsg = _getAttendanceErrorMessage(e);
        _showErrorDialog(context, errorMsg);
      }
    } finally {
      setState(() {
        _isProcessingLocation = false;
      });
    }
  }

  /// Mostrar dialog de éxito
  void _showSuccessDialog(BuildContext context, String type, String attendanceId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 8),
            Text('${type.toUpperCase()} Registrada'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tu ${type} ha sido registrada exitosamente.'),
            const SizedBox(height: 8),
            Text('Hora: ${DateTime.now().toString().substring(0, 19)}'),
            Text('ID: ${attendanceId.substring(0, 8)}...'),
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
                  const Icon(Icons.gps_fixed, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ubicación GPS validada correctamente',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                      ),
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

  /// Obtener mensaje de error específico para asistencia
  String _getAttendanceErrorMessage(dynamic error) {
    String errorStr = error.toString();
    
    if (errorStr.contains('fuera del perímetro')) {
      return errorStr;
    } else if (errorStr.contains('No se encontró registro de entrada')) {
      return 'Debes marcar tu entrada primero antes de marcar la salida.';
    } else if (errorStr.contains('Obra no encontrada')) {
      return 'La obra asignada no existe. Contacta al administrador.';
    } else if (errorStr.contains('Sin permisos de ubicación')) {
      return 'Necesitas habilitar los permisos de ubicación para marcar asistencia.';
    } else if (errorStr.contains('GPS')) {
      return 'Error al obtener ubicación GPS. Verifica que esté activado.';
    } else {
      return 'Error al registrar asistencia: $errorStr';
    }
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
  // Mostrar resultado de prueba de ubicación
void _showLocationResult(BuildContext context, String type, Position position) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.gps_fixed, color: AppColors.success),
          SizedBox(width: 8),
          Text('Ubicación Obtenida'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ubicación GPS obtenida exitosamente:'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coordenadas:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                Text('Latitud: ${position.latitude.toStringAsFixed(6)}'),
                Text('Longitud: ${position.longitude.toStringAsFixed(6)}'),
                const SizedBox(height: 8),
                Text(
                  'Precisión: ${position.accuracy.toStringAsFixed(1)}m',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  'Timestamp: ${DateTime.fromMillisecondsSinceEpoch(position.timestamp.millisecondsSinceEpoch).toString().substring(0, 19)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
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
}