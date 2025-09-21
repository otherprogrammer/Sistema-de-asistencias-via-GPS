import 'package:flutter/material.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthService() {
    _isLoading = false;
  }

  // Login for Workers (DNI + Password) - MOCK VERSION
  Future<bool> loginWorker(String dni, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Simulate network delay
      await Future.delayed(Duration(seconds: 1));

      // MOCK: Simple validation
      if (dni.length == 8 && password.length >= 6) {
        _currentUser = UserModel(
          uid: 'worker_$dni',
          role: 'trabajador',
          dni: dni,
          fullName: 'Trabajador Test',
          assignedWorksiteId: 'obra_001',
        );
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'DNI debe tener 8 dígitos y contraseña mínimo 6 caracteres';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error de conexión';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Login for Admins (Email + Password) - MOCK VERSION
  Future<bool> loginAdmin(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Simulate network delay
      await Future.delayed(Duration(seconds: 1));

      // MOCK: Simple validation
      if (email.contains('@') && password.length >= 6) {
        _currentUser = UserModel(
          uid: 'admin_${email.split('@')[0]}',
          role: 'admin',
          email: email,
          fullName: 'Admin Test',
        );
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Email inválido o contraseña muy corta';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error de conexión';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}