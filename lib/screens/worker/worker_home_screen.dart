import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/attendance_service.dart';
import '../../constants/app_colors.dart';
import 'worker_history_screen.dart';
import 'change_password_screen.dart';
import '../../services/offline_sync_service.dart';
import 'dart:async';
import '../../services/face_recognition_service.dart';
import 'face_capture_screen.dart';
import 'dart:io';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> with TickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  final AttendanceService _attendanceService = AttendanceService();
  final OfflineSyncService _offlineSync = OfflineSyncService();
  final FaceRecognitionService _faceRecognitionService = FaceRecognitionService();

  int _pendingSyncCount = 0;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isProcessingLocation = false;
  bool _hasCheckedInToday = false;
  bool _hasCheckedOutToday = false;
  bool _isLoadingStatus = true;
  bool _hasInitialized = false;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTodayAttendanceStatus();
      _checkPendingSync();
      _startAutoSync();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkTodayAttendanceStatus() async {
    if (!mounted) return;

    setState(() {
      _isLoadingStatus = true;
    });

    try {
      final authService = context.read<AuthService>();
      final user = authService.currentUser;
      
      if (user != null) {
        print('🔍 Verificando asistencia para usuario: ${user.uid}');
        
        bool hasCheckIn = await _attendanceService.hasCheckedInToday(user.uid);
        bool hasCheckOut = await _attendanceService.hasCheckedOutToday(user.uid);
        
        print('✅ Estado: Entrada=$hasCheckIn, Salida=$hasCheckOut');
        
        if (mounted) {
          setState(() {
            _hasCheckedInToday = hasCheckIn;
            _hasCheckedOutToday = hasCheckOut;
            _isLoadingStatus = false;
            _hasInitialized = true;
          });
        }
      } else {
        print('⚠️ Usuario no disponible en AuthService');
        if (mounted) {
          setState(() {
            _isLoadingStatus = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error checking attendance status: $e');
      if (mounted) {
        setState(() {
          _isLoadingStatus = false;
        });
      }
    }
  }

  Future<void> _refreshAttendanceStatus() async {
    await _checkTodayAttendanceStatus();
  }

  Future<void> _checkPendingSync() async {
    int count = await _offlineSync.getPendingCount();
    if (mounted) {
      setState(() {
        _pendingSyncCount = count;
      });
    }
  }

  void _startAutoSync() {
    _connectivitySubscription = _offlineSync.watchConnectivity().listen((results) async {
      if (results.isNotEmpty && !results.contains(ConnectivityResult.none)) {
        print('📶 Conexión detectada: $results');
        await _syncPendingAttendances();
      }
    });
  }

  Future<void> _syncPendingAttendances() async {
    int count = await _offlineSync.getPendingCount();
    if (count == 0) return;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SpinKitFadingCircle(color: AppColors.primary, size: 60),
                const SizedBox(height: 24),
                Text(
                  'Sincronizando $count marca${count > 1 ? 's' : ''} pendiente${count > 1 ? 's' : ''}...',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    try {
      SyncResult result = await _offlineSync.syncPendingAttendances();
      
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      await _checkPendingSync();
      await _refreshAttendanceStatus();

      if (mounted) {
        if (result.success) {
          _showSuccessSyncDialog(result);
        } else {
          _showErrorDialog(context, result.message);
        }
      }
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        _showErrorDialog(context, 'Error al sincronizar: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: FadeInDown(
          child: const Text(
            'Control Asistencia',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        actions: [
          if (_pendingSyncCount > 0)
            FadeInDown(
              delay: const Duration(milliseconds: 100),
              child: IconButton(
                icon: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.cloud_upload, size: 20, color: Colors.orange),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_pendingSyncCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                onPressed: _syncPendingAttendances,
                tooltip: 'Sincronizar marcas pendientes',
              ),
            ),
          FadeInDown(
            delay: const Duration(milliseconds: 200),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout, size: 20, color: Colors.white),
              ),
              onPressed: () => _showLogoutConfirmation(context),
            ),
          ),
        ],
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, _) {
          final user = authService.currentUser;

          if (user != null && !_hasInitialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkTodayAttendanceStatus();
            });
          }

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary,
                  AppColors.primaryDark,
                  AppColors.background,
                  AppColors.background,
                ],
                stops: [0.0, 0.3, 0.5, 1.0],
              ),
            ),
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: _refreshAttendanceStatus,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      
                      FadeInDown(
                        delay: const Duration(milliseconds: 300),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppColors.primary, AppColors.primaryDark],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.person, color: Colors.white, size: 35),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user!.fullName,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'DNI: ${user.dni}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Trabajador',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      FadeInUp(
                        delay: const Duration(milliseconds: 400),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.1),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.location_on, color: AppColors.primary, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Ubicación GPS requerida',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.refresh,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                    onPressed: _isLoadingStatus ? null : _refreshAttendanceStatus,
                                    tooltip: 'Refrescar estado',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildAttendanceStatus(),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      FadeInUp(
                        delay: const Duration(milliseconds: 500),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                onPressed: (_isProcessingLocation || _isLoadingStatus || _hasCheckedInToday) 
                                    ? null 
                                    : () => _handleMarkAttendance(context, 'entrada'),
                                label: _hasCheckedInToday ? 'Entrada\nRegistrada' : 'Marcar\nEntrada',
                                icon: _hasCheckedInToday ? Icons.check_circle : Icons.login,
                                gradient: _hasCheckedInToday 
                                    ? [Colors.grey, Colors.grey.shade400]
                                    : [AppColors.success, AppColors.success.withOpacity(0.7)],
                                isLoading: _isProcessingLocation && !_hasCheckedInToday,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildActionButton(
                                onPressed: (_isProcessingLocation || _isLoadingStatus || _hasCheckedOutToday) 
                                    ? null 
                                    : () {
                                        if (!_hasCheckedInToday) {
                                          _showWarningDialog(
                                            context, 
                                            'Debes marcar entrada primero', 
                                            'No puedes marcar salida sin haber marcado entrada.'
                                          );
                                        } else {
                                          _handleMarkAttendance(context, 'salida');
                                        }
                                      },
                                label: _hasCheckedOutToday ? 'Salida\nRegistrada' : 'Marcar\nSalida',
                                icon: _hasCheckedOutToday ? Icons.check_circle : Icons.logout,
                                gradient: _hasCheckedOutToday 
                                    ? [Colors.grey, Colors.grey.shade400]
                                    : [AppColors.error, AppColors.error.withOpacity(0.7)],
                                isLoading: _isProcessingLocation && !_hasCheckedOutToday,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      FadeInUp(
                        delay: const Duration(milliseconds: 600),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildMenuTile(
                                icon: Icons.history,
                                title: 'Ver Historial',
                                subtitle: 'Consulta tus registros',
                                color: AppColors.primary,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (context) => const WorkerHistoryScreen()),
                                  );
                                },
                              ),
                              _buildDivider(),
                              _buildMenuTile(
                                icon: Icons.lock_reset,
                                title: 'Cambiar Contraseña',
                                subtitle: 'Actualiza tu contraseña',
                                color: AppColors.warning,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const ChangePasswordScreen(isFirstTime: false),
                                    ),
                                  );
                                },
                              ),
                              _buildDivider(),
                              _buildMenuTile(
                                icon: Icons.location_searching,
                                title: 'Probar Ubicación',
                                subtitle: 'Verificar GPS y permisos',
                                color: AppColors.success,
                                onTap: () => _testLocation(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required String label,
    required IconData icon,
    required List<Color> gradient,
    required bool isLoading,
  }) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(20),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: gradient[0].withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isLoading
                ? const Center(
                    child: SpinKitFadingCircle(color: Colors.white, size: 35),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1, color: Colors.grey.shade200),
    );
  }

  Widget _buildAttendanceStatus() {
    if (_isLoadingStatus) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Verificando estado...',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatusIndicator('Entrada', _hasCheckedInToday, AppColors.success),
          Container(width: 1, height: 30, color: Colors.grey.shade300),
          _buildStatusIndicator('Salida', _hasCheckedOutToday, AppColors.error),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String label, bool isCompleted, Color activeColor) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isCompleted ? activeColor.withOpacity(0.1) : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted ? activeColor : AppColors.textSecondary,
            size: 20,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isCompleted ? activeColor : AppColors.textSecondary,
            fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout, color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Cerrar Sesión', style: TextStyle(fontSize: 20)),
          ],
        ),
        content: const Text('¿Estás seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<AuthService>().signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMarkAttendance(BuildContext context, String type) async {
  if (_isProcessingLocation) return;

  final authService = context.read<AuthService>();
  final user = authService.currentUser;
  
  if (user == null || user.assignedWorksiteId == null) {
    _showErrorDialog(context, 'Usuario o obra no válidos');
    return;
  }

  if (type == 'entrada' && _hasCheckedInToday) {
    _showWarningDialog(context, 'Ya registraste tu entrada hoy', 
        'Solo puedes marcar una entrada por día.');
    return;
  }

  if (type == 'salida') {
    if (!_hasCheckedInToday) {
      _showWarningDialog(context, 'Debes marcar entrada primero', 
          'No puedes marcar salida sin haber marcado entrada.');
      return;
    }
    if (_hasCheckedOutToday) {
      _showWarningDialog(context, 'Ya registraste tu salida hoy', 
          'Solo puedes marcar una salida por día.');
      return;
    }
  }

  setState(() {
    _isProcessingLocation = true;
  });

  try {
    // 🆕 PASO 1: VERIFICACIÓN FACIAL
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.face, color: AppColors.primary, size: 60),
              const SizedBox(height: 24),
              Text(
                'Verificando identidad...',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );

    // Abrir cámara para captura de rostro
    if (context.mounted) {
      Navigator.of(context).pop(); // Cerrar diálogo de "verificando"
    }

    final File? capturedImage = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (context) => FaceCaptureScreen(
          isRegistration: false,
          title: 'Verifica tu identidad',
        ),
      ),
    );

    if (capturedImage == null) {
      // Usuario canceló
      setState(() {
        _isProcessingLocation = false;
      });
      return;
    }

    // Mostrar diálogo de procesamiento
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: const Padding(
            padding: EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SpinKitFadingCircle(color: AppColors.primary, size: 60),
                SizedBox(height: 24),
                Text(
                  'Verificando rostro...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Verificar rostro
    FaceVerificationResult verificationResult = await _faceRecognitionService.verifyFace(
      userId: user.uid,
      capturedImage: capturedImage,
    );

    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(); // Cerrar diálogo de verificación
    }

    // Si el rostro NO coincide
    if (!verificationResult.isMatch) {
      if (context.mounted) {
        _showFaceVerificationFailedDialog(
          context,
          verificationResult.similarity,
          type,
        );
      }
      setState(() {
        _isProcessingLocation = false;
      });
      return;
    }

    // ✅ ROSTRO VERIFICADO - Continuar con el flujo normal (GPS)
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SpinKitFadingCircle(color: AppColors.primary, size: 60),
                const SizedBox(height: 24),
                Text(
                  '${type == 'entrada' ? 'Marcando entrada' : 'Marcando salida'}...',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 🆕 PASO 2: VALIDACIÓN GPS Y REGISTRO (código original)
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
    
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    await _refreshAttendanceStatus();

    if (context.mounted) {
      _showSuccessDialog(context, type, attendanceId);
    }

  } catch (e) {
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    if (context.mounted) {
      if (e is OfflineException) {
        await _checkPendingSync();
        _showOfflineSuccessDialog(context, e.message);
      } else {
        String errorMsg = _getAttendanceErrorMessage(e);
        _showErrorDialog(context, errorMsg);
      }
    }
  } finally {
    setState(() {
      _isProcessingLocation = false;
    });
  }
}
  void _showWarningDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning, color: AppColors.warning, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, String type, String attendanceId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle, color: AppColors.success, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${type.toUpperCase()} Registrada',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tu $type ha sido registrada exitosamente.'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Hora: ${DateTime.now().toString().substring(11, 16)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.fingerprint, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ID: ${attendanceId.substring(0, 8)}...',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.gps_fixed, color: AppColors.success, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ubicación GPS validada',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _getAttendanceErrorMessage(dynamic error) {
    String errorStr = error.toString();
    
    if (errorStr.contains('fuera del perímetro')) {
      return errorStr;
    } else if (errorStr.contains('No se encontró registro de entrada')) {
      return 'Debes marcar tu entrada primero.';
    } else if (errorStr.contains('Obra no encontrada')) {
      return 'La obra asignada no existe.';
    } else if (errorStr.contains('Sin permisos de ubicación')) {
      return 'Habilita los permisos de ubicación.';
    } else if (errorStr.contains('GPS')) {
      return 'Error al obtener ubicación GPS.';
    } else {
      return 'Error: $errorStr';
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.error_outline, color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          if (!kIsWeb)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Configuración'),
            ),
        ],
      ),
    );
  }

  Future<void> _testLocation(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: const Padding(
            padding: EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SpinKitFadingCircle(color: AppColors.primary, size: 60),
                SizedBox(height: 24),
                Text(
                  'Probando ubicación GPS...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );

      Position? position = await _locationService.getCurrentLocation();
      
      if (context.mounted) {
        Navigator.of(context).pop();
        
        if (position != null) {
          _showLocationResult(context, position);
        } else {
          _showErrorDialog(context, 'No se pudo obtener ubicación');
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        String errorMsg = _locationService.getLocationErrorMessage(e);
        _showErrorDialog(context, errorMsg);
      }
    }
  }

  void _showLocationResult(BuildContext context, Position position) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.gps_fixed, color: AppColors.success, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Ubicación Obtenida',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('GPS obtenido exitosamente:'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildInfoRow(Icons.location_on, 'Latitud', position.latitude.toStringAsFixed(6)),
                    const SizedBox(height: 6),
                    _buildInfoRow(Icons.location_on, 'Longitud', position.longitude.toStringAsFixed(6)),
                    const SizedBox(height: 6),
                    _buildInfoRow(Icons.my_location, 'Precisión', '${position.accuracy.toStringAsFixed(1)}m'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  void _showSuccessSyncDialog(SyncResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cloud_done, color: AppColors.success, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Sincronización Completa', style: TextStyle(fontSize: 18))),
          ],
        ),
        content: Text(
          '${result.synced} marca${result.synced > 1 ? 's' : ''} sincronizada${result.synced > 1 ? 's' : ''} exitosamente.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showOfflineSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cloud_off, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Guardado Offline', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'La validación de ubicación se realizará al sincronizar',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
  void _showFaceVerificationFailedDialog(BuildContext context, double similarity, String type) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.face, color: AppColors.error, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Verificación Fallida', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'El rostro capturado no coincide con el registrado.',
            style: TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.analytics, color: AppColors.textSecondary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Similitud: ${similarity.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Asegúrate de:\n'
            '• Tener buena iluminación\n'
            '• Mirar directamente a la cámara\n'
            '• No usar lentes oscuros o gorros',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            // Reintentar automáticamente
            _handleMarkAttendance(context, type);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Reintentar'),
        ),
      ],
    ),
  );
}
}