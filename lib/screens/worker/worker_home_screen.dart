import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class WorkerHomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Control Asistencia'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              context.read<AuthService>().signOut();
            },
          ),
        ],
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, _) {
          final user = authService.currentUser!;

          return Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              children: [
                // User info
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          child: Icon(Icons.person),
                          radius: 30,
                        ),
                        SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text('DNI: ${user.dni}'),
                            Text('Trabajador'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 32),

                // Check-in/out buttons (placeholder)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Implement check-in logic
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Marcar Entrada - Próximamente')),
                          );
                        },
                        icon: Icon(Icons.login),
                        label: Text('Marcar\nEntrada'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.all(24),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Implement check-out logic
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Marcar Salida - Próximamente')),
                          );
                        },
                        icon: Icon(Icons.logout),
                        label: Text('Marcar\nSalida'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.all(24),
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 32),

                // History button
                ListTile(
                  leading: Icon(Icons.history),
                  title: Text('Ver Historial'),
                  subtitle: Text('Consulta tus registros de asistencia'),
                  trailing: Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // TODO: Navigate to history screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Historial - Próximamente')),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
