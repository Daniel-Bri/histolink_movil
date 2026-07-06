import 'package:flutter/material.dart';
import 'package:histolink/shared/theme/app_colors.dart';
import 'package:histolink/shared/models/user_model.dart';
import 'package:histolink/shared/widgets/app_drawer.dart';
import 'package:histolink/GestionDeUsuarios/LoginYAutenticacion/services/auth_service.dart';
import 'package:histolink/GestionDeUsuarios/LoginYAutenticacion/screens/login_screen.dart';
import 'package:histolink/shared/services/fcm_service.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/screens/registro_y_busqueda_de_pacientes_screen.dart';
import 'package:histolink/GestionDeUsuarios/VisualizacionDelExpediente/screens/visualizacion_del_expediente_screen.dart';
import 'package:histolink/AtencionClinica/AperturaFichaYColaDeAtencion/screens/apertura_ficha_y_cola_de_atencion_screen.dart';

class DashboardScreen extends StatelessWidget {
  final UserModel user;

  const DashboardScreen({super.key, required this.user});

  Future<void> _logout(BuildContext context) async {
    try {
      // Desactivar el token FCM antes de borrar la sesión (necesita el access_token).
      await FcmService.instance.eliminarToken();
      await AuthService().logout();
    } catch (_) {
      // Si falla el logout remoto o local, igual navegamos al login
    }
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      drawer: AppDrawer(user: user, activeLabel: 'Dashboard'),
      appBar: AppBar(
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_hospital, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    user.tenantNombre ?? 'Histolink',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.2),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user.tenantNombre != null)
                    const Text(
                      'HISTOLINK — SISTEMA CLÍNICO',
                      style: TextStyle(fontSize: 9, letterSpacing: 0.5, color: Colors.white70),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar sesión',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarjeta de bienvenida con gradiente
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.azulElectrico, AppColors.azulPuro],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.azulElectrico.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bienvenido,',
                          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.mentaVibrante,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                user.role,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (user.tenantNombre != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.business_outlined, color: Colors.white60, size: 13),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  user.tenantNombre!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_circle_outlined, color: Colors.white, size: 38),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Estadísticas rápidas
            Row(
              children: [
                _StatChip(label: 'Activo', color: AppColors.mentaVibrante, bgColor: AppColors.mentaSuave),
                const SizedBox(width: 10),
                _StatChip(label: 'Hoy', color: AppColors.azulElectrico, bgColor: AppColors.azulCielo),
              ],
            ),

            const SizedBox(height: 28),

            const Text(
              'Menú Principal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.azulElectrico,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 14),

            // Grilla del menú
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.05,
              children: user.esPaciente
                  // ── Menú del PACIENTE (Sprint 5) ─────────────────────────
                  ? [
                      _MenuCard(
                        icon: Icons.folder_shared_outlined,
                        label: 'Mi Expediente',
                        iconColor: AppColors.azulPuro,
                        bgColor: AppColors.azulCielo,
                        onTap: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const VisualizacionDelExpedienteScreen(selfMode: true),
                            ),
                          );
                        },
                      ),
                      _MenuCard(
                        icon: Icons.qr_code_2_rounded,
                        label: 'Mis Recetas',
                        iconColor: AppColors.mentaVibrante,
                        bgColor: AppColors.mentaSuave,
                        onTap: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const VisualizacionDelExpedienteScreen(selfMode: true),
                            ),
                          );
                        },
                      ),
                    ]
                  // ── Menú del PERSONAL de salud ───────────────────────────
                  : [
                      _MenuCard(
                        icon: Icons.people_outline_rounded,
                        label: 'Pacientes',
                        iconColor: AppColors.azulPuro,
                        bgColor: AppColors.azulCielo,
                        onTap: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const RegistroYBusquedaDePacientesScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuCard(
                        icon: Icons.assignment_outlined,
                        label: 'Consultas',
                        iconColor: AppColors.mentaVibrante,
                        bgColor: AppColors.mentaSuave,
                        onTap: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => AperturaFichaYColaDeAtencionScreen(user: user),
                            ),
                          );
                        },
                      ),
                      const _MenuCard(
                        icon: Icons.science_outlined,
                        label: 'Laboratorio',
                        iconColor: AppColors.azulElectrico,
                        bgColor: AppColors.azulCielo,
                      ),
                      const _MenuCard(
                        icon: Icons.medication_outlined,
                        label: 'Farmacia',
                        iconColor: AppColors.mentaVibrante,
                        bgColor: AppColors.mentaSuave,
                      ),
                    ],
            ),

            const SizedBox(height: 28),

            // Sección de actividad reciente (placeholder)
            const Text(
              'Actividad Reciente',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.azulElectrico,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 14),

            _ActivityItem(
              title: 'Sin registros recientes',
              subtitle: 'Las actividades del día aparecerán aquí',
              statusLabel: 'Info',
              statusColor: AppColors.azulElectrico,
              statusBg: AppColors.azulCielo,
              icon: Icons.inbox_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;

  const _StatChip({required this.label, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback? onTap;

  const _MenuCard({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.azulElectrico.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap ?? () {},
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: Color(0xFF1A202C),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String statusLabel;
  final Color statusColor;
  final Color statusBg;
  final IconData icon;

  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.statusColor,
    required this.statusBg,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.azulElectrico.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.fondo,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.azulElectrico, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Color(0xFF1A202C))),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
