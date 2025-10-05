import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthService() {
    _initializeAuth();
  }

  /// Inicializar listener de autenticación
  void _initializeAuth() {
    _auth.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        await _loadUserData(firebaseUser.uid);
      } else {
        _currentUser = null;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Cargar datos del usuario desde Firestore
  Future<void> _loadUserData(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _currentUser =
            UserModel.fromFirestore(doc.data() as Map<String, dynamic>, uid);
      }
    } catch (e) {
      print('Error loading user data: $e');
      _errorMessage = 'Error al cargar datos del usuario';
    }
  }

  /// Login para trabajadores (DNI + Password)
  /// Login para trabajadores (DNI + Password)
Future<bool> loginWorker(String dni, String password) async {
  try {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Validaciones básicas
    if (dni.length != 8) {
      _errorMessage = 'El DNI debe tener exactamente 8 dígitos';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (password.length < 6) {
      _errorMessage = 'La contraseña debe tener al menos 6 caracteres';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // PRIMERO: Autenticarse en Firebase Auth con email/password
    String tempEmail = '$dni@crellat.com';
    
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: tempEmail,
        password: password,
      );

      if (result.user != null) {
        // DESPUÉS: Cargar datos del usuario desde Firestore (ya autenticado)
        await _loadUserData(result.user!.uid);
        
        // Verificar que sea trabajador activo
        if (_currentUser?.role != 'trabajador') {
          await signOut();
          _errorMessage = 'No tienes permisos de trabajador';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        
        if (!(_currentUser?.isActive ?? false)) {
          await signOut();
          _errorMessage = 'Tu cuenta está inactiva. Contacta al administrador';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (authError) {
      _errorMessage = _handleError(authError);
      _isLoading = false;
      notifyListeners();
      return false;
    }

    return false;
  } catch (e) {
    _errorMessage = _handleError(e);
    _isLoading = false;
    notifyListeners();
    return false;
  }
}

  /// Cambiar contraseña del usuario actual
  Future<bool> changePassword(String currentPassword, String newPassword) async {
  if (_currentUser == null || _auth.currentUser == null) return false;
  
  try {
    _isLoading = true;
    notifyListeners();

    // Re-autenticar al usuario
    String tempEmail = '${_currentUser!.dni}@crellat.com';
    AuthCredential credential = EmailAuthProvider.credential(
      email: tempEmail, 
      password: currentPassword
    );
    
    await _auth.currentUser!.reauthenticateWithCredential(credential);
    
    // Cambiar contraseña
    await _auth.currentUser!.updatePassword(newPassword);
    
    // NUEVO: Marcar que ya cambió la contraseña
    await markPasswordChanged();
    
    _isLoading = false;
    notifyListeners();
    return true;
  } catch (e) {
    _errorMessage = 'Error al cambiar contraseña: ${_handleError(e)}';
    _isLoading = false;
    notifyListeners();
    return false;
  }
}

  /// Cerrar sesión
  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Limpiar mensajes de error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Obtener información completa del usuario actual
  Future<void> refreshCurrentUser() async {
    if (_auth.currentUser == null) return;

    try {
      await _loadUserData(_auth.currentUser!.uid);
    } catch (e) {
      print('Error refreshing user data: $e');
    }
  }

  /// Getters útiles para trabajadores
  bool get isLoggedIn => _currentUser != null && _auth.currentUser != null;
  bool get isActive => _currentUser?.isActive ?? false;
  String? get workerDni => _currentUser?.dni;
  String? get workerName => _currentUser?.fullName;
  String? get assignedWorksiteId => _currentUser?.assignedWorksiteId;
  String? get currentUserId => _auth.currentUser?.uid;

  /// Verificar permisos específicos de trabajador
  bool get canMarkAttendance => _currentUser?.role == 'trabajador' && isActive;
  bool get canViewHistory => _currentUser?.role == 'trabajador' && isActive;

  /// Manejo de errores con mensajes amigables
  String _handleError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'DNI no registrado en el sistema';
        case 'wrong-password':
          return 'Contraseña incorrecta';
        case 'invalid-email':
          return 'Formato de correo inválido';
        case 'too-many-requests':
          return 'Demasiados intentos fallidos. Espera un momento';
        case 'network-request-failed':
          return 'Error de conexión. Verifica tu internet';
        case 'email-already-in-use':
          return 'Este DNI ya está registrado';
        default:
          return 'Error de autenticación: ${error.message}';
      }
    } else {
      String errorMsg = error.toString();
      if (errorMsg.contains('User account is inactive')) {
        return 'Tu cuenta está inactiva. Contacta al administrador';
      } else {
        return 'Error de conexión. Inténtalo de nuevo';
      }
    }
  }

  /// Método para debugging
  void debugPrintUserInfo() {
    if (_currentUser != null) {
      print('=== TRABAJADOR FIREBASE ===');
      print('UID: ${_currentUser!.uid}');
      print('Nombre: ${_currentUser!.fullName}');
      print('DNI: ${_currentUser!.dni}');
      print('Obra asignada: ${_currentUser!.assignedWorksiteId}');
      print('Activo: ${_currentUser!.isActive}');
      print('Firebase User: ${_auth.currentUser?.email}');
      print('Puede marcar asistencia: $canMarkAttendance');
      print('Puede ver historial: $canViewHistory');
      print('========================');
    }
  }
  Future<void> markPasswordChanged() async {
    if (_auth.currentUser == null) return;
    
    await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
      'hasChangedPassword': true,
    });
    
    await refreshCurrentUser();
  }
}
