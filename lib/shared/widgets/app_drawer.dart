import 'package:flutter/material.dart';
import 'package:histolink/shared/models/user_model.dart';
import 'package:histolink/shared/screens/error_screen.dart';
import 'package:histolink/GestionDeUsuarios/LoginYAutenticacion/services/auth_service.dart';
import 'package:histolink/GestionDeUsuarios/LoginYAutenticacion/screens/login_screen.dart';
import 'package:histolink/shared/services/fcm_service.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/screens/registro_y_busqueda_de_pacientes_screen.dart';
import 'package:histolink/AtencionClinica/SolicitudDeEstudios/screens/solicitud_de_estudios_screen.dart';
import 'package:histolink/AtencionClinica/RegistroDeTriaje/screens/registro_de_triaje_screen.dart';
import 'package:histolink/AtencionClinica/AperturaFichaYColaDeAtencion/screens/apertura_ficha_y_cola_de_atencion_screen.dart';
import 'package:histolink/AtencionClinica/EmisionDeRecetaMedica/screens/emision_de_receta_medica_screen.dart';
import 'package:histolink/SeguridadAvanzadaYAdministracion/ReporteProduccion/screens/reportes_rapidos_screen.dart';
import 'package:histolink/SeguridadAvanzadaYAdministracion/PanelDeAuditoriaYReportesSNIS/screens/panel_de_auditoria_y_reportes_snis_screen.dart';
import 'package:histolink/SeguridadAvanzadaYAdministracion/BreakGlass_Aprobacion/screens/break_glass_aprobacion_screen.dart';

import 'package:histolink/IA_Blockchain/ConfiguracionDeConsentimiento/screens/configuracion_de_consentimiento_screen.dart';

// ── Colores del sidebar (mismos que web) ─────────────────────────────────────
const _bgSidebar = Color(0xFF122268);
const _divider = Color(0x26FFFFFF);
const _activeBg = Color(0x3800A896);
const _activeBorder = Color(0xFF00A896);
const _hoverBg = Color(0x17FFFFFF);
const _textHigh = Color(0xE0FFFFFF);
const _textMid = Color(0xA6FFFFFF);
const _textLow = Color(0x8CFFFFFF);

// ── Colores por rol ───────────────────────────────────────────────────────────
final _rolColors = <String, _RolColor>{
  'Médico':        _RolColor(const Color(0x303B82F6), const Color(0xFF93C5FD)),
  'Enfermera':     _RolColor(const Color(0x3010B981), const Color(0xFF6EE7B7)),
  'Administrativo':_RolColor(const Color(0x30F59E0B), const Color(0xFFFCD34D)),
  'Auditor':       _RolColor(const Color(0x308B5CF6), const Color(0xFFC4B5FD)),
  'Director':      _RolColor(const Color(0x30EC4899), const Color(0xFFF9A8D4)),
  'Laboratorio':   _RolColor(const Color(0x3006B6D4), const Color(0xFF67E8F9)),
  'Farmacia':      _RolColor(const Color(0x30EAB308), const Color(0xFFFDE68A)),
};

class _RolColor {
  final Color bg;
  final Color text;
  const _RolColor(this.bg, this.text);
}

// ── Modelo de ítem de navegación ──────────────────────────────────────────────
class _NavItem {
  final String label;
  final IconData icon;
  final List<String> roles;
  final Widget Function(UserModel)? screenBuilder;

  const _NavItem({
    required this.label,
    required this.icon,
    this.roles = const [],
    this.screenBuilder,
  });
}

class _NavSection {
  final String title;
  final List<_NavItem> items;
  const _NavSection({required this.title, required this.items});
}

final _sections = <_NavSection>[
  _NavSection(title: 'Gestión de Usuarios', items: [
    _NavItem(
      label: 'Pacientes',
      icon: Icons.people_outline_rounded,
      screenBuilder: (_) => const RegistroYBusquedaDePacientesScreen(),
    ),
  ]),
  _NavSection(title: 'Atención Clínica', items: [
    _NavItem(
      label: 'Fichas del Día',
      icon: Icons.list_alt_rounded,
      screenBuilder: (user) => AperturaFichaYColaDeAtencionScreen(user: user),
    ),
    _NavItem(
      label: 'Triaje',
      icon: Icons.monitor_heart_outlined,
      roles: ['Médico', 'Enfermera'],
      screenBuilder: (user) => RegistroDeTriajeScreen(user: user),
    ),
    _NavItem(
      label: 'Receta Médica',
      icon: Icons.receipt_long_outlined,
      roles: ['Médico', 'Farmacia'],
      screenBuilder: (_) => const EmisionDeRecetaMedicaScreen(),
    ),
    _NavItem(
      label: 'Solicitud de Estudios',
      icon: Icons.science_outlined,
      roles: ['Médico', 'Laboratorio'],
      screenBuilder: (_) => const SolicitudDeEstudiosScreen(),
    ),
  ]),
  _NavSection(title: 'IA + Blockchain', items: [
    _NavItem(
      label: 'Gestión Consentimientos',
      icon: Icons.assignment_turned_in_rounded,
      screenBuilder: (_) => const ConfiguracionDeConsentimientoScreen(),
    ),
  ]),
  _NavSection(title: 'Seguridad y Admin', items: [
    _NavItem(
      label: 'Reportes',
      icon: Icons.analytics_outlined,
      roles: ['Administrador', 'Médico', 'Jefe de enfermería', 'Director'],
      screenBuilder: (user) => ReportesRapidosScreen(user: user),
    ),
    _NavItem(
      label: 'Auditoría',
      icon: Icons.shield_outlined,
      roles: ['Auditor', 'Director', 'Administrativo'],
      screenBuilder: (user) => PanelDeAuditoriaYReportesSNISScreen(user: user),
    ),
    _NavItem(
      label: 'Aprobación Break-Glass',
<<<<<<< HEAD
      icon: Icons.emergency_share_outlined,
      roles: ['Auditor', 'Director'],
      screenBuilder: (user) => BreakGlassAprobacionScreen(user: user),
    ),
    _NavItem(label: 'Administración', icon: Icons.settings_outlined, soon: true, roles: ['Administrativo', 'Director']),
=======
      icon: Icons.lock_open_outlined,
      roles: ['Auditor', 'Director'],
      screenBuilder: (user) => BreakGlassAprobacionScreen(user: user),
    ),
>>>>>>> servidor
  ]),
];

// ── Helpers ───────────────────────────────────────────────────────────────────
bool _canAccess(UserModel user, _NavItem item) =>
    item.roles.isEmpty || item.roles.any((r) => user.groups.contains(r));

// ── Widget principal ──────────────────────────────────────────────────────────
class AppDrawer extends StatelessWidget {
  final UserModel user;
  final String? activeLabel;

  const AppDrawer({super.key, required this.user, this.activeLabel});

  Future<void> _logout(BuildContext context) async {
    try {
      // Desactivar el token FCM antes de borrar la sesión (necesita el access_token).
      await FcmService.instance.eliminarToken();
      await AuthService().logout();
    } catch (_) {}
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rol = user.role;
    final rolColor = _rolColors[rol] ??
        _RolColor(const Color(0x3094A3B8), const Color(0xFF94A3B8));

    return Drawer(
      width: 272,
      backgroundColor: _bgSidebar,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Column(
          children: [
            // ── Logo ────────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _divider)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _activeBorder,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'HL',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HistoLink',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          user.tenantNombre?.toUpperCase() ?? 'SISTEMA CLÍNICO',
                          style: const TextStyle(
                            color: _textMid,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Usuario ─────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _divider)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0x20FFFFFF),
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: const Icon(Icons.person_outline,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          user.username,
                          style: const TextStyle(color: _textLow, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: rolColor.bg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            rol,
                            style: TextStyle(
                              color: rolColor.text,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Navegación ──────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: _sections.map((section) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
                        child: Text(
                          section.title.toUpperCase(),
                          style: const TextStyle(
                            color: _textMid,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      ...section.items.map((item) {
                        final hasAccess = _canAccess(user, item);

                        VoidCallback? onTap;
                        if (!hasAccess) {
                          onTap = () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ErrorScreen(
                                  statusCode: 403,
                                  mensaje:
                                      'No cuentas con el rol necesario para acceder a esta sección.',
                                ),
                              ),
                            );
                          };
                        } else if (item.screenBuilder != null) {
                          onTap = () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => item.screenBuilder!(user),
                              ),
                            );
                          };
                        }

                        return _NavTile(
                          item: item,
                          isActive: activeLabel == item.label,
                          hasAccess: hasAccess,
                          onTap: onTap,
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),

            // ── Cerrar sesión ────────────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _divider)),
              ),
              child: _BottomAction(
                icon: Icons.logout_rounded,
                label: 'Cerrar sesión',
                color: const Color(0xFFFFB4B4),
                activeColor: const Color(0xFFFCA5A5),
                hoverBg: const Color(0x1FEF4444),
                onTap: () => _logout(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tile de navegación ────────────────────────────────────────────────────────
class _NavTile extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  final bool hasAccess;
  final VoidCallback? onTap;

  const _NavTile({
    required this.item,
    required this.isActive,
    required this.hasAccess,
    this.onTap,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    final hasAccess = widget.hasAccess;

    Color textColor;
    if (active) {
      textColor = Colors.white;
    } else if (!hasAccess) {
      textColor = _textLow;
    } else {
      textColor = _textHigh;
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: active
              ? _activeBg
              : (_pressed ? _hoverBg : Colors.transparent),
          border: Border(
            left: BorderSide(
              color: active ? _activeBorder : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        child: Row(
          children: [
            Icon(widget.item.icon, size: 16, color: textColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.item.label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (!hasAccess)
              _Badge(
                label: 'Sin acceso',
                bg: const Color(0x1FEF4444),
                text: const Color(0xFFFF8080),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color text;

  const _Badge({required this.label, required this.bg, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: text,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      );
}

// ── Botón inferior ────────────────────────────────────────────────────────────
class _BottomAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color activeColor;
  final Color hoverBg;
  final VoidCallback onTap;

  const _BottomAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.activeColor,
    required this.hoverBg,
    required this.onTap,
  });

  @override
  State<_BottomAction> createState() => _BottomActionState();
}

class _BottomActionState extends State<_BottomAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _pressed ? widget.hoverBg : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Icon(widget.icon,
                size: 16,
                color: _pressed ? widget.activeColor : widget.color),
            const SizedBox(width: 10),
            Text(
              widget.label,
              style: TextStyle(
                color: _pressed ? widget.activeColor : widget.color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
