import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../constants/app_colors.dart';

class FaceCaptureScreen extends StatefulWidget {
  final bool isRegistration; // true = primer registro, false = verificación
  final String title;

  const FaceCaptureScreen({
    super.key,
    this.isRegistration = false,
    this.title = 'Captura de Rostro',
  });

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  //bool _faceDetected = false;
  List<CameraDescription> _cameras = []; // 🆕 Lista de cámaras disponibles
  int _currentCameraIndex = 0; // 🆕 Índice de cámara actual
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
    ),
  );

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        if (mounted) {
          _showErrorDialog('No se encontraron cámaras en el dispositivo.');
        }
        return;
      }

      // 🔧 Buscar índice de cámara frontal
      _currentCameraIndex = _cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      // Si no hay frontal, usar la primera
      if (_currentCameraIndex == -1) {
        _currentCameraIndex = 0;
      }

      print('✅ Usando cámara: ${_cameras[_currentCameraIndex].name}');

      _cameraController = CameraController(
        _cameras[_currentCameraIndex],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
        print('📸 Cámara inicializada correctamente');
      }
    } catch (e) {
      print('❌ Error inicializando cámara: $e');
      if (mounted) {
        _showErrorDialog(
            'No se pudo acceder a la cámara. Verifica los permisos.');
      }
    }
  }

  // 🆕 Cambiar entre cámaras
  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;

    setState(() {
      _isCameraInitialized = false;
    });

    await _cameraController?.dispose();

    // Cambiar al siguiente índice
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;

    _cameraController = CameraController(
      _cameras[_currentCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _cameraController!.initialize();

    if (mounted) {
      setState(() {
        _isCameraInitialized = true;
      });
    }
  }

  Future<void> _captureAndProcessFace() async {
    if (_isProcessing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Capturar imagen
      final XFile imageFile = await _cameraController!.takePicture();
      final File capturedImage = File(imageFile.path);

      // 2. Detectar rostro con ML Kit
      final InputImage inputImage = InputImage.fromFile(capturedImage);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        if (mounted) {
          _showWarningDialog(
            'No se detectó ningún rostro',
            'Asegúrate de que tu rostro esté bien iluminado y dentro del marco.',
          );
        }
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      if (faces.length > 1) {
        if (mounted) {
          _showWarningDialog(
            'Múltiples rostros detectados',
            'Asegúrate de que solo tu rostro esté visible en la cámara.',
          );
        }
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // 3. Verificar calidad del rostro
      final Face face = faces.first;

      // Verificar que el rostro esté de frente (solo ángulo Y)
      final double? headEulerAngleY = face.headEulerAngleY;

      if (headEulerAngleY != null && headEulerAngleY.abs() > 15) {
        if (mounted) {
          _showWarningDialog(
            'Rostro no está de frente',
            'Mira directamente a la cámara.',
          );
        }
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // 4. Rostro válido, devolver imagen
      if (mounted) {
        Navigator.of(context).pop(capturedImage);
      }
    } catch (e) {
      print('❌ Error capturando rostro: $e');
      if (mounted) {
        _showErrorDialog('Error al procesar la imagen. Intenta nuevamente.');
      }
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          // 🆕 Botón para cambiar cámara
          if (_cameras.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
              onPressed:
                  _isCameraInitialized && !_isProcessing ? _switchCamera : null,
              tooltip: 'Cambiar cámara',
            ),
        ],
      ),
      body: Stack(
        children: [
          // Vista previa de la cámara
          if (_isCameraInitialized)
            Center(
              child: CameraPreview(_cameraController!),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),

          // Overlay con guía de rostro
          if (_isCameraInitialized)
            CustomPaint(
              painter: FaceOverlayPainter(),
              child: Container(),
            ),

          // Instrucciones
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.face, color: Colors.white, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    widget.isRegistration
                        ? 'Registra tu rostro'
                        : 'Verifica tu identidad',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Coloca tu rostro dentro del óvalo\n'
                    '• Asegúrate de tener buena iluminación\n'
                    '• Mira directamente a la cámara',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Botón de captura
          if (_isCameraInitialized)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _isProcessing ? null : _captureAndProcessFace,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isProcessing ? Colors.grey : AppColors.primary,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: _isProcessing
                        ? const Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 40,
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showWarningDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.warning, color: AppColors.warning, size: 24),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Entendido'),
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
                color: AppColors.error.withValues(alpha: 0.1),
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

/// Painter para dibujar la guía del rostro (óvalo)
class FaceOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final center = Offset(size.width / 2, size.height / 2);
    final ovalWidth = size.width * 0.6;
    final ovalHeight = size.height * 0.4;

    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: ovalWidth,
        height: ovalHeight,
      ),
      paint,
    );

    // Dibujar fondo oscuro fuera del óvalo
    final darkPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCenter(
        center: center,
        width: ovalWidth,
        height: ovalHeight,
      ))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, darkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
