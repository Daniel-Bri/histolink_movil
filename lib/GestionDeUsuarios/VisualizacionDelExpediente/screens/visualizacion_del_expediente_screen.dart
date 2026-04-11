import 'package:flutter/material.dart';
import 'package:histolink/GestionDeUsuarios/VisualizacionDelExpediente/models/expediente_resumido_model.dart';
import 'package:histolink/GestionDeUsuarios/VisualizacionDelExpediente/services/expediente_service.dart';
import 'package:histolink/shared/theme/app_colors.dart';

class VisualizacionDelExpedienteScreen extends StatefulWidget {
  const VisualizacionDelExpedienteScreen({super.key});

  @override
  State<VisualizacionDelExpedienteScreen> createState() => _VisualizacionDelExpedienteScreenState();
}

class _VisualizacionDelExpedienteScreenState extends State<VisualizacionDelExpedienteScreen> {
  final _pacienteIdController = TextEditingController(text: '1');
  final _expedienteService = ExpedienteService();

  bool _isLoading = false;
  String? _error;
  ExpedienteResumido? _expediente;

  @override
  void initState() {
    super.initState();
    _cargarExpediente();
  }

  @override
  void dispose() {
    _pacienteIdController.dispose();
    super.dispose();
  }

  Future<void> _cargarExpediente() async {
    final id = int.tryParse(_pacienteIdController.text.trim());
    if (id == null || id <= 0) {
      setState(() {
        _error = 'Ingresa un ID de paciente valido.';
        _expediente = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final expediente = await _expedienteService.obtenerExpedienteResumido(id);
      if (!mounted) return;
      setState(() => _expediente = expediente);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _expediente = null;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expediente = _expediente;
    final ultimoTriaje = (expediente != null && expediente.triajes.isNotEmpty) ? expediente.triajes.first : null;
    final ultimaConsulta = (expediente != null && expediente.consultas.isNotEmpty) ? expediente.consultas.first : null;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: const Text('Expediente resumido'),
        backgroundColor: AppColors.azulElectrico,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _cargarExpediente,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SearchCard(
              controller: _pacienteIdController,
              loading: _isLoading,
              onSearch: _cargarExpediente,
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              const _StateCard(
                icon: Icons.hourglass_top_rounded,
                title: 'Cargando expediente...',
                subtitle: 'Obteniendo datos del paciente',
              ),

            if (!_isLoading && _error != null)
              _StateCard(
                icon: Icons.error_outline_rounded,
                title: 'No se pudo cargar el expediente',
                subtitle: _error!,
                danger: true,
              ),

            if (!_isLoading && _error == null && expediente == null)
              const _StateCard(
                icon: Icons.inbox_outlined,
                title: 'Sin datos',
                subtitle: 'No se encontro informacion para este paciente.',
              ),

            if (!_isLoading && _error == null && expediente != null) ...[
              _SectionCard(
                title: 'Datos basicos',
                icon: Icons.badge_outlined,
                children: [
                  _InfoRow(label: 'Paciente', value: '${expediente.nombres} ${expediente.apellidoPaterno} ${expediente.apellidoMaterno}'.trim()),
                  _InfoRow(label: 'CI', value: '${expediente.ci}${expediente.ciComplemento.isNotEmpty ? '-${expediente.ciComplemento}' : ''}'),
                  _InfoRow(label: 'Fecha nacimiento', value: expediente.fechaNacimiento),
                  _InfoRow(label: 'Sexo', value: expediente.sexoLabel.isNotEmpty ? expediente.sexoLabel : 'Sin dato'),
                  _InfoRow(label: 'Telefono', value: expediente.telefono.isNotEmpty ? expediente.telefono : 'Sin dato'),
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Antecedentes relevantes',
                icon: Icons.history_edu_outlined,
                children: expediente.antecedentes == null
                    ? const [Text('Sin antecedentes registrados.')]
                    : [
                        _InfoRow(
                          label: 'Grupo sanguineo',
                          value: expediente.antecedentes!.grupoSanguineo.isNotEmpty
                              ? expediente.antecedentes!.grupoSanguineo
                              : 'Sin dato',
                        ),
                        _InfoRow(
                          label: 'Alergias',
                          value: expediente.antecedentes!.alergias.isNotEmpty
                              ? expediente.antecedentes!.alergias
                              : 'Sin dato',
                        ),
                        _InfoRow(
                          label: 'Patologicos',
                          value: expediente.antecedentes!.antecedentesPatologicos.isNotEmpty
                              ? expediente.antecedentes!.antecedentesPatologicos
                              : 'Sin dato',
                        ),
                        _InfoRow(
                          label: 'Medicacion actual',
                          value: expediente.antecedentes!.medicacionActual.isNotEmpty
                              ? expediente.antecedentes!.medicacionActual
                              : 'Sin dato',
                        ),
                      ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Ultimas atenciones',
                icon: Icons.medical_information_outlined,
                children: [
                  _InfoRow(
                    label: 'Triaje reciente',
                    value: ultimoTriaje == null
                        ? 'Sin triajes registrados'
                        : '${ultimoTriaje.nivelUrgenciaLabel} · ${ultimoTriaje.motivoConsultaTriaje.isNotEmpty ? ultimoTriaje.motivoConsultaTriaje : 'Sin motivo'}',
                  ),
                  _InfoRow(
                    label: 'Consulta reciente',
                    value: ultimaConsulta == null
                        ? 'Sin consultas registradas'
                        : '${ultimaConsulta.estadoLabel} · ${ultimaConsulta.impresionDiagnostica.isNotEmpty ? ultimaConsulta.impresionDiagnostica : 'Sin diagnostico'}',
                  ),
                  _InfoRow(label: 'Total triajes', value: '${expediente.triajes.length}'),
                  _InfoRow(label: 'Total consultas', value: '${expediente.consultas.length}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSearch;

  const _SearchCard({
    required this.controller,
    required this.loading,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.azulElectrico.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ID del paciente',
                prefixIcon: Icon(Icons.person_search_outlined),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: loading ? null : onSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.azulElectrico,
              foregroundColor: Colors.white,
            ),
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.azulElectrico.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.azulElectrico),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.azulElectrico,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Color(0xFF1A202C), fontSize: 13.2),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool danger;

  const _StateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: danger ? AppColors.alerta : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: danger ? const Color(0xFFDC2626) : AppColors.azulElectrico),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: danger ? const Color(0xFFDC2626) : AppColors.azulElectrico,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: danger ? const Color(0xFFB91C1C) : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
