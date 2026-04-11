import 'package:flutter/material.dart';
import 'package:histolink/shared/theme/app_colors.dart';
import 'package:histolink/shared/widgets/loading_indicator.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/models/paciente_model.dart';
import 'package:histolink/GestionDeUsuarios/RegistroYBusquedaDePacientes/services/paciente_service.dart';

class PacienteDetalleScreen extends StatefulWidget {
  const PacienteDetalleScreen({super.key, required this.pacienteId});

  final int pacienteId;

  @override
  State<PacienteDetalleScreen> createState() => _PacienteDetalleScreenState();
}

class _PacienteDetalleScreenState extends State<PacienteDetalleScreen> {
  final _service = PacienteService();
  PacienteModel? _p;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await _service.obtener(widget.pacienteId);
      if (!mounted) return;
      setState(() {
        _p = p;
        _loading = false;
      });
    } on PacienteApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _sexoLabel(String code) {
    switch (code) {
      case 'M':
        return 'Masculino';
      case 'F':
        return 'Femenino';
      case 'O':
        return 'Otro';
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: const Text('Detalle del paciente'),
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const LoadingIndicator(message: 'Cargando expediente…')
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _load,
                          style: FilledButton.styleFrom(backgroundColor: AppColors.azulElectrico),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _p == null
                  ? const Center(child: Text('Sin datos'))
                  : RefreshIndicator(
                      color: AppColors.azulPuro,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.azulElectrico.withOpacity(0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _p!.nombreCompleto,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.azulElectrico,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _RowInfo(icon: Icons.badge_outlined, label: 'CI', value: _p!.ciCompleto),
                                _RowInfo(
                                  icon: Icons.cake_outlined,
                                  label: 'Edad',
                                  value: _p!.edadCalculada != null ? '${_p!.edadCalculada} años' : '—',
                                ),
                                _RowInfo(icon: Icons.event_outlined, label: 'Nacimiento', value: _p!.fechaNacimiento),
                                _RowInfo(icon: Icons.wc_outlined, label: 'Sexo', value: _sexoLabel(_p!.sexo)),
                                if (_p!.email != null && _p!.email!.isNotEmpty)
                                  _RowInfo(icon: Icons.email_outlined, label: 'Email', value: _p!.email!),
                                if (_p!.telefono != null && _p!.telefono!.isNotEmpty)
                                  _RowInfo(icon: Icons.phone_outlined, label: 'Teléfono', value: _p!.telefono!),
                                if (_p!.direccion != null && _p!.direccion!.isNotEmpty)
                                  _RowInfo(icon: Icons.place_outlined, label: 'Dirección', value: _p!.direccion!),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Próximamente: historial clínico, consultas y documentos en esta vista de expediente.',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _RowInfo extends StatelessWidget {
  const _RowInfo({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.azulElectrico),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
