import 'package:flutter/material.dart';
import 'package:histolink/SeguridadAvanzadaYAdministracion/BreakGlass_Aprobacion/services/break_glass_aprobacion_service.dart';
import 'package:histolink/SeguridadAvanzadaYAdministracion/BreakGlass_Solicitud/models/break_glass_solicitud_model.dart';
import 'package:histolink/shared/models/user_model.dart';
import 'package:histolink/shared/theme/app_colors.dart';
import 'package:histolink/shared/widgets/app_drawer.dart';
import 'package:intl/intl.dart';

class BreakGlassAprobacionScreen extends StatefulWidget {
  const BreakGlassAprobacionScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<BreakGlassAprobacionScreen> createState() => _BreakGlassAprobacionScreenState();
}

class _BreakGlassAprobacionScreenState extends State<BreakGlassAprobacionScreen> {
  final _service = BreakGlassAprobacionService();
  final _searchCtrl = TextEditingController();

  List<BreakGlassSolicitudModel> _solicitudes = [];
  bool _loading = true;
  bool _processing = false;
  String? _error;
  String? _success;

  bool get _puedeAcceder {
    final roles = widget.user.groups.map((r) => r.toLowerCase()).toSet();
    return roles.contains('auditor') || roles.contains('director');
  }

  List<BreakGlassSolicitudModel> get _filtradas {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _solicitudes;
    return _solicitudes.where((s) {
      final texto = [
        s.pacienteNombre,
        s.pacienteCi,
        s.solicitanteUsername,
        s.justificacion,
        s.nivelUrgencia,
      ].join(' ').toLowerCase();
      return texto.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _cargarPendientes();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarPendientes() async {
    if (!_puedeAcceder) {
      setState(() {
        _loading = false;
        _error = 'No autorizado. Solo Auditor o Director pueden revisar solicitudes Break-Glass.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final data = await _service.listarPendientes();
      if (!mounted) return;
      setState(() => _solicitudes = data);
    } on BreakGlassAprobacionException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo cargar la lista de solicitudes.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _aprobar(BreakGlassSolicitudModel solicitud) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aprobar solicitud'),
        content: Text(
          '¿Deseas aprobar el acceso Break-Glass para ${solicitud.pacienteNombre}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Aprobar')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() {
      _processing = true;
      _error = null;
      _success = null;
    });

    try {
      final resp = await _service.aprobar(solicitud.id);
      if (!mounted) return;
      setState(() => _success = (resp['mensaje'] ?? 'Solicitud aprobada correctamente.').toString());
      await _cargarPendientes();
    } on BreakGlassAprobacionException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      if (e.message.toLowerCase().contains('expir')) {
        await _cargarPendientes();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo aprobar la solicitud.');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _rechazar(BreakGlassSolicitudModel solicitud) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (context) => _RechazoDialog(pacienteNombre: solicitud.pacienteNombre),
    );
    if (motivo == null) return;

    setState(() {
      _processing = true;
      _error = null;
      _success = null;
    });

    try {
      final resp = await _service.rechazar(
        solicitudId: solicitud.id,
        motivoRechazo: motivo,
      );
      if (!mounted) return;
      setState(() => _success = (resp['mensaje'] ?? 'Solicitud rechazada correctamente.').toString());
      await _cargarPendientes();
    } on BreakGlassAprobacionException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      if (e.message.toLowerCase().contains('expir')) {
        await _cargarPendientes();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo rechazar la solicitud.');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _abrirDetalle(BreakGlassSolicitudModel solicitud) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SolicitudDetalleSheet(
        solicitud: solicitud,
        usuarioActualId: widget.user.id,
        processing: _processing,
        onAprobar: () => _aprobar(solicitud),
        onRechazar: () => _rechazar(solicitud),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filtradas;
    return Scaffold(
      backgroundColor: AppColors.fondo,
      drawer: AppDrawer(user: widget.user, activeLabel: 'Aprobación Break-Glass'),
      appBar: AppBar(
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
        title: const Text('Aprobación Break-Glass'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _cargarPendientes,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargarPendientes,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _HeaderCard(total: _solicitudes.length),
              const SizedBox(height: 14),
              _SearchCard(controller: _searchCtrl),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _MessageCard(text: _error!, color: Colors.red.shade700, bg: Colors.red.shade50),
              ],
              if (_success != null) ...[
                const SizedBox(height: 12),
                _MessageCard(text: _success!, color: Colors.green.shade700, bg: Colors.green.shade50),
              ],
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 36),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (!_puedeAcceder)
                const _EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'No autorizado',
                  subtitle: 'Solo Auditor o Director pueden revisar solicitudes Break-Glass.',
                )
              else if (_solicitudes.isEmpty)
                const _EmptyState(
                  icon: Icons.verified_user_outlined,
                  title: 'Sin solicitudes pendientes',
                  subtitle: 'Cuando exista una solicitud Break-Glass aparecerá aquí.',
                )
              else if (visible.isEmpty)
                const _EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Sin coincidencias',
                  subtitle: 'No hay solicitudes que coincidan con la búsqueda.',
                )
              else
                ...visible.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SolicitudCard(
                      solicitud: s,
                      esPropia: s.solicitanteId == widget.user.id,
                      onTap: () => _abrirDetalle(s),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.azulElectrico, AppColors.azulPuro],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.azulElectrico.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.security_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seguridad clínica',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Solicitudes Break-Glass',
                  style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total solicitud(es) pendiente(s)',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE7FF)),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Buscar por paciente, CI o médico solicitante...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: controller.clear,
                ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          isDense: true,
        ),
      ),
    );
  }
}

class _SolicitudCard extends StatelessWidget {
  const _SolicitudCard({
    required this.solicitud,
    required this.esPropia,
    required this.onTap,
  });

  final BreakGlassSolicitudModel solicitud;
  final bool esPropia;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDCE7FF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: _urgenciaColor(solicitud.nivelUrgencia).withValues(alpha: 0.12),
                    child: Icon(Icons.emergency_rounded, color: _urgenciaColor(solicitud.nivelUrgencia)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          solicitud.pacienteNombre.isEmpty ? 'Paciente sin nombre' : solicitud.pacienteNombre,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F1B5F)),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Solicita: ${solicitud.solicitanteUsername.isEmpty ? 'Usuario sin nombre' : solicitud.solicitanteUsername}',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  _TextChip(label: solicitud.nivelUrgencia, color: _urgenciaColor(solicitud.nivelUrgencia)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                solicitud.justificacion,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade800, height: 1.35),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 15, color: Colors.grey.shade500),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _fmtDate(solicitud.creadoEn),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ),
                  if (esPropia)
                    const _TextChip(label: 'Solicitud propia', color: Color(0xFF64748B))
                  else
                    const Icon(Icons.chevron_right_rounded, color: AppColors.azulElectrico),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SolicitudDetalleSheet extends StatelessWidget {
  const _SolicitudDetalleSheet({
    required this.solicitud,
    required this.usuarioActualId,
    required this.processing,
    required this.onAprobar,
    required this.onRechazar,
  });

  final BreakGlassSolicitudModel solicitud;
  final int usuarioActualId;
  final bool processing;
  final VoidCallback onAprobar;
  final VoidCallback onRechazar;

  bool get _esPropia => solicitud.solicitanteId == usuarioActualId;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.42,
      maxChildSize: 0.92,
      builder: (context, controller) {
        return Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: ListView(
            controller: controller,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(999)),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      solicitud.pacienteNombre.isEmpty ? 'Paciente sin nombre' : solicitud.pacienteNombre,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F1B5F)),
                    ),
                  ),
                  _TextChip(label: solicitud.estado, color: AppColors.azulElectrico),
                ],
              ),
              const SizedBox(height: 6),
              Text('CI: ${solicitud.pacienteCi.isEmpty ? 'No registrado' : solicitud.pacienteCi}'),
              const SizedBox(height: 18),
              _InfoRow(label: 'Médico solicitante', value: solicitud.solicitanteUsername),
              _InfoRow(label: 'Nivel de urgencia', value: solicitud.nivelUrgencia),
              _InfoRow(label: 'Fecha de solicitud', value: _fmtDate(solicitud.creadoEn)),
              const SizedBox(height: 14),
              const Text('Justificación clínica', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.azulElectrico)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFDCE7FF)),
                ),
                child: Text(solicitud.justificacion, style: const TextStyle(height: 1.4)),
              ),
              const SizedBox(height: 18),
              if (_esPropia)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.shade100),
                  ),
                  child: const Text(
                    'No puedes aprobar ni rechazar tu propia solicitud Break-Glass.',
                    style: TextStyle(color: Color(0xFF9A3412), fontWeight: FontWeight.w700),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: processing
                            ? null
                            : () {
                                Navigator.pop(context);
                                onRechazar();
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Rechazar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: processing
                            ? null
                            : () {
                                Navigator.pop(context);
                                onAprobar();
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Aprobar'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RechazoDialog extends StatefulWidget {
  const _RechazoDialog({required this.pacienteNombre});

  final String pacienteNombre;

  @override
  State<_RechazoDialog> createState() => _RechazoDialogState();
}

class _RechazoDialogState extends State<_RechazoDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final len = _ctrl.text.trim().length;
    return AlertDialog(
      title: const Text('Rechazar solicitud'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Indica el motivo para rechazar el acceso a ${widget.pacienteNombre}.'),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            minLines: 4,
            maxLines: 6,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Ej: No corresponde a una emergencia justificada...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 6),
          Text('$len/10 caracteres mínimos', style: TextStyle(color: len >= 10 ? Colors.green : Colors.grey.shade600, fontSize: 12)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: len >= 10 ? () => Navigator.pop(context, _ctrl.text.trim()) : null,
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          child: const Text('Confirmar rechazo'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
          ),
          Expanded(child: Text(value.isEmpty ? 'No registrado' : value)),
        ],
      ),
    );
  }
}

class _TextChip extends StatelessWidget {
  const _TextChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.text, required this.color, required this.bg});

  final String text;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 42),
      child: Column(
        children: [
          Icon(icon, size: 52, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

Color _urgenciaColor(String nivel) {
  switch (nivel.toUpperCase()) {
    case 'ALTA':
      return const Color(0xFFDC2626);
    case 'MEDIA':
      return const Color(0xFFD97706);
    default:
      return const Color(0xFF0284C7);
  }
}

String _fmtDate(DateTime date) {
  return DateFormat('dd/MM/yyyy, HH:mm').format(date.toLocal());
}
