import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/attendance_service.dart';
import '../../models/attendance_model.dart';

class WorkerHistoryScreen extends StatefulWidget {
  const WorkerHistoryScreen({super.key});

  @override
  State<WorkerHistoryScreen> createState() => _WorkerHistoryScreenState();
}

class _WorkerHistoryScreenState extends State<WorkerHistoryScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  List<AttendanceModel> _attendances = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedDays = 30;

  @override
  void initState() {
    super.initState();
    _loadAttendanceHistory();
  }

  Future<void> _loadAttendanceHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = context.read<AuthService>();
      final user = authService.currentUser;
      
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      List<AttendanceModel> attendances = await _attendanceService.getWorkerAttendanceHistory(
        workerId: user.uid,
        limitDays: _selectedDays,
      );

      setState(() {
        _attendances = attendances;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Historial'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.filter_list),
            onSelected: (days) {
              setState(() {
                _selectedDays = days;
              });
              _loadAttendanceHistory();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 7, child: Text('Últimos 7 días')),
              const PopupMenuItem(value: 30, child: Text('Últimos 30 días')),
              const PopupMenuItem(value: 90, child: Text('Últimos 3 meses')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Header con estadísticas
          _buildStatsHeader(),
          
          // Lista de asistencias
          Expanded(
            child: _buildAttendanceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    if (_isLoading || _attendances.isEmpty) {
      return const SizedBox.shrink();
    }

    int totalDays = _attendances.length;
    int completeDays = _attendances.where((a) => a.punchIn != null && a.punchOut != null).length;
    double avgHours = _attendances
        .where((a) => a.workedHours != null)
        .map((a) => a.workedHours!)
        .fold(0.0, (sum, hours) => sum + hours) / 
        (_attendances.where((a) => a.workedHours != null).length);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            'Últimos $_selectedDays días',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Días registrados',
                  totalDays.toString(),
                  Icons.calendar_today,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  'Días completos',
                  completeDays.toString(),
                  Icons.check_circle,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  'Hrs promedio',
                  avgHours.isNaN ? '--' : avgHours.toStringAsFixed(1),
                  Icons.schedule,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAttendanceList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando historial...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Error al cargar historial',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAttendanceHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_attendances.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No hay registros',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'No tienes registros de asistencia en los últimos $_selectedDays días.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAttendanceHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _attendances.length,
        itemBuilder: (context, index) {
          return _buildAttendanceCard(_attendances[index]);
        },
      ),
    );
  }

  Widget _buildAttendanceCard(AttendanceModel attendance) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con fecha y estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(attendance.date),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                _buildStatusChip(attendance.status),
              ],
            ),
            const SizedBox(height: 12),
            
            // Información de entrada y salida
            Row(
              children: [
                Expanded(
                  child: _buildTimeInfo(
                    'Entrada',
                    attendance.punchIn?.timestamp,
                    attendance.punchIn?.isValid ?? false,
                    Icons.login,
                    AppColors.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimeInfo(
                    'Salida',
                    attendance.punchOut?.timestamp,
                    attendance.punchOut?.isValid ?? false,
                    Icons.logout,
                    AppColors.error,
                  ),
                ),
              ],
            ),

            // Horas trabajadas si están disponibles
            if (attendance.workedHours != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Total: ${attendance.workedHours!.toStringAsFixed(1)} hrs',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInfo(String label, DateTime? time, bool isValid, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
            if (!isValid && time != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.warning, size: 12, color: AppColors.warning),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          time != null ? _formatTime(time) : '--:--',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: time != null ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'Presente':
        color = AppColors.success;
        break;
      case 'Ausente':
        color = AppColors.error;
        break;
      default:
        color = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    
    String dayName = days[date.weekday - 1];
    String month = months[date.month - 1];
    
    return '$dayName, ${date.day} $month ${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}