import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/face_model.dart';
import 'tflite_service.dart';

/// Servicio para gestionar reconocimiento facial
class FaceRecognitionService {
  static final FaceRecognitionService _instance = FaceRecognitionService._internal();
  factory FaceRecognitionService() => _instance;
  FaceRecognitionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TFLiteService _tfliteService = TFLiteService();

  /// Registrar rostro del usuario (primera vez)
  Future<void> registerFace({
    required String userId,
    required File imageFile,
  }) async {
    try {
      print('📸 Registrando rostro para usuario: $userId');

      // 1. Extraer embedding de la imagen
      List<double> embedding = await _tfliteService.getEmbedding(imageFile);

      // 2. Crear modelo de datos
      FaceData faceData = FaceData(
        userId: userId,
        embedding: embedding,
        registeredAt: DateTime.now(),
      );

      // 3. Guardar en Firestore
      await _firestore.collection('users').doc(userId).update(faceData.toFirestore());

      print('✅ Rostro registrado exitosamente para $userId');
    } catch (e) {
      print('❌ Error registrando rostro: $e');
      rethrow;
    }
  }

  /// Verificar si el rostro capturado coincide con el registrado
  Future<FaceVerificationResult> verifyFace({
    required String userId,
    required File capturedImage,
  }) async {
    try {
      print('🔍 Verificando rostro para usuario: $userId');

      // 1. Obtener embedding registrado desde Firestore
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        throw Exception('Usuario no encontrado');
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      if (userData['faceEmbedding'] == null) {
        throw Exception('El usuario no tiene rostro registrado');
      }

      List<double> registeredEmbedding = List<double>.from(userData['faceEmbedding']);

      // 2. Extraer embedding de la imagen capturada
      List<double> capturedEmbedding = await _tfliteService.getEmbedding(capturedImage);

      // 3. Calcular similitud
      double similarity = FaceData.calculateSimilarity(registeredEmbedding, capturedEmbedding);

      // 4. Verificar si coincide (threshold: 60% para MobileFaceNet 128D con similitud del coseno)
      // Para FaceNet 512D usar 70-75%
      bool isMatch = similarity >= 70.0;

      print('📊 Similitud: ${similarity.toStringAsFixed(2)}%');
      print('   Embedding registrado (primeros 5): ${registeredEmbedding.take(5).map((e) => e.toStringAsFixed(4)).join(', ')}');
      print('   Embedding capturado (primeros 5): ${capturedEmbedding.take(5).map((e) => e.toStringAsFixed(4)).join(', ')}');
      print('   Threshold: 45% | Resultado: ${isMatch ? '✅ MATCH' : '❌ NO MATCH'}');
      print(isMatch ? '✅ Rostro verificado' : '❌ Rostro no coincide');

      return FaceVerificationResult(
        isMatch: isMatch,
        similarity: similarity,
        userId: userId,
      );
    } catch (e) {
      print('❌ Error verificando rostro: $e');
      rethrow;
    }
  }

  /// Verificar si el usuario tiene rostro registrado
  Future<bool> hasFaceRegistered(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) return false;

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      return userData['faceRegistered'] == true && userData['faceEmbedding'] != null;
    } catch (e) {
      print('❌ Error verificando rostro registrado: $e');
      return false;
    }
  }

  /// Actualizar rostro (si el usuario quiere re-registrarse)
  Future<void> updateFace({
    required String userId,
    required File imageFile,
  }) async {
    await registerFace(userId: userId, imageFile: imageFile);
  }

  /// Eliminar rostro registrado
  Future<void> deleteFace(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'faceEmbedding': FieldValue.delete(),
        'faceRegistered': false,
        'faceRegisteredAt': FieldValue.delete(),
        'faceImageUrl': FieldValue.delete(),
      });
      print('🗑️ Rostro eliminado para usuario: $userId');
    } catch (e) {
      print('❌ Error eliminando rostro: $e');
      rethrow;
    }
  }
}

/// Resultado de la verificación facial
class FaceVerificationResult {
  final bool isMatch;
  final double similarity;
  final String userId;

  FaceVerificationResult({
    required this.isMatch,
    required this.similarity,
    required this.userId,
  });

  @override
  String toString() {
    return 'FaceVerificationResult(isMatch: $isMatch, similarity: ${similarity.toStringAsFixed(2)}%, userId: $userId)';
  }
}