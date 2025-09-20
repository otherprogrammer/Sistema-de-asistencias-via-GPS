import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _workerFormKey = GlobalKey<FormState>();
  final _adminFormKey = GlobalKey<FormState>();

  // Worker login controllers
  final _dniController = TextEditingController();
  final _workerPasswordController = TextEditingController();

  // Admin login controllers
  final _emailController = TextEditingController();
  final _adminPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dniController.dispose();
    _workerPasswordController.dispose();
    _emailController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Control de Asistencia'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Trabajador'),
            Tab(text: 'Administrador'),
          ],
        ),
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildWorkerLogin(authService),
              _buildAdminLogin(authService),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWorkerLogin(AuthService authService) {
    return Padding(
      padding: EdgeInsets.all(24.0),
      child: Form(
        key: _workerFormKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.engineering,
              size: 80,
              color: Colors.blue,
            ),
            SizedBox(height: 32),
            Text(
              'Ingreso Trabajador',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 32),
            TextFormField(
              controller: _dniController,
              decoration: InputDecoration(
                labelText: 'Número de DNI',
                prefixIcon: Icon(Icons.badge),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingrese su DNI';
                }
                if (value.length != 8) {
                  return 'El DNI debe tener 8 dígitos';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _workerPasswordController,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingrese su contraseña';
                }
                return null;
              },
            ),
            SizedBox(height: 24),
            if (authService.errorMessage != null)
              Container(
                padding: EdgeInsets.all(8),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  authService.errorMessage!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: authService.isLoading
                    ? null
                    : () => _handleWorkerLogin(authService),
                child: authService.isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Iniciar Sesión'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminLogin(AuthService authService) {
    return Padding(
      padding: EdgeInsets.all(24.0),
      child: Form(
        key: _adminFormKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.admin_panel_settings,
              size: 80,
              color: Colors.orange,
            ),
            SizedBox(height: 32),
            Text(
              'Panel Administrativo',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 32),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Correo Electrónico',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingrese su correo';
                }
                if (!value.contains('@')) {
                  return 'Ingrese un correo válido';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _adminPasswordController,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingrese su contraseña';
                }
                return null;
              },
            ),
            SizedBox(height: 24),
            if (authService.errorMessage != null)
              Container(
                padding: EdgeInsets.all(8),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  authService.errorMessage!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: authService.isLoading
                    ? null
                    : () => _handleAdminLogin(authService),
                child: authService.isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Acceder al Panel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleWorkerLogin(AuthService authService) async {
    if (_workerFormKey.currentState!.validate()) {
      authService.clearError();
      bool success = await authService.loginWorker(
        _dniController.text.trim(),
        _workerPasswordController.text,
      );

      if (!success) {
        // Error message is already set in AuthService
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al iniciar sesión'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleAdminLogin(AuthService authService) async {
    if (_adminFormKey.currentState!.validate()) {
      authService.clearError();
      bool success = await authService.loginAdmin(
        _emailController.text.trim(),
        _adminPasswordController.text,
      );

      if (!success) {
        // Error message is already set in AuthService
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al acceder al panel'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
