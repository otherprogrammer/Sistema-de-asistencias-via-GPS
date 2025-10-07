import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../models/worksite_model.dart';

class SelectWorksiteScreen extends StatefulWidget {
  const SelectWorksiteScreen({super.key});

  @override
  State<SelectWorksiteScreen> createState() => _SelectWorksiteScreenState();
}

class _SelectWorksiteScreenState extends State<SelectWorksiteScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<WorksiteModel> _worksites = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedWorksiteId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadWorksites();
  }

  Future<void> _loadWorksites() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('worksites')
          .orderBy('name')
          .get();

      List<WorksiteModel> worksites = querySnapshot.docs.map((doc) {
        return WorksiteModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();

      setState(() {
        _worksites = worksites;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar obras: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // No permitir retroceder
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Selecciona tu Obra'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          automaticallyImplyLeading: false,
        ),
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Cargando obras disponibles...'),
                  ],
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text(_errorMessage!),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadWorksites,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  )
                : _worksites.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.construction, size: 64, color: AppColors.textSecondary),
                            SizedBox(height: 16),
                            Text('No hay obras disponibles'),
                            SizedBox(height: 8),
                            Text(
                              'Contacta al administrador para asignarte a una obra',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha:0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primary),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.location_city, color: AppColors.primary, size: 48),
                                  SizedBox(height: 12),
                                  Text(
                                    'Selecciona tu obra',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Elige la obra donde trabajarás. Esta selección es permanente y solo puede ser modificada por el administrador.',
                                    style: TextStyle(color: AppColors.textSecondary),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Lista de obras
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _worksites.length,
                              itemBuilder: (context, index) {
                                return _buildWorksiteCard(_worksites[index]);
                              },
                            ),

                            const SizedBox(height: 24),

                            // Botón de confirmar
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: (_selectedWorksiteId == null || _isSaving)
                                    ? null
                                    : _handleConfirmSelection,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Confirmar Selección',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
      ),
    );
  }

  Widget _buildWorksiteCard(WorksiteModel worksite) {
    bool isSelected = _selectedWorksiteId == worksite.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedWorksiteId = worksite.id;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppColors.primary 
                      : AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.construction,
                  color: isSelected ? Colors.white : AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worksite.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Radio: ${worksite.radius.toStringAsFixed(0)}m',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleConfirmSelection() async {
    if (_selectedWorksiteId == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final authService = context.read<AuthService>();
      final user = authService.currentUser;

      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Actualizar usuario en Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'assignedWorksiteId': _selectedWorksiteId,
        'hasSelectedWorksite': true,
      });

      // Refrescar datos del usuario en AuthService
      await authService.refreshCurrentUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Obra asignada correctamente'),
            backgroundColor: AppColors.success,
          ),
        );

        // Navegar a la pantalla principal
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}