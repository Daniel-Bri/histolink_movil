import 'dart:async';
import 'package:flutter/material.dart';
import 'package:histolink/shared/theme/app_colors.dart';
import 'package:histolink/SeguridadAvanzadaYAdministracion/BreakGlass_Solicitud/models/break_glass_solicitud_model.dart';
import 'package:histolink/SeguridadAvanzadaYAdministracion/BreakGlass_Solicitud/services/break_glass_solicitud_service.dart';

class BreakGlassSolicitudScreen extends StatefulWidget {
  const BreakGlassSolicitudScreen({
    super.key,
    required this.pacienteId,
    required this.pacienteNombre,
  });

  final int pacienteId;
  final String pacienteNombre;

  @override
  State<BreakGlassSolicitudScreen> createState() => _BreakGlassSolicitudScreenState();
}

class _BreakGlassSolicitudScreenState extends State<BreakGlassSolicitudScreen> {
  final _service = BreakGlassSolicitudService();
  final _justificacionCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _urgencia = 'MEDIA';
  bool _sending = false;
  String? _error;
  String? _ok;
  BreakGlassSolicitudModel? _solicitud;
  Timer? _pollTimer;
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  static const _quickPhrases = <String>[
    'Emergencia médica',
    'Paciente inconsciente',
    'Guardia nocturna',
  ];

  @override
  void initState() {
    super.initState();
    _cargarUltimaSolicitud();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _cargarUltimaSolicitud());
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickCountdown());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _justificacionCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarUltimaSolicitud() async {
    try {
      final all = await _service.misSolicitudes();
      final list = all.where((s) => s.pacienteId == widget.pacienteId).toList()
        ..sort((a, b) => b.creadoEn.compareTo(a.creadoEn));
      if (!mounted) return;
      setState(() {
        _solicitud = list.isEmpty ? null : list.first;
        _error = null;
      });
      _tickCountdown();
    } on BreakGlassApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo actualizar el estado de la solicitud.');
    }
  }

  void _tickCountdown() {
    final hasta = _solicitud?.accesoHasta;
    if (hasta == null) {
      if (mounted) setState(() => _remaining = Duration.zero);
      return;
    }
    final left = hasta.difference(DateTime.now());
    if (!mounted) return;
    setState(() => _remaining = left.isNegative ? Duration.zero : left);
  }

  String _fmtRemaining(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void _appendPhrase(String phrase) {
    final current = _justificacionCtrl.text.trim();
    if (current.isEmpty) {
      _justificacionCtrl.text = '$phrase. ';
    } else if (!current.toLowerCase().contains(phrase.toLowerCase())) {
      _justificacionCtrl.text = '$current. $phrase. ';
    }
    _justificacionCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _justificacionCtrl.text.length),
    );
    setState(() {});
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _ok = null;
    });
    if (!_formKey.currentState!.validate()) return;
    try {
      setState(() => _sending = true);
      final created = await _service.crearSolicitud(
        pacienteId: widget.pacienteId,
        justificacion: _justificacionCtrl.text.trim(),
        nivelUrgencia: _urgencia,
      );
      if (!mounted) return;
      setState(() {
        _solicitud = created;
        _ok = created.advertencia ?? 'Solicitud enviada. Pendiente de revisión.';
      });
      _tickCountdown();
    } on BreakGlassApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo enviar la solicitud de emergencia.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chars = _justificacionCtrl.text.trim().length;
    final accesoActivo = (_solicitud?.accesoActivo ?? false) && _remaining > Duration.zero;
    final canOpenExpediente = accesoActivo || (_solicitud?.estado == 'APROBADA');

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: const Text('Acceso de emergencia'),
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderCard(
                pacienteNombre: widget.pacienteNombre,
                solicitud: _solicitud,
                accesoActivo: accesoActivo,
                remainingText: _fmtRemaining(_remaining),
                onVerExpediente: canOpenExpediente ? () => Navigator.pop(context, true) : null,
              ),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5EAF3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Justificación clínica',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.azulElectrico),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _quickPhrases
                            .map(
                              (p) => ActionChip(
                                label: Text(p),
                                onPressed: () => _appendPhrase(p),
                                backgroundColor: const Color(0xFFF0F5FF),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _justificacionCtrl,
                        minLines: 4,
                        maxLines: 6,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Describe la emergencia y por qué requiere acceso inmediato...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = (v ?? '').trim().length;
                          if (n < 20) return 'La justificación debe tener al menos 20 caracteres.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$chars/20 caracteres mínimos',
                        style: TextStyle(
                          fontSize: 12,
                          color: chars >= 20 ? Colors.green.shade700 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Nivel de urgencia',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.azulElectrico),
                      ),
                      const SizedBox(height: 8),
                      _UrgencySelector(
                        value: _urgencia,
                        onChange: (v) => setState(() => _urgencia = v),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Este acceso queda registrado y será auditado.',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                      if (_ok != null) ...[
                        const SizedBox(height: 10),
                        Text(_ok!, style: const TextStyle(color: Colors.green)),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _sending ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.azulElectrico,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _sending
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Solicitar acceso de emergencia'),
                        ),
                      ),
                    ],
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
  const _HeaderCard({
    required this.pacienteNombre,
    required this.solicitud,
    required this.accesoActivo,
    required this.remainingText,
    required this.onVerExpediente,
  });

  final String pacienteNombre;
  final BreakGlassSolicitudModel? solicitud;
  final bool accesoActivo;
  final String remainingText;
  final VoidCallback? onVerExpediente;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5EAF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Solicitud de Acceso de Emergencia',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.azulElectrico),
          ),
          const SizedBox(height: 6),
          Text('Paciente: $pacienteNombre', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            'No tienes permiso para acceder a este expediente. Puedes solicitar acceso de emergencia si existe una situación clínica justificada.',
          ),
          if (solicitud != null) ...[
            const SizedBox(height: 10),
            Text('Estado: ${solicitud!.estado} | Urgencia: ${solicitud!.nivelUrgencia}'),
            if (accesoActivo) ...[
              const SizedBox(height: 4),
              Text(
                'Acceso temporal concedido por emergencia. Tiempo restante: $remainingText',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
              ),
            ] else if (solicitud!.estado == 'PENDIENTE') ...[
              const SizedBox(height: 4),
              const Text('Solicitud pendiente de revisión.', style: TextStyle(color: Colors.black54)),
            ],
            if (onVerExpediente != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onVerExpediente,
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Ver expediente'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _UrgencySelector extends StatelessWidget {
  const _UrgencySelector({required this.value, required this.onChange});
  final String value;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    final items = const [
      ('ALTA', 'Vida en peligro'),
      ('MEDIA', 'Urgencia clínica'),
      ('BAJA', 'Administrativo'),
    ];
    return Column(
      children: items
          .map(
            (it) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => onChange(it.$1),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: value == it.$1 ? const Color(0xFFEFF4FF) : Colors.white,
                    border: Border.all(
                      color: value == it.$1 ? AppColors.azulElectrico : const Color(0xFFD6DFEF),
                      width: value == it.$1 ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Radio<String>(
                        value: it.$1,
                        groupValue: value,
                        onChanged: (v) => onChange(v ?? 'MEDIA'),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(it.$2, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

