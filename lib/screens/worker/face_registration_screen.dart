import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/face_recognition_service.dart';
import 'face_capture_screen.dart';
import 'worker_home_screen.dart';

class FaceRegistrationScreen extends StatefulWidget {
  const FaceRegistrationScreen({super.key});

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen> {
  final FaceRecognitionService _faceService = FaceRecognitionService();
  bool _isProcessing = false;
  File? _capturedImage;

  Future<void> _captureFace() async {
    // Abrir pantalla de captura
    final File? capturedImage = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (context) => const FaceCaptureScreen(
          isRegistration: true,
          title: 'Registra tu Rostro',
        ),
      ),
    );

    if (capturedImage != null) {
      setState(() {
        _capturedImage = capturedImage;
      });
    }
  }

  Future<void> _registerFace() async {
    if (_capturedImage == null) {
      _showErrorDialog('Debes capturar tu rostro primero');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final authService = context.read<AuthService>();
      final user = authService.currentUser;

      if (user == null) {
        throw Exception('Usuario no disponible');
      }

      // Mostrar diálogo de procesamiento
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: const Padding(
            padding: EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SpinKitFadingCircle(color: AppColors.primary, size: 60),
                SizedBox(height: 24),
                Text(
                  'Registrando tu rostro...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );

      // Registrar rostro
      await _faceService.registerFace(
        userId: user.uid,
        imageFile: _capturedImage!,
      );

      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // Cerrar diálogo
      }

      // Mostrar éxito y navegar a Home
      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // Cerrar diálogo
      }

      if (mounted) {
        _showErrorDialog('Error al registrar rostro: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Registro Facial',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Ícono principal
              FadeInDown(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.face, color: Colors.white, size: 60),
                ),
              ),

              const SizedBox(height: 32),

              // Título y descripción
              FadeInUp(
                delay: const Duration(milliseconds: 100),
                child: const Text(
                  'Configura tu Reconocimiento Facial',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 16),

              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: const Text(
                  'Tu rostro se utilizará para verificar tu identidad al marcar asistencia.',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 40),

              // Vista previa de la imagen capturada
              if (_capturedImage != null)
                FadeInUp(
                  delay: const Duration(milliseconds: 300),
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: Image.file(
                        _capturedImage!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 40),

              // Instrucciones
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildInstructionTile(
                        icon: Icons.wb_sunny,
                        title: 'Buena iluminación',
                        subtitle: 'Asegúrate de tener luz suficiente',
                      ),
                      const Divider(height: 24),
                      _buildInstructionTile(
                        icon: Icons.face,
                        title: 'Rostro visible',
                        subtitle: 'Sin lentes oscuros, gorros o mascarillas',
                      ),
                      const Divider(height: 24),
                      _buildInstructionTile(
                        icon: Icons.center_focus_strong,
                        title: 'De frente',
                        subtitle: 'Mira directamente a la cámara',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Botones de acción
              FadeInUp(
                delay: const Duration(milliseconds: 500),
                child: Column(
                  children: [
                    // Botón capturar/recapturar
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _captureFace,
                        icon: Icon(
                          _capturedImage == null
                              ? Icons.camera_alt
                              : Icons.refresh,
                        ),
                        label: Text(
                          _capturedImage == null
                              ? 'Capturar Rostro'
                              : 'Recapturar',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ),

                    if (_capturedImage != null) ...[
                      const SizedBox(height: 16),

                      // Botón confirmar
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _registerFace,
                          icon: const Icon(Icons.check_circle),
                          label: const Text(
                            'Confirmar y Continuar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle,
                  color: AppColors.success, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child:
                  Text('¡Rostro Registrado!', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: const Text(
          'Tu rostro ha sido registrado exitosamente.\n\n'
          'A partir de ahora, se verificará tu identidad al marcar asistencia.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Cerrar diálogo
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                    builder: (context) => const WorkerHomeScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ir al Inicio'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.error_outline,
                  color: AppColors.error, size: 24),
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
        ],
      ),
    );
  }
}
