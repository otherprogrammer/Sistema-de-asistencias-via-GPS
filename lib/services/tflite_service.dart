import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:typed_data';

/// Servicio para manejar TensorFlow Lite y extracción de embeddings con FaceNet
class TFLiteService {
  static final TFLiteService _instance = TFLiteService._internal();
  factory TFLiteService() => _instance;
  TFLiteService._internal();

  Interpreter? _interpreter;
  bool _isInitialized = false;

  // Configuración del modelo FaceNet
  static const int inputSize = 160; // FaceNet usa 160x160
  static const int outputSize = 512; // FaceNet genera embeddings de 512 dimensiones

  /// Inicializar el intérprete de TFLite
  Future<void> initialize() async {
    if (_isInitialized) {
      print('✅ TFLite ya está inicializado');
      return;
    }

    try {
      print('🔄 Inicializando TFLite con FaceNet...');
      
      // Cargar el modelo desde assets
      _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      
      _isInitialized = true;
      print('✅ TFLite inicializado correctamente');
      print('📊 Modelo FaceNet cargado (160x160 -> 512 dimensiones)');
    } catch (e) {
      print('❌ Error inicializando TFLite: $e');
      rethrow;
    }
  }

  /// Extraer embedding de una imagen
  Future<List<double>> getEmbedding(File imageFile) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      print('📸 Procesando imagen para extraer embedding...');

      // 1. Leer y decodificar imagen
      img.Image? image = img.decodeImage(imageFile.readAsBytesSync());
      if (image == null) {
        throw Exception('No se pudo decodificar la imagen');
      }

      // 2. Redimensionar a 160x160
      img.Image resized = img.copyResize(image, width: inputSize, height: inputSize);

      // 3. Convertir a Float32List [1, 160, 160, 3]
      var inputBytes = _imageToFloat32List(resized);

      // 4. Preparar buffers
      var input = inputBytes.reshape([1, inputSize, inputSize, 3]);
      
      // Output: [1, 512] - solo reshape el contenedor, no los datos
      var output = List.filled(1, List<double>.filled(outputSize, 0.0));

      // 5. Ejecutar inferencia
      _interpreter!.run(input, output);

      // 6. Extraer embedding (ya es List<double>)
      List<double> embedding = output[0];

      print('✅ Embedding extraído: ${embedding.length} dimensiones');
      return embedding;
    } catch (e) {
      print('❌ Error extrayendo embedding: $e');
      rethrow;
    }
  }

  /// Convertir imagen a Float32List normalizado
  Float32List _imageToFloat32List(img.Image image) {
    // Buffer para [160, 160, 3] = 76,800 valores
    var convertedBytes = Float32List(inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        var pixel = image.getPixel(x, y);
        
        // Normalizar RGB a [0, 1]
        buffer[pixelIndex++] = pixel.r / 255.0;
        buffer[pixelIndex++] = pixel.g / 255.0;
        buffer[pixelIndex++] = pixel.b / 255.0;
      }
    }

    return convertedBytes;
  }

  /// Liberar recursos
  void dispose() {
    _interpreter?.close();
    _isInitialized = false;
    print('🧹 TFLite resources disposed');
  }
}

/// Extensión para reshape compatible con tflite_flutter 0.9.0
extension ReshapeExtension on Float32List {
  List<List<List<List<double>>>> reshape(List<int> shape) {
    if (shape.length != 4) {
      throw Exception('Shape debe tener 4 dimensiones');
    }

    int batch = shape[0];
    int height = shape[1];
    int width = shape[2];
    int channels = shape[3];

    var result = List.generate(
      batch,
      (_) => List.generate(
        height,
        (y) => List.generate(
          width,
          (x) => List.generate(
            channels,
            (c) {
              int index = y * width * channels + x * channels + c;
              return this[index];
            },
          ),
        ),
      ),
    );

    return result;
  }
}